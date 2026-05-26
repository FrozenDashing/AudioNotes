import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/todo_item.dart';
import '../providers/app_providers.dart';
import 'audio_player_widget.dart';

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
    final confidenceLevel = ConfidenceLevel.fromValue(todo.confidence);
    final notifier = ref.read(todoListProvider.notifier);
    final isSelected = notifier.isSelected(todo.id);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
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
              todo.text.isEmpty ? '识别中...' : todo.text,
              style: TextStyle(
                fontSize: 16,
                decoration: todo.status == TodoStatus.completed
                    ? TextDecoration.lineThrough
                    : null,
                color: todo.status == TodoStatus.completed
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : null,
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Audio player if audio file exists
            if (todo.audioPath != null &&
                todo.audioPath!.isNotEmpty &&
                todo.taskState == TodoTaskState.ready)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: AudioPlayerWidget(audioPath: todo.audioPath!),
              ),

            Text(
              _formatDateTime(todo.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (confidenceLevel == ConfidenceLevel.low &&
                todo.taskState == TodoTaskState.ready)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Recognition may be inaccurate',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
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
        onLongPress: () => _showOptionsBottomSheet(context, notifier),
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
      BuildContext context, TodoListNotifier notifier) {
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
              leading: const Icon(Icons.mic),
              title: const Text('Re-record'),
              onTap: () {
                Navigator.pop(context);
                _reRecord(context);
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

  void _reRecord(BuildContext context) {
    // TODO: Implement re-recording functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Re-record feature coming soon')),
    );
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
