import '../data/reminder_repository.dart';
import '../data/todo_repository.dart';
import '../l10n/locale_text_lookup.dart';
import '../models/todo_item.dart';
import '../repositories/settings_repository.dart';
import 'notification_service.dart';

class ReminderService {
  ReminderService({
    required ReminderRepository reminderRepository,
    required TodoRepository todoRepository,
    required NotificationService notificationService,
    required SettingsRepository settingsRepository,
  })  : _reminderRepository = reminderRepository,
        _todoRepository = todoRepository,
        _notificationService = notificationService,
        _settingsRepository = settingsRepository;

  final ReminderRepository _reminderRepository;
  final TodoRepository _todoRepository;
  final NotificationService _notificationService;
  final SettingsRepository _settingsRepository;

  Future<void> initialize() async {
    await _notificationService.initialize();
    await syncPendingReminders();
  }

  Future<void> syncPendingReminders() async {
    final languageCode = await _getLanguageCode();
    final reminders = await _reminderRepository.getAllReminders();
    for (final reminder in reminders) {
      final todoId = reminder['todo_id'] as String?;
      final notificationId = reminder['notification_id'] as int?;
      final remindAtValue = reminder['remind_at'] as int?;
      final fired = (reminder['fired'] as int? ?? 0) == 1;

      if (todoId == null || notificationId == null || remindAtValue == null) {
        continue;
      }

      final todo = await _todoRepository.getTodoById(todoId);
      if (todo == null || todo.remindAt == null) {
        await clearReminder(todoId);
        continue;
      }

      final isPastOneTimeReminder = todo.repeatType == TodoRepeatType.none &&
          todo.remindAt!.isBefore(DateTime.now());

      final title = todo.text.isEmpty
          ? await _lookup(languageCode, 'reminder.title')
          : todo.text;
      final body = await _buildReminderBody(todo, languageCode);

      if (isPastOneTimeReminder) {
        await _notificationService.showTodoReminder(
          notificationId: notificationId,
          title: title,
          body: body,
          payload: todo.id,
        );
        await markReminderFired(todoId);
        continue;
      }

      if (fired) {
        continue;
      }

      await _notificationService.scheduleTodoReminder(
        notificationId: notificationId,
        title: title,
        body: body,
        remindAt: DateTime.fromMillisecondsSinceEpoch(remindAtValue),
        repeatType: todo.repeatType,
        payload: todo.id,
      );
    }
  }

  Future<void> scheduleReminderForTodo(TodoItem todo) async {
    final languageCode = await _getLanguageCode();
    if (todo.remindAt == null) {
      await clearReminder(todo.id);
      return;
    }

    final existing = await _reminderRepository.getReminderByTodoId(todo.id);
    final notificationId = (existing?['notification_id'] as int?) ??
        await _reminderRepository.nextNotificationId();
    final reminderId = (existing?['id'] as String?) ?? todo.id;

    await _reminderRepository.upsertReminder(
      reminderId: reminderId,
      todoId: todo.id,
      notificationId: notificationId,
      remindAt: todo.remindAt!,
      fired: 0,
    );

    if (todo.repeatType == TodoRepeatType.none &&
        todo.remindAt!.isBefore(DateTime.now())) {
      final title = todo.text.isEmpty
          ? await _lookup(languageCode, 'reminder.title')
          : todo.text;
      final body = await _buildReminderBody(todo, languageCode);
      await _notificationService.showTodoReminder(
        notificationId: notificationId,
        title: title,
        body: body,
        payload: todo.id,
      );
      await markReminderFired(todo.id);
      return;
    }

    final title = todo.text.isEmpty
        ? await _lookup(languageCode, 'reminder.title')
        : todo.text;
    final body = await _buildReminderBody(todo, languageCode);

    await _notificationService.scheduleTodoReminder(
      notificationId: notificationId,
      title: title,
      body: body,
      remindAt: todo.remindAt!,
      repeatType: todo.repeatType,
      payload: todo.id,
    );
  }

  Future<void> clearReminder(String todoId) async {
    final existing = await _reminderRepository.getReminderByTodoId(todoId);
    final notificationId = existing?['notification_id'] as int?;

    if (notificationId != null) {
      await _notificationService.cancel(notificationId);
    }

    await _notificationService.cancelByPayload(todoId);

    await _reminderRepository.deleteReminderByTodoId(todoId);
  }

  Future<void> markReminderFired(String todoId) async {
    final existing = await _reminderRepository.getReminderByTodoId(todoId);
    final notificationId = existing?['notification_id'] as int?;
    if (notificationId != null) {
      await _reminderRepository.markReminderFired(notificationId);
    }
  }

  Future<String> _buildReminderBody(TodoItem todo, String languageCode) async {
    final parts = <String>[];
    if (todo.dueAt != null) {
      final dueLabel = await _lookup(languageCode, 'reminder.dueLabel');
      parts.add('$dueLabel ${_formatDateTime(todo.dueAt!)}');
    }
    if (todo.repeatType != TodoRepeatType.none) {
      parts.add(await _repeatLabel(todo.repeatType, languageCode));
    }
    if (parts.isEmpty) {
      return _lookup(languageCode, 'reminder.onTime');
    }
    return parts.join(' · ');
  }

  Future<String> _repeatLabel(
      TodoRepeatType repeatType, String languageCode) async {
    final key = switch (repeatType) {
      TodoRepeatType.daily => 'reminder.repeat.daily',
      TodoRepeatType.weekly => 'reminder.repeat.weekly',
      TodoRepeatType.none => 'reminder.repeat.none',
    };
    return _lookup(languageCode, key);
  }

  Future<String> _getLanguageCode() async {
    try {
      final settings = await _settingsRepository.loadSettings();
      return settings.languageCode;
    } catch (_) {
      return 'zh_CN';
    }
  }

  Future<String> _lookup(String languageCode, String key) {
    return LocaleTextLookup.tr(languageCode, key);
  }

  String _formatDateTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }
}
