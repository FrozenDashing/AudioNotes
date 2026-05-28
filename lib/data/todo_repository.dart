import 'dart:io';
import '../models/todo_item.dart';
import '../models/todo_priority.dart';
import '../models/todo_query_options.dart';
import 'database_helper.dart';
import '../utils/audio_file_cleanup.dart';

/// Repository for managing todo items with proper lifecycle management
class TodoRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Insert a new todo in recognizing state after recording ends
  Future<TodoItem> insertRecognizing({
    required String audioPath,
    String text = '',
    TodoPriority priority = TodoPriority.normal,
  }) async {
    final orderIndex = await _dbHelper.getNextOrderIndex();

    final todo = TodoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
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
    int? durationMs,
    String? modelVersion,
    double? confidence,
  }) async {
    final todo = await _dbHelper.getTodoById(id);
    if (todo != null) {
      final updated = todo.copyWith(
        text: text,
        rawTranscript: text,
        taskState: TodoTaskState.ready,
        durationMs: durationMs,
        modelVersion: modelVersion,
        confidence: confidence,
        updatedAt: DateTime.now(),
      );
      await _dbHelper.updateTodo(updated);
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

    // Delete audio file if exists
    if (todo.audioPath != null && todo.audioPath!.isNotEmpty) {
      try {
        final file = File(todo.audioPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Error deleting audio file: $e');
      }
    }

    await _dbHelper.deleteReminderByTodoId(id);

    // Delete from database
    await _dbHelper.deleteTodo(id);
  }

  /// Get todos using unified query options
  Future<List<TodoItem>> getTodos(TodoQueryOptions options) async {
    return await _dbHelper.getTodos(options);
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

  /// Clean up orphaned audio files
  Future<void> cleanupOrphanedFiles() async {
    try {
      // Get all valid audio paths from database
      final todos = await getAllTodos();
      final validAudioPaths = todos
          .where((todo) => todo.audioPath != null && todo.audioPath!.isNotEmpty)
          .map((todo) => todo.audioPath!)
          .toList();

      // Clean up orphaned files
      await AudioFileCleanup.cleanOrphanedFiles(validAudioPaths);
    } catch (e) {
      print('Error during cleanup: $e');
    }
  }

  /// Get total storage used by audio files
  Future<int> getTotalAudioStorageSize() async {
    return await AudioFileCleanup.getTotalAudioSize();
  }
}
