import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database_helper.dart';
import '../models/todo_item.dart';
import '../services/recorder_service.dart';
import '../services/recognition_service.dart';
import '../services/audio_playback_service.dart';
import '../services/model_manager_service.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';
import '../services/todo_grouping_service.dart';
import '../data/todo_repository.dart';
import '../data/reminder_repository.dart';
import '../data/category_repository.dart';
import '../data/tag_repository.dart';
import '../models/todo_group.dart';
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

/// Provider for tag list
final tagListProvider = FutureProvider<List<Tag>>((ref) {
  return ref.read(tagRepositoryProvider).getTags();
});

/// Provider for tags of a specific todo
final tagsForTodoProvider =
    FutureProvider.family<List<Tag>, String>((ref, todoId) {
  return ref.read(tagRepositoryProvider).getTagsForTodo(todoId);
});

/// Provider for notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

/// Provider for reminder service
final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(
    reminderRepository: ref.read(reminderRepositoryProvider),
    todoRepository: ref.read(todoRepositoryProvider),
    notificationService: ref.read(notificationServiceProvider),
    settingsRepository: ref.read(settingsRepositoryProvider),
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
    recorder: ref.read(recorderServiceProvider),
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
        } catch (_) {
          // Ignore cleanup failures; the file is now orphaned and can be cleaned later.
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
      print('Recording workflow failed: $e');
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
    final recognition = ref.read(recognitionServiceProvider);
    final repository = ref.read(todoRepositoryProvider);
    final settings = ref.read(settingsProvider);

    try {
      // Ensure model is ready. If not, attempt reload once.
      final ready = await recognition.isModelReady();
      if (!ready) {
        await recognition.reloadModel();
      }

      // Try recognition with a few retries and exponential backoff using
      // the detailed recognizer which may return ASR-provided confidence.
      Map<String, dynamic>? detailed;
      const maxAttempts = 3;
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final result = await recognition
              .recognizeDetailed(wavPath)
              .timeout(const Duration(seconds: 30), onTimeout: () {
            throw TimeoutException('Recognition timed out');
          });

          if (result != null && (result['text'] ?? '').toString().isNotEmpty) {
            detailed = Map<String, dynamic>.from(result);
            break;
          } else {
            throw Exception('Empty recognition result');
          }
        } catch (e) {
          if (attempt < maxAttempts) {
            await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
            continue;
          } else {
            rethrow;
          }
        }
      }

      if (detailed == null || (detailed['text'] ?? '').toString().isEmpty) {
        throw Exception('error.speechRecognitionFailed');
      }

      // Normalize whitespace first and operate on a non-null local copy
      var processed =
          detailed['text'].toString().replaceAll(RegExp(r'\s+'), ' ').trim();

      // Remove spaces between Chinese characters (keep spaces for Latin)
      final cjkPair = RegExp(r'([\u4E00-\u9FFF])\s+([\u4E00-\u9FFF])');
      while (cjkPair.hasMatch(processed)) {
        processed =
            processed.replaceAllMapped(cjkPair, (m) => '${m[1]}${m[2]}');
      }

      // Basic sentence end heuristic: ensure punctuation at end of text
      final endsPunct = RegExp(r'[.!?。？，、]$');
      if (!endsPunct.hasMatch(processed)) {
        // If contains CJK characters use Chinese period
        if (RegExp(r'[\u4E00-\u9FFF]').hasMatch(processed)) {
          processed = '$processed。';
        } else {
          processed = '$processed.';
        }
      }

      if (settings.autoRemoveTrailingPeriod) {
        processed = processed.replaceFirst(RegExp(r'[。.]$'), '');
      }

      // Compute a heuristic confidence score based on text and simple audio cues
      double computeTextHeuristic(String t) {
        final len = t.length;
        if (len < 4) return 0.3;
        final base = ((len.clamp(4, 200) - 4) / 196).clamp(0.0, 1.0);
        var conf = 0.5 + base * 0.45; // 0.5..0.95
        final cjkCount = RegExp(r'[\u4E00-\u9FFF]').allMatches(t).length;
        if (cjkCount / len > 0.5) conf = (conf + 0.05).clamp(0.0, 1.0);
        return conf;
      }

      Future<double> computeAudioQuality(String path) async {
        try {
          final file = File(path);
          if (!await file.exists()) return 0.5;
          final bytes = await file.readAsBytes();
          if (bytes.length <= 44) return 0.5;
          final pcm = bytes.sublist(44);
          final sampleCount = pcm.length ~/ 2;
          if (sampleCount == 0) return 0.5;

          int silent = 0;
          const int threshold = 500; // low amplitude threshold
          for (var i = 0; i < pcm.length; i += 2) {
            final lo = pcm[i];
            final hi = pcm[i + 1];
            int sample = (hi << 8) | (lo & 0xFF);
            if (sample & 0x8000 != 0) sample = sample - 0x10000;
            if (sample.abs() < threshold) silent++;
          }

          final silenceRatio = silent / sampleCount;
          final durationMs = (pcm.length / (16000 * 2) * 1000).toDouble();
          final durationFactor =
              (durationMs / 30000).clamp(0.0, 1.0); // favour up to 30s
          final quality = (1.0 - silenceRatio) * 0.7 + durationFactor * 0.3;
          return quality.clamp(0.0, 1.0);
        } catch (_) {
          return 0.5;
        }
      }

      final textHeuristic = computeTextHeuristic(processed);
      final audioQuality = await computeAudioQuality(wavPath);

      // Combine ASR confidence (if present) with heuristics
      final asrConfRaw = detailed['confidence'];
      double finalConfidence;
      if (asrConfRaw is num) {
        final asrConf = asrConfRaw.toDouble().clamp(0.0, 1.0);
        finalConfidence =
            (asrConf * 0.7) + (textHeuristic * 0.2) + (audioQuality * 0.1);
      } else {
        finalConfidence = (textHeuristic * 0.6) + (audioQuality * 0.4);
      }
      finalConfidence = finalConfidence.clamp(0.0, 1.0);

      if (todoId != null) {
        await repository.completeRecognition(
          id: todoId,
          text: processed,
          modelVersion: 'vosk-model-small-cn-0.22',
          confidence: finalConfidence,
        );
      }
    } catch (e) {
      if (todoId != null) {
        await repository.markFailed(
          id: todoId,
          errorMessage: e.toString(),
        );
      }
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
    state = AsyncValue.data(await _repository.getTodos(_queryOptions));
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
    if (currentValue == null) {
      await loadTodos();
      return refreshed;
    }

    final updatedTodos = currentValue
        .map((todo) => todo.id == id ? refreshed : todo)
        .toList(growable: false);
    state = AsyncValue.data(updatedTodos);
    // Schedule or clear system notification for this todo via ReminderService
    try {
      await ref
          .read(reminderServiceProvider)
          .scheduleReminderForTodo(refreshed);
    } catch (e) {
      // Do not fail the UI update if scheduling fails; log for debugging
      // ignore: avoid_print
      print('Failed to schedule reminder for todo $id: $e');
    }
    return refreshed;
  }

  /// Update priority for a todo and refresh list state
  Future<void> updatePriority(String id, TodoPriority priority) async {
    await _repository.updatePriority(id, priority);
    await loadTodos();
  }

  /// Set tags for a todo and refresh
  Future<void> setTags(String todoId, List<String> tagIds) async {
    await _repository.setTags(todoId, tagIds);
    ref.invalidate(tagsForTodoProvider(todoId));
  }

  /// Update due time and refresh list state
  Future<TodoItem?> updateDueTime(String id, DateTime? dueAt) async {
    final result = await _repository.updateDueAt(id, dueAt);
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

  Future<TodoItem?> updateCategory(String id, String? categoryId) async {
    await _repository.updateCategory(id, categoryId);
    final refreshed = await _repository.getTodoById(id);
    if (refreshed == null) {
      await loadTodos();
      return null;
    }

    final currentValue = state.value;
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

/// Global provider holding persisted group order map so UI can react to changes.
class GroupOrderMapNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => {};

  void setMap(Map<String, int> map) => state = map;
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
