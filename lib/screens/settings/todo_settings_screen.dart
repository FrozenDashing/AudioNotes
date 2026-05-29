import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_i18n.dart';
import '../../models/todo_priority.dart';
import '../../providers/settings_provider.dart';

/// Todo-related settings section.
class TodoSettingsScreen extends ConsumerWidget {
  const TodoSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('settings.section.todo')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: context.tr('settings.todo.defaultPriority'),
            child: RadioGroup<TodoPriority>(
              groupValue: settings.defaultTodoPriority,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                ref
                    .read(settingsProvider.notifier)
                    .setDefaultTodoPriority(value);
              },
              child: Column(
                children: TodoPriority.values.map((priority) {
                  return RadioListTile<TodoPriority>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_priorityLabel(context, priority)),
                    value: priority,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: context.tr('settings.todo.aggregateCompleted'),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('settings.todo.aggregateCompletedTitle')),
              subtitle: Text(
                context.tr('settings.todo.aggregateCompletedSubtitle'),
                style: theme.textTheme.bodySmall,
              ),
              value: settings.aggregateCompletedTodos,
              onChanged: (value) {
                ref
                    .read(settingsProvider.notifier)
                    .setAggregateCompletedTodos(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _priorityLabel(BuildContext context, TodoPriority p) {
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
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
