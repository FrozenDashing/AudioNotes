import 'database_helper.dart';

class ReminderRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> nextNotificationId() {
    return _dbHelper.getNextReminderNotificationId();
  }

  Future<Map<String, dynamic>?> getReminderByTodoId(String todoId) {
    return _dbHelper.getReminderByTodoId(todoId);
  }

  Future<List<Map<String, dynamic>>> getAllReminders() {
    return _dbHelper.getAllReminders();
  }

  Future<List<Map<String, dynamic>>> getDueReminders(DateTime before) {
    return _dbHelper.getRemindersDueBefore(before);
  }

  Future<void> upsertReminder({
    required String reminderId,
    required String todoId,
    required int notificationId,
    required DateTime remindAt,
    int fired = 0,
  }) {
    return _dbHelper.upsertReminder(
      reminderId: reminderId,
      todoId: todoId,
      notificationId: notificationId,
      remindAt: remindAt,
      fired: fired,
    );
  }

  Future<void> deleteReminderByTodoId(String todoId) {
    return _dbHelper.deleteReminderByTodoId(todoId);
  }

  Future<void> markReminderFired(int notificationId) {
    return _dbHelper.markReminderFired(notificationId);
  }
}
