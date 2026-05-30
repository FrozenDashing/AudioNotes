import 'dart:io';
import 'package:flutter/foundation.dart' as foundation;
import 'package:uuid/uuid.dart';
import '../models/todo_item.dart';
import '../models/todo_priority.dart';
import '../models/todo_query_options.dart';
import 'database_helper.dart';
import '../utils/audio_file_cleanup.dart';
import '../models/settings_state.dart';

/// Repository for managing todo items with proper lifecycle management
class TodoRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  /// Insert a new todo in recognizing state after recording ends
  Future<TodoItem> insertRecognizing({
    required String audioPath,
    String text = '',
    TodoPriority priority = TodoPriority.normal,
  }) async {
    final orderIndex = await _dbHelper.getNextOrderIndex();

    final todo = TodoItem(
      id: _uuid.v4(),
      text: text,
      rawTranscript: text,
      createdAt: DateTime.now(),
      audioPath: audioPath,
      taskState: TodoTaskState.recognizing,
      status: TodoStatus.pending,
      priority: priority,
      orderIndex: orderIndex,
    );

    return await _dbHelper.insertTodo(todo);
  }

  /// Backward-compatible alias for inserting a recognizing todo
  Future<TodoItem> insertRecording({
    required String audioPath,
    String text = '',
  }) {
    return insertRecognizing(audioPath: audioPath, text: text);
  }

  /// Update todo to recognizing state
  Future<void> updateToRecognizing(
    String id, {
    String? audioPath,
  }) async {
    final todo = await _dbHelper.getTodoById(id);
    if (todo != null) {
      final updated = todo.copyWith(
        taskState: TodoTaskState.recognizing,
        audioPath: audioPath ?? todo.audioPath,
        updatedAt: DateTime.now(),
      );
      await _dbHelper.updateTodo(updated);
    }
  }

  /// Complete recognition successfully
  Future<void> completeRecognition({
    required String id,
    required String text,
    String? modelVersion,
    String? rawTranscript,
  }) async {
    final todo = await _dbHelper.getTodoById(id);
    if (todo != null) {
      final originalAudioPath = todo.audioPath;

      final updated = todo.copyWith(
        text: text,
        rawTranscript: rawTranscript ?? text,
        taskState: TodoTaskState.ready,
        modelVersion: modelVersion,
        audioPath: null, // we no longer keep audio after saving rawTranscript
        updatedAt: DateTime.now(),
      );

      await _dbHelper.updateTodo(updated);

      // Delete the original audio file from disk if present
      if (originalAudioPath != null && originalAudioPath.isNotEmpty) {
        try {
          final file = File(originalAudioPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          foundation.debugPrint('Failed to delete audio after recognition: $e');
        }
      }
    }
  }

  /// Mark recognition as failed
  Future<void> markFailed({
    required String id,
    required String errorMessage,
  }) async {
    final todo = await _dbHelper.getTodoById(id);
    if (todo != null) {
      final updated = todo.copyWith(
        taskState: TodoTaskState.failed,
        errorMessage: errorMessage,
        updatedAt: DateTime.now(),
      );
      await _dbHelper.updateTodo(updated);
    }
  }

  /// Toggle todo completion status
  Future<void> toggleStatus(String id) async {
    await _dbHelper.toggleStatus(id);
  }

  /// Update the text of a todo item
  Future<void> updateText(String id, String newText) async {
    final todo = await _dbHelper.getTodoById(id);
    if (todo == null) return;

    final trimmedText = newText.trim();
    final updatedText = trimmedText.isEmpty &&
            (todo.rawTranscript != null && todo.rawTranscript!.isNotEmpty)
        ? todo.rawTranscript!
        : trimmedText;

    final updated = todo.copyWith(
      text: updatedText,
      updatedAt: DateTime.now(),
    );
    await _dbHelper.updateTodo(updated);
  }

  /// Update the due time of a todo item
  Future<TodoItem?> updateDueAt(String id, DateTime? dueAt) async {
    final rows = await _dbHelper.updateDueAt(id, dueAt);
    if (rows == 0) return null;
    return _dbHelper.getTodoById(id);
  }

  /// Update the reminder time of a todo item
  Future<TodoItem?> updateRemindAt(String id, DateTime? remindAt) async {
    final rows = await _dbHelper.updateRemindAt(id, remindAt);
    if (rows == 0) return null;
    return _dbHelper.getTodoById(id);
  }

  /// Update the repeat configuration of a todo item
  Future<void> updateRepeatRule(
    String id,
    TodoRepeatType repeatType, {
    String? repeatRule,
  }) async {
    await _dbHelper.updateRepeatRule(
      id,
      repeatType,
      repeatRule: repeatRule,
    );
  }

  /// Update the category of a todo item
  Future<void> updateCategory(String id, String? categoryId) async {
    await _dbHelper.updateCategory(id, categoryId);
  }

  /// Update the priority of a todo item
  Future<void> updatePriority(String id, TodoPriority priority) async {
    await _dbHelper.updatePriority(id, priority);
  }

  /// Set tags for a todo item
  Future<void> setTags(String todoId, List<String> tagIds) async {
    await _dbHelper.setTagsForTodo(todoId, tagIds);
  }

  /// Update the pinned state of a todo item
  Future<void> updatePinned(String id, bool pinned) async {
    await _dbHelper.updatePinned(id, pinned);
  }

  /// Set todo completion status explicitly
  Future<TodoItem?> setStatus(String id, TodoStatus status) async {
    return _dbHelper.setStatus(id, status);
  }

  /// Delete todo and its associated audio file
  Future<void> deleteTodo(String id) async {
    final todo = await _dbHelper.getTodoById(id);
    if (todo == null) return;

    await _dbHelper.deleteReminderByTodoId(id);
    await _dbHelper.deleteTodo(id);
  }

  /// Restore a todo from the trash
  Future<TodoItem?> restoreTodo(String id) async {
    final todo = await _dbHelper.getTodoById(id, includeDeleted: true);
    if (todo == null || todo.deletedAt == null) {
      return null;
    }

    final rows = await _dbHelper.restoreTodo(id);
    if (rows == 0) {
      return null;
    }

    return _dbHelper.getTodoById(id, includeDeleted: true);
  }

  /// Permanently delete a todo and its stored audio file.
  Future<void> purgeTodoPermanently(String id) async {
    final todo = await _dbHelper.getTodoById(id, includeDeleted: true);
    final audioPath = todo?.audioPath;

    await _dbHelper.deleteReminderByTodoId(id);
    await _dbHelper.purgeTodoPermanently(id);

    if (audioPath != null && audioPath.isNotEmpty) {
      try {
        final file = File(audioPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        foundation.debugPrint('Error deleting audio file: $e');
      }
    }
  }

  /// Purge todos that have been deleted longer than the configured interval.
  Future<void> purgeExpiredDeletedTodos(TrashAutoPurgeInterval interval) async {
    if (interval == TrashAutoPurgeInterval.never) {
      return;
    }

    final cutoff = DateTime.now().subtract(_durationForInterval(interval));
    await _dbHelper.purgeDeletedTodosBefore(cutoff);
  }

  /// Permanently delete every todo currently in trash.
  Future<void> purgeAllDeletedTodos() async {
    await _dbHelper.purgeAllDeletedTodos();
  }

  /// Get todos using unified query options
  Future<List<TodoItem>> getTodos(
    TodoQueryOptions options, {
    bool sortInDatabase = true,
  }) async {
    return await _dbHelper.getTodos(
      options,
      sortInDatabase: sortInDatabase,
    );
  }

  /// Get all todos (legacy helper)
  Future<List<TodoItem>> getAllTodos({bool sortByOrder = false}) async {
    return await _dbHelper.getAllTodos(sortByOrder: sortByOrder);
  }

  /// Get todos by task state
  Future<List<TodoItem>> getTodosByTaskState(TodoTaskState state) async {
    return await _dbHelper.getTodosByTaskState(state);
  }

  /// Get todos by category
  Future<List<TodoItem>> getTodosByCategory(String categoryId) async {
    return await _dbHelper.getTodosByCategory(categoryId);
  }

  /// Get todos by tag
  Future<List<TodoItem>> getTodosByTag(String tagId) async {
    return await _dbHelper.getTodosByTag(tagId);
  }

  /// Get a single todo by ID
  Future<TodoItem?> getTodoById(String id) async {
    return _dbHelper.getTodoById(id);
  }

  /// Get todos currently in the trash.
  Future<List<TodoItem>> getDeletedTodos() async {
    return await _dbHelper.getDeletedTodos();
  }

  /// Clean up orphaned audio files
  Future<void> cleanupOrphanedFiles() async {
    try {
      // Get all valid audio paths from database
      final todos = await _dbHelper.getAllTodos(includeDeleted: true);
      final validAudioPaths = todos
          .where((todo) => todo.audioPath != null && todo.audioPath!.isNotEmpty)
          .map((todo) => todo.audioPath!)
          .toList();

      // Clean up orphaned files
      await AudioFileCleanup.cleanOrphanedFiles(validAudioPaths);
    } catch (e) {
      foundation.debugPrint('Error during cleanup: $e');
    }
  }

  /// Get total storage used by audio files
  Future<int> getTotalAudioStorageSize() async {
    return await AudioFileCleanup.getTotalAudioSize();
  }

  Duration _durationForInterval(TrashAutoPurgeInterval interval) {
    switch (interval) {
      case TrashAutoPurgeInterval.oneDay:
        return const Duration(days: 1);
      case TrashAutoPurgeInterval.threeDays:
        return const Duration(days: 3);
      case TrashAutoPurgeInterval.sevenDays:
        return const Duration(days: 7);
      case TrashAutoPurgeInterval.thirtyDays:
        return const Duration(days: 30);
      case TrashAutoPurgeInterval.never:
        return Duration.zero;
    }
  }
}
