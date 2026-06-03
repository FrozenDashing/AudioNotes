import 'dart:async';

import 'package:flutter/foundation.dart' as foundation;

import '../data/reminder_repository.dart';
import '../data/todo_repository.dart';
import '../models/notification_mode.dart';
import '../models/todo_item.dart';
import '../repositories/settings_repository.dart';
import 'calendar_sync_service.dart';
import 'local_notification_service.dart';
import 'notification_controller.dart';

class ReminderService {
  final ReminderRepository _reminderRepository;
  final TodoRepository _todoRepository;
  final SettingsRepository _settingsRepository;
  final CalendarSyncService _calendarSyncService;
  final LocalNotificationService _notificationService;

  ReminderService({
    required ReminderRepository reminderRepository,
    required TodoRepository todoRepository,
    required SettingsRepository settingsRepository,
    required CalendarSyncService calendarSyncService,
    required LocalNotificationService notificationService,
  })  : _reminderRepository = reminderRepository,
        _todoRepository = todoRepository,
        _settingsRepository = settingsRepository,
        _calendarSyncService = calendarSyncService,
        _notificationService = notificationService;

  NotificationMode _notificationMode = NotificationMode.none;

  bool get _usesLocalNotifications =>
      _notificationMode == NotificationMode.local;

  Future<void> initialize() async {
    await _notificationService.initialize();
    await _loadNotificationMode();
    await _ensureNotificationPermissionState();
    await syncPendingReminders();
  }

  Future<void> setNotificationMode(NotificationMode mode) async {
    _notificationMode = mode;
    await _settingsRepository.saveNotificationMode(mode.stringValue);
    await _syncAllTodosWithMode();
  }

  NotificationMode get notificationMode => _notificationMode;

  Future<void> _ensureNotificationPermissionState() async {
    final allowed = await _notificationService.isNotificationAllowed();
    if (allowed) {
      return;
    }

    final granted = await _notificationService.requestNotificationPermission();
    if (!granted && _notificationMode == NotificationMode.local) {
      await setNotificationMode(NotificationMode.none);
    }
  }

  Future<void> _loadNotificationMode() async {
    try {
      final modeString = await _settingsRepository.loadNotificationMode();
      _notificationMode = NotificationModeExtension.fromString(modeString);
    } catch (error) {
      foundation.debugPrint(
        'Failed to load notification mode, defaulting to local: $error',
      );
      _notificationMode = NotificationMode.local;
    }
  }

  Future<void> _syncAllTodosWithMode() async {
    final todos = await _todoRepository.getAllTodos();
    for (final todo in todos) {
      if (todo.status == TodoStatus.completed) {
        await clearReminder(todo.id);
        continue;
      }

      if (todo.remindAt == null && todo.dueAt == null) {
        await clearReminder(todo.id);
        continue;
      }

      if (_notificationMode == NotificationMode.none) {
        await clearReminder(todo.id);
        continue;
      }

      if (_usesLocalNotifications) {
        if (todo.remindAt == null) {
          await clearReminder(todo.id);
          continue;
        }

        await _cancelCalendarReminder(todo);
        await _scheduleLocalNotification(todo);
      } else {
        await _cancelLocalNotification(todo);
        await _cancelCalendarReminder(todo);
        await _syncTodoWithCalendar(todo);
      }
    }
  }

  Future<void> syncPendingReminders() async {
    // Consume externally-recorded fired notifications
    final firedTodoIds = await NotificationFiredTracker.consumeFired();
    for (final todoId in firedTodoIds) {
      await markReminderFired(todoId);
    }

    final now = DateTime.now();
    final reminders = await _reminderRepository.getAllReminders();
    for (final reminder in reminders) {
      final todoId = reminder['todo_id'] as String?;
      final fired = (reminder['fired'] as int? ?? 0) == 1;
      if (todoId == null) {
        continue;
      }

      final todo = await _todoRepository.getTodoById(todoId);
      if (todo == null || todo.remindAt == null) {
        await clearReminder(todoId);
        continue;
      }

      if (_notificationMode == NotificationMode.none) {
        await clearReminder(todoId);
        continue;
      }

      if (fired) {
        continue;
      }

      // Heuristic: if remindAt is in the past, treat as already fired
      if (todo.remindAt!.isBefore(now)) {
        await markReminderFired(todoId);
        continue;
      }

      if (_usesLocalNotifications) {
        await _scheduleLocalNotification(todo);
      } else {
        await _syncTodoWithCalendar(todo);
      }
    }
  }

  Future<void> scheduleReminderForTodo(TodoItem todo) async {
    if (_notificationMode == NotificationMode.none) {
      await clearReminder(todo.id);
      return;
    }

    if (_usesLocalNotifications) {
      if (todo.remindAt == null) {
        await clearReminder(todo.id);
        return;
      }

      await _cancelCalendarReminder(todo);
      await _scheduleLocalNotification(todo);
      return;
    }

    if (todo.remindAt == null && todo.dueAt == null) {
      await clearReminder(todo.id);
      return;
    }

    await _cancelLocalNotification(todo);
    await _syncTodoWithCalendar(todo);
  }

  Future<void> updateReminderForTodo(TodoItem todo) async {
    await scheduleReminderForTodo(todo);
  }

  Future<void> clearReminder(String todoId) async {
    await _notificationService.cancelTodoNotification(todoId);

    final todo = await _todoRepository.getTodoById(todoId);
    if (todo != null) {
      await _cancelCalendarReminder(todo);
    }

    await _reminderRepository.deleteReminderByTodoId(todoId);
  }

  Future<void> _scheduleLocalNotification(TodoItem todo) async {
    try {
      await _notificationService.scheduleTodoNotification(todo);
      final notificationId =
          _notificationService.getNotificationIdForTodo(todo.id);
      await _reminderRepository.upsertReminder(
        reminderId: todo.id,
        todoId: todo.id,
        notificationId: notificationId,
        remindAt: todo.remindAt!,
        fired: 0,
      );

      final updatedTodo = todo.copyWith(
        notificationId: notificationId,
        notificationMode: NotificationMode.local.stringValue,
        syncedAt: DateTime.now(),
      );
      await _todoRepository.updateTodo(updatedTodo);
    } catch (error) {
      foundation.debugPrint('Failed to schedule local notification: $error');
    }
  }

  Future<void> _cancelLocalNotification(TodoItem todo) async {
    try {
      await _notificationService.cancelTodoNotification(todo.id);

      final updatedTodo = todo.copyWith(
        notificationId: null,
        notificationMode: null,
        syncedAt: null,
      );
      await _todoRepository.updateTodo(updatedTodo);
    } catch (error) {
      foundation.debugPrint('Failed to cancel local notification: $error');
    }
  }

  Future<void> _syncTodoWithCalendar(TodoItem todo) async {
    try {
      final result = await _calendarSyncService.syncTodoWithCalendar(todo);
      final updatedTodo = todo.copyWith(
        calendarEventId: result.calendarEventId ?? todo.calendarEventId,
        calendarId: result.calendarId ?? todo.calendarId,
        calendarMode: _notificationMode.stringValue,
        syncStatus: result.status.name,
        syncedAt: DateTime.now(),
      );
      await _todoRepository.updateTodo(updatedTodo);
    } catch (error) {
      foundation.debugPrint('Failed to sync todo with calendar: $error');
    }
  }

  Future<void> _cancelCalendarReminder(TodoItem todo) async {
    try {
      await _calendarSyncService.removeTodoFromCalendar(todo);
      final updatedTodo = todo.copyWith(
        calendarEventId: null,
        calendarMode: null,
        syncStatus: 'cancelled',
        syncedAt: DateTime.now(),
      );
      await _todoRepository.updateTodo(updatedTodo);
    } catch (error) {
      foundation.debugPrint('Failed to cancel calendar reminder: $error');
    }
  }

  Future<void> markReminderFired(String todoId) async {
    final existing = await _reminderRepository.getReminderByTodoId(todoId);
    final notificationId = existing?['notification_id'] as int?;
    if (notificationId != null) {
      await _reminderRepository.markReminderFired(notificationId);
    }
  }

  /// Re-schedule all pending (unfired, future-dated) local notifications.
  ///
  /// Safe to call from a background isolate (e.g. WorkManager) because it
  /// constructs its own dependencies without Riverpod.
  Future<void> rescheduleAllPendingReminders() async {
    await _loadNotificationMode();
    if (!_usesLocalNotifications) {
      return;
    }

    final firedTodoIds = await NotificationFiredTracker.consumeFired();
    for (final todoId in firedTodoIds) {
      await markReminderFired(todoId);
    }

    final now = DateTime.now();
    final reminders = await _reminderRepository.getAllReminders();
    for (final reminder in reminders) {
      final todoId = reminder['todo_id'] as String?;
      final fired = (reminder['fired'] as int? ?? 0) == 1;
      if (todoId == null || fired) {
        continue;
      }

      final todo = await _todoRepository.getTodoById(todoId);
      if (todo == null ||
          todo.remindAt == null ||
          todo.status == TodoStatus.completed ||
          todo.deletedAt != null) {
        await clearReminder(todoId);
        continue;
      }

      if (todo.remindAt!.isBefore(now)) {
        await markReminderFired(todoId);
        continue;
      }

      try {
        await _notificationService.scheduleTodoNotification(todo);
      } catch (error) {
        foundation.debugPrint(
          'Failed to reschedule notification for ${todo.id}: $error',
        );
      }
    }
  }
}
