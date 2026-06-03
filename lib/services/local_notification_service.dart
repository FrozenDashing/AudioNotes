import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/todo_item.dart';
import '../l10n/locale_text_lookup.dart';
import '../repositories/settings_repository.dart';

/// Top-level callback for background notification responses.
/// Must be top-level (not an instance method) because
/// flutter_local_notifications requires it to be a Flutter entry point.
@pragma('vm:entry-point')
void onBackgroundNotificationResponse(NotificationResponse response) {
  final todoId = response.payload;
  if (todoId != null && todoId.isNotEmpty) {
    LocalNotificationService.onNotificationTap?.call(todoId);
  }
}

/// Service for managing local notifications via flutter_local_notifications.
class LocalNotificationService {
  static const String _channelKey = 'todo_channel';
  static const String _channelName = 'Todo Notifications';
  static const String _channelDesc = 'Notifications for todo reminders';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final SettingsRepository _settingsRepository = SettingsRepository();
  String? _languageCode;
  bool _initialized = false;

  /// Callback invoked when user taps a notification.
  static void Function(String todoId)? onNotificationTap;

  /// Initialize the notification plugin and create the Android channel.
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onForegroundNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          onBackgroundNotificationResponse,
    );

    // Create the Android notification channel.
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelKey,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
        ),
      );
    }

    _initialized = true;
  }

  /// Check if notification permission is granted (Android 13+).
  Future<bool> isNotificationAllowed() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true;
    final result = await androidPlugin.areNotificationsEnabled();
    return result ?? true;
  }

  /// Request notification permission (Android 13+).
  Future<bool> requestNotificationPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true;
    final result = await androidPlugin.requestNotificationsPermission();
    return result ?? true;
  }

  /// Request exact alarm permission (Android 14+).
  Future<void> requestExactAlarmPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;
    await androidPlugin.requestExactAlarmsPermission();
  }

  /// Create a scheduled notification for a todo.
  Future<void> scheduleTodoNotification(TodoItem todo) async {
    final remindAt = todo.remindAt;
    if (remindAt == null) {
      return;
    }

    final tzTime = tz.TZDateTime.from(remindAt, tz.local);
    final title = _buildNotificationTitle(todo);
    final body = await _buildNotificationBody(todo);
    final id = getNotificationIdForTodo(todo.id);

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelKey,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: todo.id,
    );
  }

  /// Show a notification immediately.
  Future<void> showTodoNotification({
    required int id,
    required String title,
    required String body,
    required String todoId,
  }) async {
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelKey,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: todoId,
    );
  }

  /// Cancel a notification for a todo.
  Future<void> cancelTodoNotification(String todoId) async {
    await _plugin.cancel(id: getNotificationIdForTodo(todoId));
  }

  /// Get notification ID from todo ID (FNV-1a 32-bit hash).
  int getNotificationIdForTodo(String todoId) {
    var hash = 0x811c9dc5;
    for (final unit in todoId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  // ---- Private helpers -----------------------------------------------------

  void _onForegroundNotificationResponse(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    final todoId = response.payload;
    if (todoId != null && todoId.isNotEmpty) {
      onNotificationTap?.call(todoId);
    }
  }

  String _buildNotificationTitle(TodoItem todo) {
    if (todo.text.trim().isNotEmpty) {
      return todo.text;
    }
    return 'Todo reminder';
  }

  Future<String> _buildNotificationBody(TodoItem todo) async {
    if (todo.dueAt == null) {
      return _tr('notification.todoReminder');
    }

    final languageCode = await _getLanguageCode();
    final formattedDate = _formatDateTime(todo.dueAt!);
    return LocaleTextLookup.tr(
      languageCode,
      'notification.dueAt',
      params: {'date': formattedDate},
    );
  }

  Future<String> _getLanguageCode() async {
    if (_languageCode != null) {
      return _languageCode!;
    }

    try {
      final settings = await _settingsRepository.loadSettings();
      _languageCode = settings.languageCode;
    } catch (_) {
      _languageCode = 'zh_CN';
    }

    return _languageCode!;
  }

  Future<String> _tr(String key, {Map<String, String>? params}) async {
    final languageCode = await _getLanguageCode();
    return LocaleTextLookup.tr(languageCode, key, params: params);
  }

  String _formatDateTime(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day $hour:$minute';
  }
}

final localNotificationService = LocalNotificationService();
