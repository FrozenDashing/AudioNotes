import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

import '../models/todo_item.dart';
import '../l10n/locale_text_lookup.dart';
import '../repositories/settings_repository.dart';
import 'notification_controller.dart';

/// Service for managing awesome notifications.
class AwesomeNotificationService {
  static const String _channelKey = 'todo_channel';
  bool _initialized = false;
  final SettingsRepository _settingsRepository = SettingsRepository();
  String? _languageCode;

  /// Initialize the notification service.
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: _channelKey,
          channelName: 'Todo Notifications',
          channelDescription: 'Notifications for todo reminders',
          defaultColor: const Color(0xFF9D50DD),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
        ),
      ],
    );

    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: NotificationController.onActionReceivedMethod,
      onNotificationCreatedMethod:
          NotificationController.onNotificationCreatedMethod,
      onNotificationDisplayedMethod:
          NotificationController.onNotificationDisplayedMethod,
      onDismissActionReceivedMethod:
          NotificationController.onDismissActionReceivedMethod,
    );

    _initialized = true;
  }

  /// Check if notifications are allowed.
  Future<bool> isNotificationAllowed() async {
    return AwesomeNotifications().isNotificationAllowed();
  }

  /// Request notification permissions.
  Future<bool> requestNotificationPermission() async {
    return AwesomeNotifications().requestPermissionToSendNotifications();
  }

  /// Create a notification for a todo.
  Future<void> createTodoNotification(TodoItem todo) async {
    final remindAt = todo.remindAt;
    if (remindAt == null) {
      return;
    }

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: getNotificationIdForTodo(todo.id),
        channelKey: _channelKey,
        title: _buildNotificationTitle(todo),
        body: await _buildNotificationBody(todo),
        notificationLayout: NotificationLayout.Default,
        payload: {'todoId': todo.id},
      ),
      schedule: NotificationCalendar.fromDate(
        date: remindAt,
        allowWhileIdle: true,
        preciseAlarm: true,
        repeats: false,
      ),
    );
  }

  /// Update a notification for a todo.
  Future<void> updateTodoNotification(TodoItem todo) async {
    await cancelTodoNotification(todo.id);
    await createTodoNotification(todo);
  }

  /// Cancel a notification for a todo.
  Future<void> cancelTodoNotification(String todoId) async {
    await AwesomeNotifications().cancel(getNotificationIdForTodo(todoId));
  }

  /// Get notification ID from todo ID.
  int getNotificationIdForTodo(String todoId) {
    var hash = 0x811c9dc5;
    for (final unit in todoId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  String _buildNotificationTitle(TodoItem todo) {
    if (todo.text.trim().isNotEmpty) {
      return todo.text;
    }
    return 'Todo reminder';
  }

  /// Build notification body from todo.
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

  /// Format datetime for display.
  String _formatDateTime(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day $hour:$minute';
  }
}
