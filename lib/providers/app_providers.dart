import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database_helper.dart';
import '../models/todo_item.dart';
import '../services/recorder_service.dart';
import '../services/recognition_service.dart';
import '../services/audio_playback_service.dart';
import '../services/model_manager_service.dart';
import '../data/todo_repository.dart';
import '../domain/usecases/create_todo_from_recording_usecase.dart';

/// Provider for database helper
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

/// Provider for todo repository
final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  return TodoRepository();
});

/// Provider for recorder service
final recorderServiceProvider = Provider<RecorderService>((ref) {
  return RecorderService();
});

/// Provider for recognition service
final recognitionServiceProvider = Provider<RecognitionService>((ref) {
  return RecognitionService();
});

/// Provider for audio playback service
final audioPlaybackServiceProvider = Provider<AudioPlaybackService>((ref) {
  final service = AudioPlaybackService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for model manager service
final modelManagerServiceProvider = Provider<ModelManagerService>((ref) {
  return ModelManagerService();
});

/// Provider for create todo use case
final createTodoUseCaseProvider =
    Provider<CreateTodoFromRecordingUseCase>((ref) {
  return CreateTodoFromRecordingUseCase(
    recorder: ref.read(recorderServiceProvider),
    recognition: ref.read(recognitionServiceProvider),
    repository: ref.read(todoRepositoryProvider),
  );
});

/// State for recording status
enum RecordingState {
  idle,
  recording,
  recognizing, // Audio recorded, being recognized
  completed, // Recognition completed
  failed // Recognition failed
}

class RecordingNotifier extends Notifier<RecordingState> {
  @override
  RecordingState build() => RecordingState.idle;

  /// Start recording using RecorderService
  Future<void> start() async {
    final recorder = ref.read(recorderServiceProvider);

    try {
      final wavPath = await recorder.startRecording();

      if (wavPath != null) {
        state = RecordingState.recording;
      } else {
        throw Exception('Failed to start recording');
      }
    } catch (e) {
      state = RecordingState.idle;
      rethrow;
    }
  }

  /// Stop recording and trigger recognition workflow
  Future<void> stop() async {
    try {
      state = RecordingState.recognizing;

      // Execute the complete workflow: record → recognize → create todo
      final useCase = ref.read(createTodoUseCaseProvider);
      await useCase.execute();

      state = RecordingState.completed;

      // ✅ Refresh todo list to show the newly created todo
      await ref.read(todoListProvider.notifier).loadTodos();

      // Reset to idle after a short delay
      await Future.delayed(const Duration(seconds: 1));
      state = RecordingState.idle;
    } catch (e) {
      print('Recording workflow failed: $e');
      state = RecordingState.failed;

      // Reset to idle after showing error
      await Future.delayed(const Duration(seconds: 2));
      state = RecordingState.idle;
      rethrow;
    }
  }

  void reset() => state = RecordingState.idle;
}

final recordingStateProvider =
    NotifierProvider<RecordingNotifier, RecordingState>(() {
  return RecordingNotifier();
});

/// Notifier for current partial transcript
class PartialTranscriptNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String newText) {
    state = newText;
  }
}

/// State for current partial transcript
final partialTranscriptProvider =
    NotifierProvider<PartialTranscriptNotifier, String>(() {
  return PartialTranscriptNotifier();
});

/// State for all todo items
class TodoListNotifier extends AsyncNotifier<List<TodoItem>> {
  late final TodoRepository _repository;
  Set<String> _selectedIds = {}; // Track selected todo IDs
  final Set<String> _statusUpdatingIds =
      {}; // Track items currently updating status

  @override
  Future<List<TodoItem>> build() async {
    _repository = ref.read(todoRepositoryProvider);
    // Load todos on initialization
    final todos = await _repository.getAllTodos(sortByOrder: true);
    return todos;
  }

  /// Get currently selected todo IDs
  Set<String> get selectedIds => _selectedIds;

  /// Toggle selection of a todo
  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    state = AsyncValue.data(List<TodoItem>.from(state.value ?? const []));
  }

  /// Clear all selections
  void clearSelection() {
    _selectedIds.clear();
    state = AsyncValue.data(List<TodoItem>.from(state.value ?? const []));
  }

  /// Remove a single item from the selection set
  void removeSelection(String id) {
    _selectedIds.remove(id);
    state = AsyncValue.data(List<TodoItem>.from(state.value ?? const []));
  }

  /// Select all pending todos
  void selectAllPending() {
    final todos = state.value ?? [];
    _selectedIds = todos
        .where((todo) => todo.status == TodoStatus.pending)
        .map((todo) => todo.id)
        .toSet();
    state = AsyncValue.data(List<TodoItem>.from(todos));
  }

  /// Select all todos.
  void selectAllTodos() {
    final todos = state.value ?? [];
    _selectedIds = todos.map((todo) => todo.id).toSet();
    state = AsyncValue.data(List<TodoItem>.from(todos));
  }

  /// Check if a todo is selected
  bool isSelected(String id) {
    return _selectedIds.contains(id);
  }

  /// Check if a todo status update is in progress
  bool isStatusUpdating(String id) {
    return _statusUpdatingIds.contains(id);
  }

  /// Load all todos from database
  Future<void> loadTodos() async {
    final todos = await _repository.getAllTodos(sortByOrder: true);
    state = AsyncValue.data(todos);
  }

  /// Toggle todo completion status
  Future<void> toggleStatus(String id) async {
    final currentValue =
        state.value ?? await _repository.getAllTodos(sortByOrder: true);
    final currentTodo = currentValue
        .where((todo) => todo.id == id)
        .cast<TodoItem?>()
        .firstWhere(
          (todo) => todo != null,
          orElse: () => null,
        );

    if (currentTodo == null) {
      await _repository.toggleStatus(id);
      await loadTodos();
      return;
    }

    await setCompletionStatus(
      id,
      currentTodo.status == TodoStatus.pending
          ? TodoStatus.completed
          : TodoStatus.pending,
    );
  }

  /// Set a todo's completion status explicitly.
  Future<void> setCompletionStatus(String id, TodoStatus status) async {
    if (_statusUpdatingIds.contains(id)) {
      return;
    }

    _statusUpdatingIds.add(id);
    final currentValue =
        state.value ?? await _repository.getAllTodos(sortByOrder: true);
    try {
      final currentTodo = currentValue
          .where((todo) => todo.id == id)
          .cast<TodoItem?>()
          .firstWhere(
            (todo) => todo != null,
            orElse: () => null,
          );

      if (currentTodo == null) {
        final updated = await _repository.setStatus(id, status);
        if (updated == null) {
          await loadTodos();
          return;
        }
        await loadTodos();
        return;
      }

      if (currentTodo.status == status) {
        _selectedIds.remove(id);
        state = AsyncValue.data(List<TodoItem>.from(currentValue));
        return;
      }

      final updated = await _repository.setStatus(id, status);
      if (updated == null) {
        await loadTodos();
        return;
      }

      _selectedIds.remove(id);

      final updatedTodos = currentValue
          .map((todo) => todo.id == id ? updated : todo)
          .toList(growable: false);

      state = AsyncValue.data(List<TodoItem>.from(updatedTodos));
    } finally {
      _statusUpdatingIds.remove(id);
    }
  }

  /// Update todo text
  Future<void> updateText(String id, String newText) async {
    final dbHelper = DatabaseHelper.instance;
    final todo = await dbHelper.getTodoById(id);
    if (todo != null) {
      final updated = todo.copyWith(text: newText);
      await dbHelper.updateTodo(updated);
      await loadTodos();
    }
  }

  /// Delete a todo
  Future<void> deleteTodo(String id) async {
    await _repository.deleteTodo(id);
    await loadTodos();
  }

  /// Delete multiple todos
  Future<void> deleteTodos(List<String> ids) async {
    for (final id in ids) {
      await _repository.deleteTodo(id);
    }
    _selectedIds.clear();
    await loadTodos();
  }

  /// Mark multiple todos as completed
  Future<void> completeTodos(List<String> ids) async {
    for (final id in ids) {
      if (_statusUpdatingIds.contains(id)) {
        continue;
      }
      await setCompletionStatus(id, TodoStatus.completed);
    }
    _selectedIds.clear();
    await loadTodos();
  }

  /// Delete all completed todos
  Future<void> deleteAllCompleted() async {
    final todos = state.value ?? [];
    final completedIds = todos
        .where((todo) => todo.status == TodoStatus.completed)
        .map((todo) => todo.id)
        .toList();

    for (final id in completedIds) {
      await _repository.deleteTodo(id);
    }
    await loadTodos();
  }

  /// Reorder todos
  Future<void> reorderTodos(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final currentValue = state.value ?? [];
    final items = List<TodoItem>.from(currentValue);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    // Update order indices
    final orderMap = <String, int>{};
    for (int i = 0; i < items.length; i++) {
      orderMap[items[i].id] = i;
    }

    final dbHelper = ref.read(databaseHelperProvider);
    await dbHelper.updateOrderIndices(orderMap);

    state = AsyncValue.data(items);
  }

  /// Reorder todos within a specific status section.
  Future<void> reorderTodosInSection({
    required bool isPendingSection,
    required int oldIndex,
    required int newIndex,
  }) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final currentValue =
        state.value ?? await _repository.getAllTodos(sortByOrder: true);
    final pendingTodos = currentValue
        .where((todo) => todo.status == TodoStatus.pending)
        .toList();
    final completedTodos = currentValue
        .where((todo) => todo.status == TodoStatus.completed)
        .toList();

    final targetSection = isPendingSection ? pendingTodos : completedTodos;
    if (oldIndex < 0 ||
        oldIndex >= targetSection.length ||
        newIndex < 0 ||
        newIndex >= targetSection.length) {
      return;
    }

    final reorderedSection = List<TodoItem>.from(targetSection);
    final item = reorderedSection.removeAt(oldIndex);
    reorderedSection.insert(newIndex, item);

    final combined = isPendingSection
        ? <TodoItem>[...reorderedSection, ...completedTodos]
        : <TodoItem>[...pendingTodos, ...reorderedSection];

    final orderMap = <String, int>{};
    final updatedItems = <TodoItem>[];
    for (var i = 0; i < combined.length; i++) {
      orderMap[combined[i].id] = i;
      updatedItems.add(combined[i].copyWith(orderIndex: i));
    }

    final dbHelper = ref.read(databaseHelperProvider);
    await dbHelper.updateOrderIndices(orderMap);

    state = AsyncValue.data(updatedItems);
  }
}

final todoListProvider =
    AsyncNotifierProvider<TodoListNotifier, List<TodoItem>>(() {
  return TodoListNotifier();
});
