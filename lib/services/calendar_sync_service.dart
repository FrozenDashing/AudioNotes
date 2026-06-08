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

class CalendarSyncResult {
  final CalendarSyncStatus status;
  final String? calendarEventId;
  final String? calendarId;

  const CalendarSyncResult({
    required this.status,
    this.calendarEventId,
    this.calendarId,
  });
}

/// Service for managing calendar integration with todos
class CalendarSyncService {
  final DeviceCalendar _calendarPlugin = DeviceCalendar.instance;
  final SettingsRepository _settingsRepository = SettingsRepository();
  String? _languageCode;

  static const String _todoUrlScheme = 'audionotes://todo/';

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

  String _buildTodoUrl(String todoId) {
    return '$_todoUrlScheme${Uri.encodeComponent(todoId)}';
  }

  bool _isEventForTodo(Event event, TodoItem todo) {
    final marker = _buildTodoUrl(todo.id);
    return event.url == marker;
  }

  Future<Event?> _findExistingTodoEvent(TodoItem todo) async {
    final anchor = todo.remindAt ?? todo.dueAt;
    if (anchor == null) {
      return null;
    }

    final calendars = await getAvailableCalendars();
    final calendarIds = calendars.map((calendar) => calendar.id).toList();
    if (calendarIds.isEmpty) {
      return null;
    }

    final start = anchor.subtract(const Duration(days: 365));
    final end = anchor.add(const Duration(days: 365));
    final events = await _calendarPlugin.listEvents(
      start,
      end,
      calendarIds: calendarIds,
    );

    for (final event in events) {
      if (_isEventForTodo(event, todo)) {
        return event;
      }
    }

    return null;
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
  Future<CalendarSyncResult> createTodoEvent(TodoItem todo) async {
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
        url: _buildTodoUrl(todo.id),
        isAllDay: todo.dueAt != null && todo.remindAt == null,
      );

      return CalendarSyncResult(
        status: CalendarSyncStatus.success,
        calendarEventId: result,
        calendarId: calendarId,
      );
    } catch (e) {
      throw CalendarSyncException(
        'Failed to create calendar event: ${e.toString()}',
        CalendarSyncStatus.error,
      );
    }
  }

  /// Update calendar event from todo
  ///
  /// Skips getEvent / listEvents queries because they can trigger native
  /// SIGSEGV on vivo/OPPO/小米 etc. OEM ROMs.  If [calendarEventId] is
  /// stored, updates directly; otherwise falls back to creating a new event.
  Future<CalendarSyncResult> updateTodoEvent(TodoItem todo) async {
    try {
      if (todo.calendarEventId == null) {
        return createTodoEvent(todo);
      }

      final startTime = todo.remindAt ?? todo.dueAt!;
      final endTime = todo.dueAt?.add(const Duration(hours: 1)) ??
          todo.remindAt?.add(const Duration(hours: 1)) ??
          startTime.add(const Duration(hours: 1));
      final title = await _buildCalendarTitle(todo);
      final calendarId = todo.calendarId;

      await _calendarPlugin.updateEvent(
        eventId: todo.calendarEventId!,
        title: title,
        description: Patch.set(todo.description ?? ''),
        url: Patch.set(_buildTodoUrl(todo.id)),
        startDate: startTime,
        endDate: endTime,
      );

      return CalendarSyncResult(
        status: CalendarSyncStatus.success,
        calendarEventId: todo.calendarEventId,
        calendarId: calendarId,
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
  ///
  /// Skips _findExistingTodoEvent (listEvents) because it triggers native
  /// SIGSEGV on vivo/OPPO etc. OEM ROMs.  If [calendarEventId] is stored,
  /// updates in-place; otherwise creates a new event.
  Future<CalendarSyncResult> syncTodoWithCalendar(TodoItem todo) async {
    try {
      if (todo.remindAt == null && todo.dueAt == null) {
        return const CalendarSyncResult(status: CalendarSyncStatus.idle);
      }

      if (todo.calendarEventId == null) {
        return createTodoEvent(todo);
      }

      return updateTodoEvent(todo);
    } catch (e) {
      if (e is CalendarSyncException &&
          e.status == CalendarSyncStatus.permissionDenied) {
        return const CalendarSyncResult(
          status: CalendarSyncStatus.permissionDenied,
        );
      }
      return const CalendarSyncResult(status: CalendarSyncStatus.error);
    }
  }

  /// Remove todo from calendar
  ///
  /// If [todo.calendarEventId] is known, deletes directly by ID without
  /// querying the calendar ContentProvider first.  This avoids native crashes
  /// on some OEM ROMs (vivo/OPPO 等) whose getEvent/listEvents
  /// ContentProvider queries can trigger SIGSEGV, while deleteEvent is a
  /// simple ContentResolver.delete that does not.
  ///
  /// When no [calendarEventId] is stored, the method returns [idle] without
  /// searching (search queries also trigger the same crash).  A small number
  /// of orphaned calendar events is acceptable trade-off for not crashing.
  Future<CalendarSyncStatus> removeTodoFromCalendar(TodoItem todo) async {
    try {
      if (todo.calendarEventId != null) {
        await _calendarPlugin.deleteEvent(eventId: todo.calendarEventId!);
        return CalendarSyncStatus.success;
      }

      // No stored ID — skip the search (crashes on vivo/OPPO etc.).
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
