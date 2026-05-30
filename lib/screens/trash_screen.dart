import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/app_i18n.dart';
import '../models/todo_item.dart';
import '../providers/app_providers.dart';
import '../utils/motion.dart';

/// Trash screen for soft-deleted todos.
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trashAsync = ref.watch(trashTodosProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('trash.title')),
        actions: [
          IconButton(
            tooltip: context.tr('trash.clearAll'),
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => _confirmClearAll(context, ref),
          ),
        ],
      ),
      body: trashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(error.toString()),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr('trash.emptyTitle'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('trash.emptySubtitle'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final todo = items[index];
              return motionEntrance(
                context,
                _TrashTodoCard(
                  todo: todo,
                  onTap: () => _showActions(context, ref, todo),
                ),
                duration: MotionTokens.page,
                slideY: 0.03,
              );
            },
          );
        },
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref, TodoItem todo) {
    final messenger = ScaffoldMessenger.of(context);
    final restoreLabel = context.tr('trash.restore');
    final purgeLabel = context.tr('trash.purge');
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.restore_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(restoreLabel),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await ref
                        .read(trashTodosProvider.notifier)
                        .restoreTodo(todo.id);
                    _showToast(messenger, restoreLabel);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: Colors.red,
                  ),
                  title: Text(purgeLabel),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final confirmed = await _confirmPurge(context);
                    if (confirmed) {
                      await ref
                          .read(trashTodosProvider.notifier)
                          .purgeTodo(todo.id);
                      _showToast(messenger, purgeLabel);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final clearLabel = context.tr('trash.clearAllAction');
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.tr('trash.clearAllTitle')),
            content: Text(context.tr('trash.clearAllContent')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.tr('common.cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.tr('trash.clearAllAction')),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    await ref.read(trashTodosProvider.notifier).purgeAllTrash();
    _showToast(messenger, clearLabel);
  }

  Future<bool> _confirmPurge(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.tr('trash.clearAllTitle')),
            content: Text(context.tr('trash.clearAllContent')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.tr('common.cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.tr('trash.purge')),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showToast(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _TrashTodoCard extends StatelessWidget {
  final TodoItem todo;
  final VoidCallback onTap;

  const _TrashTodoCard({
    required this.todo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deletedText = DateFormat('yyyy-MM-dd HH:mm').format(
      todo.deletedAt ?? todo.updatedAt ?? todo.createdAt,
    );
    final displayText = todo.text.trim().isEmpty
        ? (todo.rawTranscript?.trim().isNotEmpty == true
            ? todo.rawTranscript!.trim()
            : todo.text)
        : todo.text;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayText.isEmpty ? ' ' : displayText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr('trash.deletedAt', params: {'time': deletedText}),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
