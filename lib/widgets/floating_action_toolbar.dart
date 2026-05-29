import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_i18n.dart';
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
                  tooltip: context.tr('toolbar.clearCompletedTooltip'),
                  onPressed: () => _confirmDeleteAllCompleted(context, ref),
                  color: Colors.orange,
                ),
              if (hasSelectedTodos) ...[
                const VerticalDivider(width: 1),
                IconButton(
                  icon: const Icon(Icons.check),
                  tooltip: context.tr('toolbar.completeSelectedTooltip'),
                  onPressed: () => _completeSelected(context, ref),
                  color: Colors.green,
                ),
                const VerticalDivider(width: 1),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: context.tr('toolbar.deleteSelectedTooltip'),
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
        title: Text(context.tr('toolbar.clearCompletedTitle')),
        content: Text(context.tr('toolbar.clearCompletedContent')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.cancel')),
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
                  SnackBar(
                      content: Text(context.tr('toolbar.clearedCompleted'))),
                );
              }
            },
            child: Text(context.tr('toolbar.clearAction')),
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
          SnackBar(
            content: Text(context.tr('toolbar.completedCount',
                params: {'count': '${selectedIds.length}'})),
          ),
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
        title: Text(context.tr('toolbar.deleteSelectedTitle')),
        content: Text(context.tr('toolbar.deleteSelectedContent',
            params: {'count': '${selectedIds.length}'})),
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
              await ref
                  .read(todoListProvider.notifier)
                  .deleteTodos(selectedIds);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr('toolbar.deletedCount',
                        params: {'count': '${selectedIds.length}'})),
                  ),
                );
              }
            },
            child: Text(context.tr('common.delete')),
          ),
        ],
      ),
    );
  }
}
