import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';

/// Floating action toolbar for batch operations on todos
class FloatingActionToolbar extends ConsumerWidget {
  const FloatingActionToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(todoSummaryProvider);
    final notifier = ref.read(todoListProvider.notifier);
    final hasCompletedTodos = summary.completedCount > 0;
    final hasSelectedTodos = notifier.selectedIds.isNotEmpty;

    // Don't show toolbar if no completed todos and no selected todos.
    if (!hasCompletedTodos && !hasSelectedTodos) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 16,
      bottom: 16,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasCompletedTodos)
                IconButton(
                  icon: const Icon(Icons.cleaning_services),
                  tooltip: '清除所有已完成待办',
                  onPressed: () => _confirmDeleteAllCompleted(context, ref),
                  color: Colors.orange,
                ),
              if (hasSelectedTodos) ...[
                const VerticalDivider(width: 1),
                IconButton(
                  icon: const Icon(Icons.check),
                  tooltip: '完成选中的待办',
                  onPressed: () => _completeSelected(context, ref),
                  color: Colors.green,
                ),
                const VerticalDivider(width: 1),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: '删除选中的待办',
                  onPressed: () => _confirmDeleteSelected(context, ref),
                  color: Colors.red,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAllCompleted(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除已完成待办'),
        content: const Text('确定要删除所有已完成的待办吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            onPressed: () async {
              await ref.read(todoListProvider.notifier).deleteAllCompleted();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已清除所有已完成待办')),
                );
              }
            },
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }

  void _completeSelected(BuildContext context, WidgetRef ref) {
    final selectedIds =
        ref.read(todoListProvider.notifier).selectedIds.toList();
    if (selectedIds.isEmpty) return;

    ref.read(todoListProvider.notifier).completeTodos(selectedIds);

    // Show success message
    Future.delayed(const Duration(milliseconds: 100), () {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已完成 ${selectedIds.length} 个待办')),
        );
      }
    });
  }

  void _confirmDeleteSelected(BuildContext context, WidgetRef ref) {
    final selectedIds =
        ref.read(todoListProvider.notifier).selectedIds.toList();
    if (selectedIds.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除选中待办'),
        content: Text('确定要删除选中的 ${selectedIds.length} 个待办吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              await ref
                  .read(todoListProvider.notifier)
                  .deleteTodos(selectedIds);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已删除 ${selectedIds.length} 个待办')),
                );
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
