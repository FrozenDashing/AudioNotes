import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        title: const Text('代办设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: '默认优先级',
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
                    title: Text(_priorityLabel(priority)),
                    value: priority,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '已完成聚合',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('聚合已完成待办'),
              subtitle: Text(
                '开启后，所有已完成待办将集中到“已完成”分组。',
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

  String _priorityLabel(TodoPriority p) {
    switch (p) {
      case TodoPriority.low:
        return '低';
      case TodoPriority.normal:
        return '普通';
      case TodoPriority.high:
        return '高';
      case TodoPriority.urgent:
        return '紧急';
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
