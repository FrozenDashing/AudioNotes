import 'dart:ui' show Color;

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_show_when_locked/flutter_show_when_locked.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/todo_item.dart';
import '../l10n/locale_text_lookup.dart';
import '../repositories/settings_repository.dart';

// ---------------------------------------------------------------------------
// Background-isolate entry point (Chrono's alarm_isolate.dart equivalent)
// ---------------------------------------------------------------------------

/// Top-level callback invoked by [AndroidAlarmManager] when an alarm fires.
///
/// Runs in a background isolate.  Follows Chrono's [triggerScheduledNotification]
/// pattern — re-initialises the plugin infrastructure inside the isolate so
/// that [fullScreenIntent] and [wakeUpScreen] have the proper Android context
/// to wake the device.
@pragma('vm:entry-point')
void onTodoAlarmFired(int scheduleId, Map<String, dynamic>? params) async {
  final todoId = params?['todoId'] as String?;
  final title = params?['title'] as String? ?? 'Todo reminder';
  final body = params?['body'] as String?;
  final notificationId = params?['notificationId'] as int? ?? 0;

  debugPrint(
    '⏰ onTodoAlarmFired: scheduleId=$scheduleId, '
    'todoId=$todoId, notificationId=$notificationId',
  );

  if (todoId == null || todoId.isEmpty) {
    debugPrint('❌ onTodoAlarmFired: Missing todoId, aborting');
    return;
  }

  try {
    // ── Chrono's initializeIsolate() pattern ──
    // Ensure Flutter binding is available in this background isolate
    WidgetsFlutterBinding.ensureInitialized();

    // 2. Re-initialise awesome_notifications so its native side has a handle
    //    to the background isolate's context (required for wake-up/fullscreen)
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'todo_channel',
          channelName: 'Todo Notifications',
          channelDescription: 'Notifications for todo reminders',
          importance: NotificationImportance.Max,
          criticalAlerts: true,
          enableVibration: true,
          enableLights: true,
          ledColor: const Color(0xFF9D50DD),
          locked: true,
          defaultPrivacy: NotificationPrivacy.Private,
          groupKey: 'todo_group',
        ),
      ],
      debug: false,
    );

    // 3. Force screen wake with FlutterShowWhenLocked (Chrono pattern).
    //    On vivo/Chinese ROMs fullScreenIntent alone is suppressed;
    //    this transparent Activity forces the screen on.
    try {
      await FlutterShowWhenLocked().show();
      debugPrint('✓ FlutterShowWhenLocked: show() succeeded');
    } catch (e) {
      // On some ROMs MethodChannel from background isolate may fail;
      // this is non-fatal — fullScreenIntent may still work or user
      // sees notification when they wake the device manually.
      debugPrint('⚠ FlutterShowWhenLocked: show() failed (non-fatal): $e');
    }

    // 4. Show the heads-up / full-screen notification.
    //    autoDismissible: true so the notification doesn't persist
    //    after the user has seen it (prevents "re-reminder" feeling).
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: notificationId,
        channelKey: 'todo_channel',
        title: title,
        body: body ?? 'Todo reminder',
        category: NotificationCategory.Alarm,
        fullScreenIntent: true,
        wakeUpScreen: true,
        locked: true,
        autoDismissible: true,
        payload: {'todoId': todoId},
      ),
    );

    debugPrint(
      '✓ onTodoAlarmFired: Notification shown for todoId=$todoId',
    );

    // 5. Persist fired state so the main isolate's syncPendingReminders()
    //    immediately knows this todo has been handled and won't re-process.
    //    (NotificationFiredTracker.recordFired is defined but never wired;
    //     we write directly here for reliability.)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification.fired.$todoId', true);
      debugPrint('✓ Fired state recorded for todoId=$todoId');
    } catch (e) {
      debugPrint('⚠ Failed to record fired state: $e');
    }

    // 6. Auto-hide the lock-screen overlay after 3 seconds so it doesn't
    //    linger when the user unlocks the phone.
    Future.delayed(const Duration(seconds: 3), () async {
      try {
        await FlutterShowWhenLocked().hide();
        debugPrint('✓ FlutterShowWhenLocked auto-hid after 3s');
      } catch (_) {
        // non-fatal
      }
    });
  } catch (e) {
    debugPrint('❌ onTodoAlarmFired: Failed to show notification: $e');
  }
}

// ---------------------------------------------------------------------------
// Main-isolate service  (Chrono's schedule_alarm.dart layer)
// ---------------------------------------------------------------------------

/// Service that owns notification scheduling and display.
///
/// Architecture follows Chrono:
/// - **Scheduling** → [AndroidAlarmManager] JobService → [setAlarmClock] API
/// - **Display**   → [AwesomeNotifications]  (channel mgmt, permission, show)
/// - **Callback**  → [onTodoAlarmFired] runs in a background isolate with
///                   full plugin re-initialisation.
class LocalNotificationService {
  static const String _channelKey = 'todo_channel';
  static const String _channelName = 'Todo Notifications';
  static const String _channelDesc = 'Notifications for todo reminders';

  final SettingsRepository _settingsRepository = SettingsRepository();
  String? _languageCode;
  bool _initialized = false;

  /// Callback invoked when user taps a notification.
  static void Function(String todoId)? onNotificationTap;

  /// Initialise awesome_notifications in the **main** isolate.
  Future<void> initialize() async {
    if (_initialized) return;

    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: _channelKey,
          channelName: _channelName,
          channelDescription: _channelDesc,
          importance: NotificationImportance.Max,
          criticalAlerts: true,
          enableVibration: true,
          enableLights: true,
          ledColor: const Color(0xFF9D50DD),
          locked: true,
          defaultPrivacy: NotificationPrivacy.Private,
          groupKey: 'todo_group',
        ),
      ],
      debug: false,
    );

    _initialized = true;
  }

  /// Schedule a one-shot todo alarm — Chrono-style.
  ///
  /// Delegates to [AndroidAlarmManager.oneShotAt] with
  /// [alarmClock=true] → [AlarmManager.setAlarmClock].
  /// This is the **only** API that makes the app visible in vivo/OPPO/Xiaomi
  /// "Alarm & reminder" permission lists, and the only one that guarantees
  /// heads-up + screen-on on Chinese ROMs.
  Future<void> scheduleTodoNotification(TodoItem todo) async {
    final remindAt = todo.remindAt;
    if (remindAt == null) return;

    final title = _buildNotificationTitle(todo);
    final body = await _buildNotificationBody(todo);
    final id = getNotificationIdForTodo(todo.id);

    await AndroidAlarmManager.oneShotAt(
      remindAt,
      id,
      onTodoAlarmFired,
      alarmClock: true,
      exact: true,
      allowWhileIdle: true,
      wakeup: true,
      rescheduleOnReboot: true,
      params: <String, dynamic>{
        'todoId': todo.id,
        'title': title,
        'body': body,
        'notificationId': id,
      },
    );

    debugPrint(
      '✓ Alarm scheduled: todoId=${todo.id}, '
      'notificationId=$id, '
      'remindAt=${remindAt.toIso8601String()}',
    );
  }

  /// Show a notification immediately from the main isolate.
  Future<void> showTodoNotification({
    required int id,
    required String title,
    required String body,
    required String todoId,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: _channelKey,
        title: title,
        body: body,
        category: NotificationCategory.Reminder,
        fullScreenIntent: true,
        wakeUpScreen: true,
        payload: {'todoId': todoId},
      ),
    );
  }

  /// Cancel a scheduled todo alarm.
  Future<void> cancelTodoNotification(String todoId) async {
    final notificationId = getNotificationIdForTodo(todoId);
    await AndroidAlarmManager.cancel(notificationId);
    await AwesomeNotifications().cancel(notificationId);
  }

  /// Deterministic notification ID for a given todo UUID (FNV-1a 32-bit).
  /// Public so that other services (e.g. [ReminderService]) can persist it.
  int getNotificationIdForTodo(String todoId) {
    var hash = 0x811c9dc5;
    for (final unit in todoId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  /// Cancel stale alarms left over from the old notification system
  /// (flutter_local_notifications / WorkManager).
  ///
  /// Call once after [AndroidAlarmManager.initialize()] on first launch
  /// after migration.  The list comes from real device logs showing
  /// "Dart: task not found" for these IDs.
  Future<void> cancelStaleAlarms() async {
    const staleIds = <int>{
      46,
      47,
      48,
      1000033,
      1000034,
      1000035,
      1000036,
      1000037,
      1000038,
      1000039,
      1000040,
      1000041,
    };
    for (final id in staleIds) {
      await AndroidAlarmManager.cancel(id);
    }
    debugPrint('✓ ${staleIds.length} stale alarms cancelled');
  }

  // -- Private helpers -------------------------------------------------------

  String _buildNotificationTitle(TodoItem todo) {
    if (todo.text.trim().isNotEmpty) return todo.text;
    return 'Todo reminder';
  }

  Future<String> _buildNotificationBody(TodoItem todo) async {
    if (todo.dueAt == null) return _tr('notification.todoReminder');
    final lang = await _getLanguageCode();
    final date = _formatDateTime(todo.dueAt!);
    return LocaleTextLookup.tr(lang, 'notification.dueAt',
        params: {'date': date});
  }

  Future<String> _getLanguageCode() async {
    if (_languageCode != null) return _languageCode!;
    try {
      final settings = await _settingsRepository.loadSettings();
      _languageCode = settings.languageCode;
    } catch (_) {
      _languageCode = 'zh_CN';
    }
    return _languageCode!;
  }

  Future<String> _tr(String key, {Map<String, String>? params}) async {
    final lang = await _getLanguageCode();
    return LocaleTextLookup.tr(lang, key, params: params);
  }

  String _formatDateTime(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d $h:$min';
  }
}

/// Singleton convenience instance.
final localNotificationService = LocalNotificationService();
