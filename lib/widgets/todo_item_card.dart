import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/todo_item.dart';
import '../providers/app_providers.dart';
import 'completed_text.dart';

/// Individual todo item card widget
class TodoItemCard extends ConsumerWidget {
  final TodoItem todo;

  const TodoItemCard({
    super.key,
    required this.todo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(todoListProvider);
    final theme = Theme.of(context);
    final notifier = ref.read(todoListProvider.notifier);
    final isSelected = notifier.isSelected(todo.id);
    final isCompleted = todo.status == TodoStatus.completed;
    final isRecognizing = todo.taskState == TodoTaskState.recognizing;

    if (isRecognizing) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.5 : 0.8,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onLongPress: () => _confirmDelete(context, notifier),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        '转录中...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '正在将语音转换为文字',
                        style: TextStyle(
                          fontSize: 12,
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
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: isCompleted
          ? theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.55 : 0.7,
            )
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: InkResponse(
          onTap: () => notifier.toggleSelection(todo.id),
          radius: 24,
          containedInkWell: true,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  isSelected ? Icons.circle : Icons.radio_button_unchecked,
                  key: ValueKey(isSelected),
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDateTime(todo.createdAt),
              style: TextStyle(
                fontSize: 11,
                height: 1.1,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            if (isCompleted)
              CompletedText(
                text: todo.text.isEmpty ? '识别中...' : todo.text,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.2,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Text(
                todo.text.isEmpty ? '识别中...' : todo.text,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.2,
                  color: null,
                ),
              ),
            if (todo.taskState == TodoTaskState.recognizing)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: LinearProgressIndicator(),
              ),
            if (todo.taskState == TodoTaskState.failed &&
                todo.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '失败: ${todo.errorMessage}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              value: todo.status == TodoStatus.completed,
              onChanged: notifier.isStatusUpdating(todo.id)
                  ? null
                  : (value) => _setStatus(
                        notifier,
                        value == true
                            ? TodoStatus.completed
                            : TodoStatus.pending,
                      ),
            ),
          ],
        ),
        onTap: () => _showEditDialog(context, notifier),
        onLongPress: () => _showOptionsBottomSheet(context, ref, notifier),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today at ${_formatTime(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${_formatTime(dateTime)}';
    } else {
      return '${dateTime.year}-${_twoDigits(dateTime.month)}-${_twoDigits(dateTime.day)} ${_formatTime(dateTime)}';
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}';
  }

  String _twoDigits(int n) {
    return n.toString().padLeft(2, '0');
  }

  void _setStatus(TodoListNotifier notifier, TodoStatus status) {
    notifier.setCompletionStatus(todo.id, status);
  }

  void _showEditDialog(BuildContext context, TodoListNotifier notifier) {
    final controller = TextEditingController(text: todo.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Note'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Enter note text',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await notifier.updateText(todo.id, controller.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showOptionsBottomSheet(
      BuildContext context, WidgetRef ref, TodoListNotifier notifier) {
    final isCompleted = todo.status == TodoStatus.completed;
    final hasAudio = todo.audioPath != null && todo.audioPath!.isNotEmpty;
    final rootContext = context;

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
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showEditDialog(rootContext, notifier);
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('设置提醒时间'),
                subtitle: todo.remindAt == null
                    ? null
                    : Text('当前: ${_formatDateTimeValue(todo.remindAt!)}'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _setReminderTime(rootContext, ref, notifier);
                },
              ),
              if (todo.remindAt != null)
                ListTile(
                  leading: const Icon(Icons.notifications_off_outlined),
                  title: const Text('清除提醒'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _clearReminder(rootContext, ref, notifier);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.event_outlined),
                title: const Text('设置截止时间'),
                subtitle: todo.dueAt == null
                    ? null
                    : Text('当前: ${_formatDateTimeValue(todo.dueAt!)}'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _setDueTime(rootContext, ref, notifier);
                },
              ),
              if (todo.dueAt != null)
                ListTile(
                  leading: const Icon(Icons.event_busy_outlined),
                  title: const Text('清除截止时间'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _clearDueTime(rootContext, ref, notifier);
                  },
                ),
              if (hasAudio)
                ListTile(
                  leading: const Icon(Icons.play_arrow),
                  title: const Text('Playback'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _playback(rootContext, ref);
                  },
                ),
              if (!isCompleted)
                ListTile(
                  leading: const Icon(Icons.mic),
                  title: const Text('Re-record'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _reRecord(rootContext, ref);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(rootContext, notifier);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reRecord(BuildContext context, WidgetRef ref) {
    final recordingNotifier = ref.read(recordingStateProvider.notifier);

    recordingNotifier.startReRecord(todo).catchError((error) {
      if (context.mounted) {
        _showToast(context, '重录失败: $error');
      }
    });
  }

  Future<void> _setReminderTime(
    BuildContext context,
    WidgetRef ref,
    TodoListNotifier notifier,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final pickerResult = await _pickDateTime(context, initial: todo.remindAt);
    if (pickerResult == null) return;

    final updated = await notifier.updateReminderTime(todo.id, pickerResult);
    if (updated?.remindAt == null) {
      if (context.mounted) {
        _showToast(context, '提醒时间写入失败，请重试');
      }
      return;
    }
    await _ensureExactAlarmPermission(context, ref);
    await ref.read(reminderServiceProvider).scheduleReminderForTodo(updated!);
    await notifier.loadTodos();

    if (!context.mounted) return;

    _showToast(context, '提醒已设置为 ${_formatDateTimeValue(pickerResult)}');
  }

  Future<void> _clearReminder(
    BuildContext context,
    WidgetRef ref,
    TodoListNotifier notifier,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final updated = await notifier.updateReminderTime(todo.id, null);
    if (updated == null) {
      if (context.mounted) {
        _showToast(context, '提醒清除失败，请重试');
      }
      return;
    }
    await ref.read(reminderServiceProvider).clearReminder(todo.id);
    if (!context.mounted) return;
    _showToast(context, '提醒已清除');
  }

  Future<void> _setDueTime(
    BuildContext context,
    WidgetRef ref,
    TodoListNotifier notifier,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final pickerResult = await _pickDateTime(context, initial: todo.dueAt);
    if (pickerResult == null) return;

    final updated = await notifier.updateDueTime(todo.id, pickerResult);
    if (updated?.dueAt == null) {
      if (context.mounted) {
        _showToast(context, '截止时间写入失败，请重试');
      }
      return;
    }

    if (!context.mounted) return;

    _showToast(context, '截止时间已设置为 ${_formatDateTimeValue(pickerResult)}');
  }

  Future<void> _clearDueTime(
    BuildContext context,
    WidgetRef ref,
    TodoListNotifier notifier,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final updated = await notifier.updateDueTime(todo.id, null);
    if (updated == null) {
      if (context.mounted) {
        _showToast(context, '截止时间清除失败，请重试');
      }
      return;
    }
    if (!context.mounted) return;
    _showToast(context, '截止时间已清除');
  }

  Future<void> _ensureExactAlarmPermission(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final notificationService = ref.read(notificationServiceProvider);
    final allowed = await notificationService.canScheduleExactAlarms();
    if (allowed || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('允许精确提醒?'),
        content: const Text('系统限制精确闹钟，开启后提醒会更准。是否前往开启？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('稍后'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('去开启'),
          ),
        ],
      ),
    );

    if (shouldRequest != true || !context.mounted) return;

    final granted = await notificationService.requestExactAlarmsPermission();
    if (!context.mounted) return;
    if (!granted) {
      _showToast(context, '未开启精确提醒，将使用普通提醒');
    }
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context, {
    DateTime? initial,
  }) async {
    final now = DateTime.now();
    final initialDate = initial ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return null;

    if (!context.mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _formatDateTimeValue(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day $hour:$minute';
  }

  Future<void> _playback(BuildContext context, WidgetRef ref) async {
    final audioPath = todo.audioPath;
    if (audioPath == null || audioPath.isEmpty) {
      if (context.mounted) {
        _showToast(context, '没有可播放的音频');
      }
      return;
    }

    try {
      await ref.read(audioPlaybackServiceProvider).play(audioPath);
    } catch (e) {
      if (context.mounted) {
        _showToast(context, '播放失败: $e');
      }
    }
  }

  void _showToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

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

  void _confirmDelete(BuildContext context, TodoListNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
