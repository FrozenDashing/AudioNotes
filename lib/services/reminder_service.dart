import 'package:flutter/foundation.dart' as foundation;

import '../data/reminder_repository.dart';
import '../data/todo_repository.dart';
import '../models/notification_mode.dart';
import '../models/todo_item.dart';
import '../repositories/settings_repository.dart';
import 'awesome_notification_service.dart';
import 'calendar_sync_service.dart';

class ReminderService {
  final ReminderRepository _reminderRepository;
  final TodoRepository _todoRepository;
  final SettingsRepository _settingsRepository;
  final CalendarSyncService _calendarSyncService;
  final AwesomeNotificationService _notificationService;

  ReminderService({
    required ReminderRepository reminderRepository,
    required TodoRepository todoRepository,
    required SettingsRepository settingsRepository,
    required CalendarSyncService calendarSyncService,
    required AwesomeNotificationService notificationService,
  })  : _reminderRepository = reminderRepository,
        _todoRepository = todoRepository,
        _settingsRepository = settingsRepository,
        _calendarSyncService = calendarSyncService,
        _notificationService = notificationService;

  NotificationMode _notificationMode = NotificationMode.none;

  bool get _usesLocalNotifications =>
      _notificationMode == NotificationMode.local ||
      _notificationMode == NotificationMode.awesome;

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
    if (!granted &&
        (_notificationMode == NotificationMode.local ||
            _notificationMode == NotificationMode.awesome)) {
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
        await _scheduleAwesomeNotification(todo);
      } else {
        await _cancelAwesomeNotification(todo);
        await _cancelCalendarReminder(todo);
        await _syncTodoWithCalendar(todo);
      }
    }
  }

  Future<void> syncPendingReminders() async {
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

      if (_usesLocalNotifications) {
        await _scheduleAwesomeNotification(todo);
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
      await _scheduleAwesomeNotification(todo);
      return;
    }

    if (todo.remindAt == null && todo.dueAt == null) {
      await clearReminder(todo.id);
      return;
    }

    await _cancelAwesomeNotification(todo);
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

  Future<void> _scheduleAwesomeNotification(TodoItem todo) async {
    try {
      await _notificationService.createTodoNotification(todo);
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
      foundation.debugPrint('Failed to schedule awesome notification: $error');
    }
  }

  Future<void> _cancelAwesomeNotification(TodoItem todo) async {
    try {
      await _notificationService.cancelTodoNotification(todo.id);

      final updatedTodo = todo.copyWith(
        notificationId: null,
        notificationMode: null,
        syncedAt: null,
      );
      await _todoRepository.updateTodo(updatedTodo);
    } catch (error) {
      foundation.debugPrint('Failed to cancel awesome notification: $error');
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
}
