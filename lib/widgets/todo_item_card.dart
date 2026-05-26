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
                style: TextStyle(
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

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(context, notifier);
              },
            ),
            ListTile(
              leading: Icon(isCompleted ? Icons.play_arrow : Icons.mic),
              title: Text(isCompleted ? 'Playback' : 'Re-record'),
              onTap: () {
                Navigator.pop(context);
                if (isCompleted) {
                  _playback(context, ref);
                } else {
                  _reRecord(context, ref);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, notifier);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _reRecord(BuildContext context, WidgetRef ref) {
    final recordingNotifier = ref.read(recordingStateProvider.notifier);

    recordingNotifier.startReRecord(todo).catchError((error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重录失败: $error')),
        );
      }
    });
  }

  Future<void> _playback(BuildContext context, WidgetRef ref) async {
    final audioPath = todo.audioPath;
    if (audioPath == null || audioPath.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可播放的音频')),
        );
      }
      return;
    }

    try {
      await ref.read(audioPlaybackServiceProvider).play(audioPath);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e')),
        );
      }
    }
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
