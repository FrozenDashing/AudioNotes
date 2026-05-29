import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_i18n.dart';
import '../models/tag.dart';
import '../models/todo_item.dart';
import '../models/todo_priority.dart';
import '../providers/app_providers.dart';
import '../screens/category_picker_screen.dart';
import '../screens/tag_picker_screen.dart';
import 'completed_text.dart';

/// Individual todo item card widget
class TodoItemCard extends ConsumerWidget {
  final String todoId;
  final bool showCategoryChip;
  final bool compact;
  final bool subdued;

  const TodoItemCard({
    super.key,
    required this.todoId,
    this.showCategoryChip = true,
    this.compact = false,
    this.subdued = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(todoListProvider.notifier);
    final todo = ref.watch(todoByIdProvider(todoId));
    if (todo == null) {
      return const SizedBox.shrink();
    }

    final isSelected = notifier.isSelected(todo.id);
    final isSelectionMode = notifier.isSelectionMode;
    final isCompleted = todo.status == TodoStatus.completed;
    final isRecognizing = todo.taskState == TodoTaskState.recognizing;
    final priorityLabel = _resolvePriorityLabel(context, todo);
    final outerPadding = compact
        ? const EdgeInsets.symmetric(vertical: 0, horizontal: 0)
        : const EdgeInsets.symmetric(vertical: 4, horizontal: 8);
    final cardPadding = compact
        ? const EdgeInsets.fromLTRB(10, 10, 10, 10)
        : const EdgeInsets.fromLTRB(12, 10, 12, 10);
    final card = Padding(
      padding: outerPadding,
      child: _buildCard(
        context,
        ref,
        theme,
        notifier,
        todo,
        isSelected,
        isSelectionMode,
        isCompleted,
        isRecognizing,
        priorityLabel,
        cardPadding,
      ),
    );

    final visualCard = subdued
        ? Opacity(
            opacity: 0.72,
            child: card,
          )
        : card;

    return visualCard;
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    TodoListNotifier notifier,
    TodoItem todo,
    bool isSelected,
    bool isSelectionMode,
    bool isCompleted,
    bool isRecognizing,
    String? priorityLabel,
    EdgeInsets cardPadding,
  ) {
    final tagsAsync = ref.watch(tagsForTodoProvider(todo.id));
    final tags = tagsAsync.maybeWhen(
      data: (items) => items,
      orElse: () => const <Tag>[],
    );

    if (isRecognizing) {
      return Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.5 : 0.8,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isSelectionMode
              ? () => notifier.toggleSelection(todo.id)
              : () => _showOptionsBottomSheet(context, ref, notifier, todo),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr('todo.recognizingTitle'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('todo.recognizingSubtitle'),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      color: isSelectionMode && isSelected
          ? theme.colorScheme.primary.withValues(alpha: 0.12)
          : (isCompleted
              ? theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.55 : 0.7,
                )
              : null),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isSelectionMode
            ? () => notifier.toggleSelection(todo.id)
            : () => _showOptionsBottomSheet(context, ref, notifier, todo),
        child: Padding(
          padding: cardPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCompleted)
                        CompletedText(
                          text: todo.text.isEmpty
                              ? context.tr('todo.recognizingInline')
                              : todo.text,
                          style: TextStyle(
                            fontSize: 20,
                            height: 1.1,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        Text(
                          todo.text.isEmpty
                              ? context.tr('todo.recognizingInline')
                              : todo.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      if (todo.taskState == TodoTaskState.recognizing)
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: LinearProgressIndicator(),
                        ),
                      if (todo.taskState == TodoTaskState.failed &&
                          todo.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            context.tr('todo.failedWithError', params: {
                              'error': _displayErrorMessage(
                                context,
                                todo.errorMessage,
                              )
                            }),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildTagRow(
                        context,
                        customTags: tags.take(3).toList(growable: false),
                        priorityLabel: priorityLabel,
                        remindAt: todo.remindAt,
                        dueAt: todo.dueAt,
                        onPriorityTap: isSelectionMode
                            ? null
                            : () =>
                                _showPriorityPicker(context, notifier, todo),
                        onReminderTap: isSelectionMode
                            ? null
                            : () => _pickReminderTime(context, notifier, todo),
                        onDueTap: isSelectionMode
                            ? null
                            : () => _pickDueTime(context, notifier, todo),
                        onTagsTap: isSelectionMode
                            ? null
                            : () =>
                                _openTagPicker(context, ref, notifier, todo),
                      ),
                    ],
                  ),
                  Checkbox(
                    visualDensity: VisualDensity.standard,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    value: todo.status == TodoStatus.completed,
                    onChanged: notifier.isStatusUpdating(todo.id)
                        ? null
                        : (value) => _setStatus(
                              notifier,
                              value == true
                                  ? TodoStatus.completed
                                  : TodoStatus.pending,
                              todo,
                            ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _resolvePriorityLabel(BuildContext context, TodoItem todo) {
    switch (todo.priority) {
      case TodoPriority.low:
        return context.tr('settings.todo.priority.low');
      case TodoPriority.normal:
        return context.tr('settings.todo.priority.normal');
      case TodoPriority.high:
        return context.tr('settings.todo.priority.high');
      case TodoPriority.urgent:
        return context.tr('settings.todo.priority.urgent');
    }
  }

  Widget _buildTagRow(
    BuildContext context, {
    required List<Tag> customTags,
    required String? priorityLabel,
    required DateTime? remindAt,
    required DateTime? dueAt,
    VoidCallback? onPriorityTap,
    VoidCallback? onReminderTap,
    VoidCallback? onDueTap,
    VoidCallback? onTagsTap,
  }) {
    final theme = Theme.of(context);
    final chips = <Widget>[];

    // Display order: custom tags -> reminder -> deadline -> priority
    for (final tag in customTags.take(3)) {
      chips.add(
        _buildTagPill(
          context,
          icon: Icons.label,
          label: tag.name,
          color: Color(tag.color ?? theme.colorScheme.primary.toARGB32()),
          onTap: onTagsTap,
        ),
      );
    }

    if (remindAt != null) {
      chips.add(
        _buildTagPill(
          context,
          icon: Icons.notifications_active_outlined,
          label: _formatRelativeDate(remindAt),
          color: theme.colorScheme.secondary,
          onTap: onReminderTap,
        ),
      );
    }

    if (dueAt != null) {
      chips.add(
        _buildTagPill(
          context,
          icon: Icons.event_outlined,
          label: _formatRelativeDate(dueAt),
          color: theme.colorScheme.tertiary,
          onTap: onDueTap,
        ),
      );
    }

    if (priorityLabel != null && priorityLabel.trim().isNotEmpty) {
      chips.add(
        _buildTagPill(
          context,
          icon: Icons.flag_outlined,
          label: priorityLabel,
          color: theme.colorScheme.outline,
          onTap: onPriorityTap,
        ),
      );
    }

    if (chips.isEmpty) {
      return const SizedBox(height: 22, width: double.infinity);
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: chips,
    );
  }

  Widget _buildTagPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return pill;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: pill,
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}';
  }

  String _formatRelativeDate(DateTime dateTime) {
    final now = DateTime.now();
    final sameDay = now.year == dateTime.year &&
        now.month == dateTime.month &&
        now.day == dateTime.day;
    if (sameDay) {
      return _formatTime(dateTime);
    }
    return '${_twoDigits(dateTime.month)}/${_twoDigits(dateTime.day)} ${_formatTime(dateTime)}';
  }

  String _twoDigits(int n) {
    return n.toString().padLeft(2, '0');
  }

  void _setStatus(TodoListNotifier notifier, TodoStatus status, TodoItem todo) {
    notifier.setCompletionStatus(todo.id, status);
  }

  void _showOptionsBottomSheet(
    BuildContext context,
    WidgetRef ref,
    TodoListNotifier notifier,
    TodoItem todo,
  ) {
    final isCompleted = todo.status == TodoStatus.completed;
    final hasAudio = todo.audioPath != null && todo.audioPath!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(context.tr('todo.editAction')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showEditDialog(context, notifier, todo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.category_outlined),
                title: Text(context.tr('todo.setCategory')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openCategoryPicker(context, ref, notifier, todo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(context.tr('todo.setReminderTime')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickReminderTime(context, notifier, todo);
                },
              ),
              if (todo.remindAt != null)
                ListTile(
                  leading: const Icon(Icons.notifications_off_outlined),
                  title: Text(context.tr('todo.clearReminderTime')),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _clearReminderTime(context, notifier, todo);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.event_outlined),
                title: Text(context.tr('todo.setDueTime')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickDueTime(context, notifier, todo);
                },
              ),
              if (todo.dueAt != null)
                ListTile(
                  leading: const Icon(Icons.event_busy_outlined),
                  title: Text(context.tr('todo.clearDueTime')),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _clearDueTime(context, notifier, todo);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.flag),
                title: Text(context.tr('todo.setPriority')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showPriorityPicker(context, notifier, todo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.label_outline),
                title: Text(context.tr('todo.editTags')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openTagPicker(context, ref, notifier, todo);
                },
              ),
              if (!isCompleted)
                ListTile(
                  leading: const Icon(Icons.mic),
                  title: Text(context.tr('todo.reRecordAction')),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _reRecord(context, ref, todo);
                  },
                ),
              if (hasAudio)
                ListTile(
                  leading: const Icon(Icons.play_arrow),
                  title: Text(context.tr('todo.playbackAction')),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _playback(context, ref, todo);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(context.tr('common.delete'),
                    style: const TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(context, notifier, todo);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPriorityPicker(
    BuildContext context,
    TodoListNotifier notifier,
    TodoItem todo,
  ) async {
    final picked = await showModalBottomSheet<TodoPriority>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: TodoPriority.values.map((p) {
              return ListTile(
                title: Text(_priorityToLabel(context, p)),
                onTap: () => Navigator.pop(ctx, p),
              );
            }).toList(),
          ),
        );
      },
    );

    if (picked != null && picked != todo.priority) {
      await notifier.updatePriority(todo.id, picked);
    }
  }

  String _priorityToLabel(BuildContext context, TodoPriority p) {
    switch (p) {
      case TodoPriority.low:
        return context.tr('settings.todo.priority.low');
      case TodoPriority.normal:
        return context.tr('settings.todo.priority.normal');
      case TodoPriority.high:
        return context.tr('settings.todo.priority.high');
      case TodoPriority.urgent:
        return context.tr('settings.todo.priority.urgent');
    }
  }

  Future<void> _openCategoryPicker(
    BuildContext context,
    WidgetRef ref,
    TodoListNotifier notifier,
    TodoItem todo,
  ) async {
    final navigator = Navigator.of(context);
    final selected = await navigator.push<String>(
      MaterialPageRoute(
        builder: (_) => CategoryPickerScreen(
          selectedCategoryId: todo.categoryId,
        ),
      ),
    );

    if (selected == null) return;
    await notifier.updateCategory(todo.id, selected);
  }

  Future<void> _pickReminderTime(
    BuildContext context,
    TodoListNotifier notifier,
    TodoItem todo,
  ) async {
    final picked = await _pickDateTime(
      context,
      initialDateTime:
          todo.remindAt ?? DateTime.now().add(const Duration(hours: 1)),
      title: context.tr('todo.pickReminderTimeTitle'),
    );

    if (picked == null || !context.mounted) return;
    await notifier.updateReminderTime(todo.id, picked);
  }

  Future<void> _pickDueTime(
    BuildContext context,
    TodoListNotifier notifier,
    TodoItem todo,
  ) async {
    final picked = await _pickDateTime(
      context,
      initialDateTime:
          todo.dueAt ?? DateTime.now().add(const Duration(days: 1)),
      title: context.tr('todo.pickDueTimeTitle'),
    );

    if (picked == null || !context.mounted) return;
    await notifier.updateDueTime(todo.id, picked);
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context, {
    required DateTime initialDateTime,
    required String title,
  }) async {
    final initialDate = DateTime(
      initialDateTime.year,
      initialDateTime.month,
      initialDateTime.day,
    );

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: title,
    );

    if (date == null || !context.mounted) {
      return null;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDateTime),
    );

    if (time == null) {
      return null;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _clearReminderTime(
    BuildContext context,
    TodoListNotifier notifier,
    TodoItem todo,
  ) async {
    await notifier.updateReminderTime(todo.id, null);
    if (context.mounted) {
      _showToast(context, context.tr('todo.clearedReminderTimeToast'));
    }
  }

  Future<void> _clearDueTime(
    BuildContext context,
    TodoListNotifier notifier,
    TodoItem todo,
  ) async {
    await notifier.updateDueTime(todo.id, null);
    if (context.mounted) {
      _showToast(context, context.tr('todo.clearedDueTimeToast'));
    }
  }

  Future<void> _openTagPicker(
    BuildContext context,
    WidgetRef ref,
    TodoListNotifier notifier,
    TodoItem todo,
  ) async {
    final navigator = Navigator.of(context);
    final current =
        await ref.read(tagRepositoryProvider).getTagsForTodo(todo.id);
    final selectedIds = current.map((t) => t.id).toList();
    final picked = await navigator.push<List<String>>(
      MaterialPageRoute(
        builder: (_) => TagPickerScreen(initialSelected: selectedIds),
      ),
    );

    if (picked == null) return;
    await notifier.setTags(todo.id, picked);
  }

  void _showEditDialog(
      BuildContext context, TodoListNotifier notifier, TodoItem todo) {
    final controller = TextEditingController(text: todo.text);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('todo.editDialogTitle')),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: context.tr('todo.editDialogHint'),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              final navigator = Navigator.of(dialogContext);
              await notifier.updateText(todo.id, controller.text.trim());
              navigator.pop();
            },
            child: Text(context.tr('common.save')),
          ),
        ],
      ),
    );
  }

  void _reRecord(BuildContext context, WidgetRef ref, TodoItem todo) {
    final recordingNotifier = ref.read(recordingStateProvider.notifier);

    recordingNotifier.startReRecord(todo).catchError((error) {
      if (context.mounted) {
        _showToast(
          context,
          context.tr('todo.reRecordFailed', params: {'error': '$error'}),
        );
      }
    });
  }

  Future<void> _playback(
      BuildContext context, WidgetRef ref, TodoItem todo) async {
    final audioPath = todo.audioPath;
    if (audioPath == null || audioPath.isEmpty) {
      if (context.mounted) {
        _showToast(context, context.tr('todo.noAudioToPlay'));
      }
      return;
    }

    try {
      await ref.read(audioPlaybackServiceProvider).play(audioPath);
    } catch (e) {
      if (context.mounted) {
        _showToast(
          context,
          context.tr('todo.playbackFailed', params: {'error': '$e'}),
        );
      }
    }
  }

  void _showToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        left: 16,
        right: 16,
        bottom: 24,
        child: SafeArea(
          child: ExcludeSemantics(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), entry.remove);
  }

  void _confirmDelete(
      BuildContext context, TodoListNotifier notifier, TodoItem todo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('todo.deleteDialogTitle')),
        content: Text(context.tr('todo.deleteDialogContent')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              await notifier.deleteTodo(todo.id);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text(context.tr('common.delete')),
          ),
        ],
      ),
    );
  }

  String _displayErrorMessage(BuildContext context, String? raw) {
    if (raw == null || raw.isEmpty) {
      return '';
    }

    final value = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
    switch (value) {
      case 'error.recordingFileGenerationFailed':
        return context.tr('errors.recordingFileGenerationFailed');
      case 'error.speechRecognitionFailed':
        return context.tr('errors.speechRecognitionFailed');
      default:
        return raw;
    }
  }
}
