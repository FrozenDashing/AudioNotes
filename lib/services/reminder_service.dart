import '../data/reminder_repository.dart';
import '../data/todo_repository.dart';
import '../models/todo_item.dart';
import 'notification_service.dart';

class ReminderService {
  ReminderService({
    required ReminderRepository reminderRepository,
    required TodoRepository todoRepository,
    required NotificationService notificationService,
  })  : _reminderRepository = reminderRepository,
        _todoRepository = todoRepository,
        _notificationService = notificationService;

  final ReminderRepository _reminderRepository;
  final TodoRepository _todoRepository;
  final NotificationService _notificationService;

  Future<void> initialize() async {
    await _notificationService.initialize();
    await syncPendingReminders();
  }

  Future<void> syncPendingReminders() async {
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

      if (isPastOneTimeReminder) {
        await _notificationService.showTodoReminder(
          notificationId: notificationId,
          title: todo.text.isEmpty ? '待办提醒' : todo.text,
          body: _buildReminderBody(todo),
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
        title: todo.text.isEmpty ? '待办提醒' : todo.text,
        body: _buildReminderBody(todo),
        remindAt: DateTime.fromMillisecondsSinceEpoch(remindAtValue),
        repeatType: todo.repeatType,
        payload: todo.id,
      );
    }
  }

  Future<void> scheduleReminderForTodo(TodoItem todo) async {
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
      await _notificationService.showTodoReminder(
        notificationId: notificationId,
        title: todo.text.isEmpty ? '待办提醒' : todo.text,
        body: _buildReminderBody(todo),
        payload: todo.id,
      );
      await markReminderFired(todo.id);
      return;
    }

    await _notificationService.scheduleTodoReminder(
      notificationId: notificationId,
      title: todo.text.isEmpty ? '待办提醒' : todo.text,
      body: _buildReminderBody(todo),
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

  String _buildReminderBody(TodoItem todo) {
    final parts = <String>[];
    if (todo.dueAt != null) {
      parts.add('截止 ${_formatDateTime(todo.dueAt!)}');
    }
    if (todo.repeatType != TodoRepeatType.none) {
      parts.add(_repeatLabel(todo.repeatType));
    }
    return parts.isEmpty ? '到点提醒' : parts.join(' · ');
  }

  String _repeatLabel(TodoRepeatType repeatType) {
    return switch (repeatType) {
      TodoRepeatType.daily => '每日重复',
      TodoRepeatType.weekly => '每周重复',
      TodoRepeatType.none => '一次性提醒',
    };
  }

  String _formatDateTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }
}
