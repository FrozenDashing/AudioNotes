import 'package:device_calendar_plus/device_calendar_plus.dart';

import '../repositories/settings_repository.dart';
import '../models/todo_item.dart';

/// Calendar sync status
enum CalendarSyncStatus {
  idle,
  syncing,
  success,
  error,
  permissionDenied,
}

/// Service for managing calendar integration with todos
class CalendarSyncService {
  final DeviceCalendar _calendarPlugin = DeviceCalendar.instance;
  final SettingsRepository _settingsRepository = SettingsRepository();
  String? _languageCode;

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

  Future<String> _buildCalendarTitle(TodoItem todo) async {
    final baseTitle =
        todo.text.trim().isEmpty ? 'Todo reminder' : todo.text.trim();
    if (todo.dueAt == null) {
      return baseTitle;
    }

    final languageCode = await _getLanguageCode();
    final dueSuffix = languageCode == 'en' ? ' deadline' : ' 截止';
    return '$baseTitle$dueSuffix';
  }

  /// Check if calendar permissions are granted
  Future<CalendarPermissionStatus> checkPermissions() async {
    try {
      return await _calendarPlugin.hasPermissions();
    } catch (e) {
      return CalendarPermissionStatus.denied;
    }
  }

  /// Request calendar permissions
  Future<CalendarPermissionStatus> requestPermissions() async {
    try {
      return await _calendarPlugin.requestPermissions();
    } catch (e) {
      return CalendarPermissionStatus.denied;
    }
  }

  /// Get available calendars
  Future<List<Calendar>> getAvailableCalendars() async {
    try {
      return await _calendarPlugin.listCalendars();
    } catch (e) {
      return [];
    }
  }

  /// Get writable calendars
  Future<List<Calendar>> getWritableCalendars() async {
    try {
      final calendars = await getAvailableCalendars();
      return calendars.where((calendar) => !calendar.readOnly).toList();
    } catch (e) {
      return [];
    }
  }

  /// Create or get default calendar
  Future<String?> getDefaultCalendarId() async {
    try {
      final writableCalendars = await getWritableCalendars();
      if (writableCalendars.isNotEmpty) {
        // Return first writable calendar
        return writableCalendars.first.id;
      }

      // If no writable calendar exists, create one
      final calendarId = await _calendarPlugin.createCalendar(
        name: 'AudioNotes',
      );

      return calendarId;
    } catch (e) {
      return null;
    }
  }

  /// Create calendar event from todo
  Future<String?> createTodoEvent(TodoItem todo) async {
    try {
      // Check permissions first
      final permissions = await checkPermissions();
      if (permissions != CalendarPermissionStatus.granted) {
        throw CalendarSyncException(
          'Calendar permissions not granted',
          CalendarSyncStatus.permissionDenied,
        );
      }

      // Get calendar ID
      final calendarId = todo.calendarId ?? await getDefaultCalendarId();
      if (calendarId == null) {
        throw CalendarSyncException(
          'No calendar available',
          CalendarSyncStatus.error,
        );
      }

      // Create event
      final startTime = todo.remindAt ?? todo.dueAt!;
      final endTime = todo.dueAt?.add(const Duration(hours: 1)) ??
          todo.remindAt?.add(const Duration(hours: 1)) ??
          startTime.add(const Duration(hours: 1));
      final title = await _buildCalendarTitle(todo);

      final result = await _calendarPlugin.createEvent(
        calendarId: calendarId,
        title: title,
        startDate: startTime,
        endDate: endTime,
        description: todo.description ?? '',
        isAllDay: todo.dueAt != null && todo.remindAt == null,
      );

      return result;
    } catch (e) {
      throw CalendarSyncException(
        'Failed to create calendar event: ${e.toString()}',
        CalendarSyncStatus.error,
      );
    }
  }

  /// Update calendar event from todo
  Future<void> updateTodoEvent(TodoItem todo) async {
    try {
      if (todo.calendarEventId == null) {
        // No existing event, create new one
        final eventId = await createTodoEvent(todo);
        if (eventId != null) {
          // Update todo with event ID
          // This should be handled by the caller
        }
        return;
      }

      // Update existing event
      final startTime = todo.remindAt ?? todo.dueAt!;
      final endTime = todo.dueAt?.add(const Duration(hours: 1)) ??
          todo.remindAt?.add(const Duration(hours: 1)) ??
          startTime.add(const Duration(hours: 1));
      final title = await _buildCalendarTitle(todo);

      await _calendarPlugin.updateEvent(
        eventId: todo.calendarEventId!,
        title: title,
        description: Patch.set(todo.description ?? ''),
        startDate: startTime,
        endDate: endTime,
      );
    } catch (e) {
      throw CalendarSyncException(
        'Failed to update calendar event: ${e.toString()}',
        CalendarSyncStatus.error,
      );
    }
  }

  /// Delete calendar event
  Future<void> deleteTodoEvent(String eventId) async {
    try {
      await _calendarPlugin.deleteEvent(eventId: eventId);
    } catch (e) {
      throw CalendarSyncException(
        'Failed to delete calendar event: ${e.toString()}',
        CalendarSyncStatus.error,
      );
    }
  }

  /// Sync todo with calendar
  Future<CalendarSyncStatus> syncTodoWithCalendar(TodoItem todo) async {
    try {
      if (todo.remindAt == null && todo.dueAt == null) {
        return CalendarSyncStatus.idle;
      }

      if (todo.calendarEventId == null) {
        // Create new event
        final eventId = await createTodoEvent(todo);
        if (eventId != null) {
          return CalendarSyncStatus.success;
        }
        return CalendarSyncStatus.error;
      } else {
        // Update existing event
        await updateTodoEvent(todo);
        return CalendarSyncStatus.success;
      }
    } catch (e) {
      if (e is CalendarSyncException &&
          e.status == CalendarSyncStatus.permissionDenied) {
        return CalendarSyncStatus.permissionDenied;
      }
      return CalendarSyncStatus.error;
    }
  }

  /// Remove todo from calendar
  Future<CalendarSyncStatus> removeTodoFromCalendar(TodoItem todo) async {
    try {
      if (todo.calendarEventId != null) {
        await deleteTodoEvent(todo.calendarEventId!);
        return CalendarSyncStatus.success;
      }
      return CalendarSyncStatus.idle;
    } catch (e) {
      return CalendarSyncStatus.error;
    }
  }
}

/// Exception for calendar sync operations
class CalendarSyncException implements Exception {
  final String message;
  final CalendarSyncStatus status;

  CalendarSyncException(this.message, this.status);

  @override
  String toString() => message;
}
