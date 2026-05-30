import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' as foundation;
import '../data/database_helper.dart';
import '../models/todo_item.dart';
import '../services/recorder_service.dart';
import '../services/recognition_service.dart';
import '../services/audio_playback_service.dart';
import '../services/model_manager_service.dart';
import '../services/awesome_notification_service.dart';
import '../services/reminder_service.dart';
import '../services/calendar_sync_service.dart';
import '../services/todo_grouping_service.dart';
import '../services/settings_service.dart';
import '../data/todo_repository.dart';
import '../data/reminder_repository.dart';
import '../data/category_repository.dart';
import '../data/tag_repository.dart';
import '../models/todo_group.dart';
import '../models/settings_state.dart';
import '../domain/usecases/create_todo_from_recording_usecase.dart';
import '../models/category.dart';
import '../models/tag.dart';
import '../providers/settings_provider.dart';
import '../models/todo_query_options.dart';
import '../models/todo_priority.dart';

/// Provider for database helper
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

/// Provider for todo repository
final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  return TodoRepository();
});

/// Provider for reminder repository
final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository();
});

/// Provider for category repository
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository();
});

/// Provider for tag repository
final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepository();
});

/// Provider for todo grouping service
final todoGroupingServiceProvider = Provider<TodoGroupingService>((ref) {
  return TodoGroupingService();
});

/// Provider for settings service
final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

/// Provider for tag list
final tagListProvider = FutureProvider<List<Tag>>((ref) {
  return ref.read(tagRepositoryProvider).getTags();
});

/// Provider for tags of a specific todo
final tagsForTodoProvider =
    FutureProvider.family<List<Tag>, String>((ref, todoId) {
  return ref.read(tagRepositoryProvider).getTagsForTodo(todoId);
});

/// Batch cache of todo_id -> tags mapping to reduce N database queries in list view
final tagsByTodoIdProvider = Provider<Map<String, List<Tag>>>((ref) {
  // Provider is a simple cache map; it should be cleared/refreshed by notifiers when tags change
  return <String, List<Tag>>{};
});

final todoTagsCacheNotifierProvider =
    NotifierProvider<TodoTagsCacheNotifier, Map<String, List<Tag>>>(() {
  return TodoTagsCacheNotifier();
});

class TodoTagsCacheNotifier extends Notifier<Map<String, List<Tag>>> {
  late final TagRepository _tagRepo;

  @override
  Map<String, List<Tag>> build() {
    _tagRepo = ref.read(tagRepositoryProvider);
    return <String, List<Tag>>{};
  }

  Future<void> refreshForTodos(List<String> todoIds) async {
    if (todoIds.isEmpty) {
      state = <String, List<Tag>>{};
      return;
    }
    final mapping = await _tagRepo.getTagsForTodos(todoIds);
    state = mapping;
  }

  void invalidate() {
    state = <String, List<Tag>>{};
  }

  void invalidateFor(String todoId) {
    if (state.containsKey(todoId)) {
      final next = Map<String, List<Tag>>.from(state);
      next.remove(todoId);
      state = next;
    }
  }

  List<Tag>? get(String todoId) => state[todoId];
}

/// Provider for awesome notification service
final notificationServiceProvider = Provider<AwesomeNotificationService>((ref) {
  return AwesomeNotificationService();
});

/// Provider for calendar sync service
final calendarSyncServiceProvider = Provider<CalendarSyncService>((ref) {
  return CalendarSyncService();
});

/// Provider for reminder service
final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(
    reminderRepository: ref.read(reminderRepositoryProvider),
    todoRepository: ref.read(todoRepositoryProvider),
    notificationService: ref.read(notificationServiceProvider),
    settingsRepository: ref.read(settingsRepositoryProvider),
    calendarSyncService: ref.read(calendarSyncServiceProvider),
  );
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
    recognition: ref.read(recognitionServiceProvider),
    repository: ref.read(todoRepositoryProvider),
    settingsRepository: ref.read(settingsRepositoryProvider),
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
  String? _replacementTodoId;
  String? _replacementOldAudioPath;

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

  /// Stop recording, create a placeholder todo, and continue recognition in the background.
  Future<void> stop() async {
    try {
      final recorder = ref.read(recorderServiceProvider);
      final repository = ref.read(todoRepositoryProvider);

      final wavPath = await recorder.stopRecording();
      if (wavPath == null || wavPath.isEmpty) {
        throw Exception('error.recordingFileGenerationFailed');
      }

      final replacingTodoId = _replacementTodoId;
      final replacingOldAudioPath = _replacementOldAudioPath;
      _replacementTodoId = null;
      _replacementOldAudioPath = null;

      String? todoId;

      if (replacingTodoId != null) {
        await repository.updateToRecognizing(
          replacingTodoId,
          audioPath: wavPath,
        );
        todoId = replacingTodoId;
      } else {
        final settings = ref.read(settingsProvider);
        final todo = await repository.insertRecognizing(
          audioPath: wavPath,
          priority: settings.defaultTodoPriority,
        );
        todoId = todo.id;
      }

      if (replacingOldAudioPath != null &&
          replacingOldAudioPath.isNotEmpty &&
          replacingOldAudioPath != wavPath) {
        try {
          await File(replacingOldAudioPath).delete();
        } catch (e) {
          foundation.debugPrint('Failed to delete replaced audio file: $e');
        }
      }

      // Return to idle immediately so the next recording can start right away.
      state = RecordingState.idle;

      // Show the placeholder item immediately.
      await ref.read(todoListProvider.notifier).loadTodos();

      unawaited(
        _recognizeRecordingInBackground(
          todoId,
          wavPath,
        ),
      );
    } catch (e) {
      foundation.debugPrint('Recording workflow failed: $e');
      state = RecordingState.failed;

      // Reset to idle after showing error
      await Future.delayed(const Duration(seconds: 2));
      state = RecordingState.idle;
      rethrow;
    }
  }

  Future<void> _recognizeRecordingInBackground(
    String? todoId,
    String wavPath,
  ) async {
    final useCase = ref.read(createTodoUseCaseProvider);

    try {
      // Ensure model is ready. If not, attempt reload once.
      final recognition = ref.read(recognitionServiceProvider);
      final ready = await recognition.isModelReady();
      if (!ready) {
        await recognition.reloadModel();
      }

      await useCase.execute(wavPath: wavPath, todoId: todoId);
    } catch (e) {
      foundation.debugPrint('Background recognition failed: $e');
    } finally {
      await ref.read(todoListProvider.notifier).loadTodos();
    }
  }

  Future<void> startReRecord(TodoItem todo) async {
    if (state != RecordingState.idle) {
      return;
    }

    _replacementTodoId = todo.id;
    _replacementOldAudioPath = todo.audioPath;
    await start();
  }

  void reset() => state = RecordingState.idle;
}

final recordingStateProvider =
    NotifierProvider<RecordingNotifier, RecordingState>(() {
  return RecordingNotifier();
});

/// State for all todo items
class TodoListNotifier extends AsyncNotifier<List<TodoItem>> {
  late final TodoRepository _repository;
  Set<String> _selectedIds = {}; // Track selected todo IDs
  final Set<String> _statusUpdatingIds =
      {}; // Track items currently updating status
  bool _selectionMode = false;
  // New: current query options for list
  TodoQueryOptions _queryOptions = const TodoQueryOptions();

  @override
  Future<List<TodoItem>> build() async {
    _repository = ref.read(todoRepositoryProvider);
    // Initialize query options from settings
    final settings = ref.read(settingsProvider);
    _queryOptions = TodoQueryOptions(
      sortField: settings.todoSortField,
      direction: settings.todoSortDirection,
      onlyPending: false,
      categoryId: null,
    );

    // Load todos on initialization
    return _repository.getTodos(_queryOptions);
  }

  /// Get currently selected todo IDs
  Set<String> get selectedIds => _selectedIds;

  bool get isSelectionMode => _selectionMode;

  void enableSelectionMode() {
    _selectionMode = true;
    state = AsyncValue.data(List<TodoItem>.from(state.value ?? const []));
  }

  void disableSelectionMode() {
    _selectionMode = false;
    _selectedIds.clear();
    state = AsyncValue.data(List<TodoItem>.from(state.value ?? const []));
  }

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
    final todos = await _repository.getTodos(
      _queryOptions,
      sortInDatabase: false,
    );
    final sortedTodos = todos.length > 1
        ? await ref.read(todoGroupingServiceProvider).sortTodosInBackground(
              todos,
              _queryOptions.sortField,
              _queryOptions.direction,
            )
        : todos;
    state = AsyncValue.data(sortedTodos);
    // Refresh batch tags cache for list view
    unawaited(ref.read(todoTagsCacheNotifierProvider.notifier).refreshForTodos(
          sortedTodos.map((t) => t.id).toList(),
        ));
  }

  /// Set query options and refresh list
  Future<void> setQueryOptions(TodoQueryOptions options) async {
    _queryOptions = options;
    await loadTodos();
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

        if (status == TodoStatus.completed) {
          await ref.read(reminderServiceProvider).clearReminder(id);
        } else {
          await ref
              .read(reminderServiceProvider)
              .scheduleReminderForTodo(updated);
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

      if (status == TodoStatus.completed) {
        await ref.read(reminderServiceProvider).clearReminder(id);
      } else {
        await ref
            .read(reminderServiceProvider)
            .scheduleReminderForTodo(updated);
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
    await ref.read(todoRepositoryProvider).updateText(id, newText);

    // Try to update locally if we have current state
    final currentValue = state.value;
    if (currentValue != null) {
      final updated = await _repository.getTodoById(id);
      if (updated != null) {
        final updatedTodos = currentValue
            .map((todo) => todo.id == id ? updated : todo)
            .toList(growable: false);
        state = AsyncValue.data(updatedTodos);
        return;
      }
    }

    // Fallback to full reload if local update fails
    await loadTodos();
  }

  /// Update reminder time and refresh list state
  Future<TodoItem?> updateReminderTime(String id, DateTime? remindAt) async {
    final result = await _repository.updateRemindAt(id, remindAt);
    if (result == null) {
      await loadTodos();
      return null;
    }

    final refreshed = await _repository.getTodoById(id);
    if (refreshed == null) {
      await loadTodos();
      return result;
    }

    final currentValue = state.value;
    if (currentValue != null) {
      final updatedTodos = currentValue
          .map((todo) => todo.id == id ? refreshed : todo)
          .toList(growable: false);
      state = AsyncValue.data(updatedTodos);
    } else {
      await loadTodos();
    }

    // Schedule or clear system notification for this todo via ReminderService.
    try {
      await ref
          .read(reminderServiceProvider)
          .scheduleReminderForTodo(refreshed);
    } catch (e) {
      // Do not fail the UI update if scheduling fails; log for debugging
      // ignore: avoid_print
      foundation.debugPrint('Failed to schedule reminder for todo $id: $e');
    }
    return refreshed;
  }

  /// Update priority for a todo and refresh list state
  Future<void> updatePriority(String id, TodoPriority priority) async {
    await _repository.updatePriority(id, priority);

    // Try to update locally if we have current state
    final currentValue = state.value;
    if (currentValue != null) {
      final updated = await _repository.getTodoById(id);
      if (updated != null) {
        final updatedTodos = currentValue
            .map((todo) => todo.id == id ? updated : todo)
            .toList(growable: false);
        state = AsyncValue.data(updatedTodos);
        return;
      }
    }

    // Fallback to full reload if local update fails
    await loadTodos();
  }

  /// Set tags for a todo and refresh
  Future<void> setTags(String todoId, List<String> tagIds) async {
    await _repository.setTags(todoId, tagIds);
    ref.invalidate(tagsForTodoProvider(todoId));
    ref.read(todoTagsCacheNotifierProvider.notifier).invalidateFor(todoId);
  }

  /// Update due time and refresh list state
  Future<TodoItem?> updateDueTime(String id, DateTime? dueAt) async {
    final result = await _repository.updateDueAt(id, dueAt);
    if (result == null) {
      await loadTodos();
      return null;
    }

    // Try to update locally if we have current state
    final currentValue = state.value;
    if (currentValue != null) {
      final updated = await _repository.getTodoById(id);
      if (updated != null) {
        final updatedTodos = currentValue
            .map((todo) => todo.id == id ? updated : todo)
            .toList(growable: false);
        state = AsyncValue.data(updatedTodos);
        return updated;
      }
    }

    // Fallback to full reload if local update fails
    final refreshed = await _repository.getTodoById(id);
    if (refreshed == null) {
      await loadTodos();
      return result;
    }

    if (currentValue == null) {
      await loadTodos();
      return refreshed;
    }

    final updatedTodos = currentValue
        .map((todo) => todo.id == id ? refreshed : todo)
        .toList(growable: false);
    state = AsyncValue.data(updatedTodos);
    try {
      await ref
          .read(reminderServiceProvider)
          .scheduleReminderForTodo(refreshed);
    } catch (e) {
      foundation.debugPrint('Failed to sync due time for todo $id: $e');
    }
    return refreshed;
  }

  Future<TodoItem?> updateCategory(String id, String? categoryId) async {
    await _repository.updateCategory(id, categoryId);

    // Try to update locally if we have current state
    final currentValue = state.value;
    if (currentValue != null) {
      final updated = await _repository.getTodoById(id);
      if (updated != null) {
        final updatedTodos = currentValue
            .map((todo) => todo.id == id ? updated : todo)
            .toList(growable: false);
        state = AsyncValue.data(updatedTodos);
        return updated;
      }
    }

    // Fallback to full reload if local update fails
    final refreshed = await _repository.getTodoById(id);
    if (refreshed == null) {
      await loadTodos();
      return null;
    }

    if (currentValue == null) {
      await loadTodos();
      return refreshed;
    }

    final updatedTodos = currentValue
        .map((todo) => todo.id == id ? refreshed : todo)
        .toList(growable: false);
    state = AsyncValue.data(updatedTodos);
    return refreshed;
  }

  /// Move a todo to a category and insert it at a specific index within that category.
  Future<void> moveTodoToCategoryAtIndex(
    String id,
    String? targetCategoryId,
    int targetIndex, {
    String? sourceGroupKey,
    int? sourceIndex,
  }) async {
    final currentValue =
        state.value ?? await _repository.getAllTodos(sortByOrder: true);
    final movingTodo = currentValue.firstWhere(
      (todo) => todo.id == id,
      orElse: () => throw StateError('Todo not found: $id'),
    );

    final sourceCategoryId = movingTodo.categoryId;
    final inferredTargetGroupKey =
        targetCategoryId ?? TodoGroupingService.uncategorizedGroupKey;
    final sameGroupByCategory = sourceCategoryId == targetCategoryId;
    final sameGroup = sourceGroupKey == null
        ? sameGroupByCategory
        : sourceGroupKey == inferredTargetGroupKey;
    final sourceGroup = currentValue
        .where((todo) => todo.categoryId == sourceCategoryId && todo.id != id)
        .toList();
    final targetGroup = sameGroupByCategory
        ? sourceGroup
        : currentValue
            .where(
                (todo) => todo.categoryId == targetCategoryId && todo.id != id)
            .toList();

    var adjustedTargetIndex = targetIndex;
    if (sameGroup && sourceIndex != null && sourceIndex < adjustedTargetIndex) {
      adjustedTargetIndex -= 1;
    }

    final clampedIndex = adjustedTargetIndex.clamp(0, targetGroup.length);
    final movedTodo = movingTodo.copyWith(categoryId: targetCategoryId);

    targetGroup.insert(clampedIndex, movedTodo);

    final updatedById = <String, TodoItem>{};
    final orderMap = <String, int>{};
    for (var i = 0; i < targetGroup.length; i++) {
      final updatedTodo = targetGroup[i].copyWith(orderIndex: i);
      updatedById[updatedTodo.id] = updatedTodo;
      orderMap[updatedTodo.id] = i;
    }

    if (!sameGroupByCategory) {
      for (var i = 0; i < sourceGroup.length; i++) {
        final updatedTodo = sourceGroup[i].copyWith(orderIndex: i);
        updatedById[updatedTodo.id] = updatedTodo;
        orderMap[updatedTodo.id] = i;
      }
    }

    final updatedTodos = currentValue
        .map((todo) => updatedById[todo.id] ?? todo)
        .toList(growable: false);
    state = AsyncValue.data(updatedTodos);

    if (!sameGroupByCategory) {
      await _repository.updateCategory(id, targetCategoryId);
    }

    final dbHelper = ref.read(databaseHelperProvider);
    await dbHelper.updateOrderIndices(orderMap);
  }

  /// Delete a todo
  Future<void> deleteTodo(String id) async {
    await ref.read(reminderServiceProvider).clearReminder(id);
    await _repository.deleteTodo(id);
    // Refresh trash list so deleted item appears immediately in Trash UI
    await ref.read(trashTodosProvider.notifier).loadTrash();

    // Try to remove locally if we have current state
    final currentValue = state.value;
    if (currentValue != null) {
      final updatedTodos =
          currentValue.where((todo) => todo.id != id).toList(growable: false);
      state = AsyncValue.data(updatedTodos);
      return;
    }

    // Fallback to full reload if local update fails
    await loadTodos();
  }

  /// Delete multiple todos
  Future<void> deleteTodos(List<String> ids) async {
    for (final id in ids) {
      await ref.read(reminderServiceProvider).clearReminder(id);
      await _repository.deleteTodo(id);
    }
    _selectedIds.clear();
    // Ensure trash list is up-to-date after batch delete
    await ref.read(trashTodosProvider.notifier).loadTrash();

    // Try to remove locally if we have current state
    final currentValue = state.value;
    if (currentValue != null) {
      final updatedTodos = currentValue
          .where((todo) => !ids.contains(todo.id))
          .toList(growable: false);
      state = AsyncValue.data(updatedTodos);
      return;
    }

    // Fallback to full reload if local update fails
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
      await ref.read(reminderServiceProvider).clearReminder(id);
      await _repository.deleteTodo(id);
    }
    // Refresh trash after removing completed items
    await ref.read(trashTodosProvider.notifier).loadTrash();
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

  /// Reorder todos within a single category group.
  Future<void> reorderTodosInGroup(
    List<TodoItem> groupItems,
    int oldIndex,
    int newIndex,
  ) async {
    if (groupItems.isEmpty) {
      return;
    }

    if (oldIndex < 0 ||
        oldIndex >= groupItems.length ||
        newIndex < 0 ||
        newIndex >= groupItems.length) {
      return;
    }

    final reorderedGroup = List<TodoItem>.from(groupItems);
    final movedItem = reorderedGroup.removeAt(oldIndex);
    reorderedGroup.insert(newIndex, movedItem);

    final currentValue =
        state.value ?? await _repository.getAllTodos(sortByOrder: true);
    final updatedById = <String, TodoItem>{};
    final orderMap = <String, int>{};
    for (var i = 0; i < reorderedGroup.length; i++) {
      final updatedTodo = reorderedGroup[i].copyWith(orderIndex: i);
      updatedById[updatedTodo.id] = updatedTodo;
      orderMap[updatedTodo.id] = i;
    }

    final updatedTodos = currentValue
        .map((todo) => updatedById[todo.id] ?? todo)
        .toList(growable: false);
    state = AsyncValue.data(updatedTodos);

    final dbHelper = ref.read(databaseHelperProvider);
    await dbHelper.updateOrderIndices(orderMap);
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

/// State for todos currently in the trash.
class TrashTodosNotifier extends AsyncNotifier<List<TodoItem>> {
  late final TodoRepository _repository;

  @override
  Future<List<TodoItem>> build() async {
    _repository = ref.read(todoRepositoryProvider);
    return _repository.getDeletedTodos();
  }

  Future<void> loadTrash() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repository.getDeletedTodos());
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> restoreTodo(String id) async {
    final restored = await _repository.restoreTodo(id);
    if (restored != null) {
      await ref.read(reminderServiceProvider).scheduleReminderForTodo(restored);
    }
    await loadTrash();
    await ref.read(todoListProvider.notifier).loadTodos();
  }

  Future<void> purgeTodo(String id) async {
    await ref.read(reminderServiceProvider).clearReminder(id);
    await _repository.purgeTodoPermanently(id);
    await loadTrash();
    await ref.read(todoListProvider.notifier).loadTodos();
  }

  Future<void> purgeAllTrash() async {
    final items = state.value ?? await _repository.getDeletedTodos();
    for (final item in items) {
      await ref.read(reminderServiceProvider).clearReminder(item.id);
      await _repository.purgeTodoPermanently(item.id);
    }
    await loadTrash();
    await ref.read(todoListProvider.notifier).loadTodos();
  }

  Future<void> purgeExpiredTrash(TrashAutoPurgeInterval interval) async {
    final expiredItems = await _repository.getDeletedTodos();
    final cutoff = DateTime.now().subtract(
      switch (interval) {
        TrashAutoPurgeInterval.oneDay => const Duration(days: 1),
        TrashAutoPurgeInterval.threeDays => const Duration(days: 3),
        TrashAutoPurgeInterval.sevenDays => const Duration(days: 7),
        TrashAutoPurgeInterval.thirtyDays => const Duration(days: 30),
        TrashAutoPurgeInterval.never => Duration.zero,
      },
    );

    for (final item in expiredItems) {
      final deletedAt = item.deletedAt;
      if (deletedAt != null && deletedAt.isBefore(cutoff)) {
        await ref.read(reminderServiceProvider).clearReminder(item.id);
      }
    }

    await _repository.purgeExpiredDeletedTodos(interval);
    await loadTrash();
    await ref.read(todoListProvider.notifier).loadTodos();
  }
}

final trashTodosProvider =
    AsyncNotifierProvider<TrashTodosNotifier, List<TodoItem>>(() {
  return TrashTodosNotifier();
});

/// Global provider holding persisted group order map so UI can react to changes.
class GroupOrderMapNotifier extends Notifier<Map<String, int>> {
  late final TodoGroupingService _groupingService;

  @override
  Map<String, int> build() {
    _groupingService = ref.read(todoGroupingServiceProvider);
    unawaited(_loadPersistedMap());
    return {};
  }

  Future<void> _loadPersistedMap() async {
    final orderMap = await _groupingService.loadGroupOrderMap();
    state = orderMap;
  }

  void setMap(Map<String, int> map) {
    state = map;
  }

  Future<void> saveMap(Map<String, int> map) async {
    await _groupingService.saveGroupOrderMap(map);
  }
}

final groupOrderMapProvider =
    NotifierProvider<GroupOrderMapNotifier, Map<String, int>>(() {
  return GroupOrderMapNotifier();
});

/// Provider to expose a single TodoItem by id, derived from [todoListProvider].
final todoByIdProvider = Provider.family<TodoItem?, String>((ref, id) {
  final listAsync = ref.watch(todoListProvider);
  return listAsync.maybeWhen(
    data: (items) {
      for (final t in items) {
        if (t.id == id) return t;
      }
      return null;
    },
    orElse: () => null,
  );
});

/// Lightweight summary for toolbar/badges without exposing the full todo list.
final todoSummaryProvider =
    Provider<({int totalCount, int completedCount})>((ref) {
  final todosAsync = ref.watch(todoListProvider);
  return todosAsync.maybeWhen(
    data: (todos) {
      var completedCount = 0;
      for (final todo in todos) {
        if (todo.status == TodoStatus.completed) {
          completedCount += 1;
        }
      }
      return (totalCount: todos.length, completedCount: completedCount);
    },
    orElse: () => (totalCount: 0, completedCount: 0),
  );
});

/// Provider that returns the ordered list of group keys computed from current todos and settings.
final todoGroupKeysProvider = Provider<List<String>>((ref) {
  final todosAsync = ref.watch(todoListProvider);
  final categories =
      ref.watch(categoryListProvider).asData?.value ?? const <Category>[];
  final settings = ref.watch(settingsProvider);
  final groupingService = ref.read(todoGroupingServiceProvider);
  // Read persisted group order map from global provider
  final groupOrderMap = ref.watch(groupOrderMapProvider);

  return todosAsync.maybeWhen(
    data: (todos) {
      final groups = groupingService.buildGroups(
        todos: todos,
        categories: categories,
        sortField: settings.todoSortField,
        direction: settings.todoSortDirection,
        completedLabel: 'completed',
        uncategorizedLabel: 'uncategorized',
        aggregateCompletedTodos: settings.aggregateCompletedTodos,
        groupOrderMap: groupOrderMap,
      );
      return groups.map((g) => g.groupKey).toList(growable: false);
    },
    orElse: () => const <String>[],
  );
});

/// Provider family to expose a single `TodoGroup` by groupKey derived from current todos.
final todoGroupProvider = Provider.family<TodoGroup?, String>((ref, groupKey) {
  final todosAsync = ref.watch(todoListProvider);
  final categories =
      ref.watch(categoryListProvider).asData?.value ?? const <Category>[];
  final settings = ref.watch(settingsProvider);
  final groupingService = ref.read(todoGroupingServiceProvider);

  return todosAsync.maybeWhen(
    data: (todos) {
      final groupOrderMap = ref.watch(groupOrderMapProvider);
      final groups = groupingService.buildGroups(
        todos: todos,
        categories: categories,
        sortField: settings.todoSortField,
        direction: settings.todoSortDirection,
        completedLabel: 'completed',
        uncategorizedLabel: 'uncategorized',
        aggregateCompletedTodos: settings.aggregateCompletedTodos,
        groupOrderMap: groupOrderMap,
      );
      for (final g in groups) {
        if (g.groupKey == groupKey) return g;
      }
      return null;
    },
    orElse: () => null,
  );
});

final categoryListProvider = FutureProvider<List<Category>>((ref) async {
  final repository = ref.read(categoryRepositoryProvider);
  return repository.getCategories();
});
