import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/settings_state.dart';
import '../models/todo_priority.dart';
import '../models/todo_sort.dart';
import '../providers/settings_provider.dart';
import 'settings/appearance_settings_screen.dart';
import 'settings/todo_settings_screen.dart';
import 'settings/voice_settings_screen.dart';

/// Settings hub screen.
///
/// This screen only routes users into the three dedicated settings sections.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsHubCard(
            icon: Icons.palette_outlined,
            accentColor: Theme.of(context).colorScheme.primary,
            title: '外观设置',
            subtitle:
                '字号：${_fontSizeLabel(settings.fontSizeOption)} · 主题色：${_themeModeLabel(settings.themeMode)}',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AppearanceSettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _SettingsHubCard(
            icon: Icons.checklist_outlined,
            accentColor: Theme.of(context).colorScheme.secondary,
            title: '代办设置',
            subtitle:
                '默认优先级：${_priorityLabel(settings.defaultTodoPriority)} · 已完成聚合：${settings.aggregateCompletedTodos ? '开启' : '关闭'} · 排序：${_sortSummary(settings)}',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TodoSettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _SettingsHubCard(
            icon: Icons.graphic_eq_outlined,
            accentColor: Theme.of(context).colorScheme.tertiary,
            title: '语音设置',
            subtitle: settings.autoModelSelect
                ? '模型：自动选择'
                : '模型：${settings.currentModelId}',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VoiceSettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              ref.read(settingsProvider.notifier).resetToDefaults();
            },
            icon: const Icon(Icons.restart_alt),
            label: const Text('恢复默认'),
          ),
        ],
      ),
    );
  }

  String _themeModeLabel(ThemeModeOption mode) {
    switch (mode) {
      case ThemeModeOption.system:
        return '跟随系统';
      case ThemeModeOption.light:
        return '浅色';
      case ThemeModeOption.dark:
        return '深色';
      case ThemeModeOption.custom:
        return '自定义';
    }
  }

  String _fontSizeLabel(FontSizeOption option) {
    switch (option) {
      case FontSizeOption.small:
        return '小';
      case FontSizeOption.medium:
        return '中';
      case FontSizeOption.large:
        return '大';
      case FontSizeOption.custom:
        return '自定义';
    }
  }

  String _priorityLabel(TodoPriority priority) {
    switch (priority) {
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

  String _sortSummary(SettingsState settings) {
    final field = switch (settings.todoSortField) {
      TodoSortField.manual => '手动顺序',
      TodoSortField.createdAt => '创建时间',
      TodoSortField.dueAt => '截止时间',
      TodoSortField.priority => '优先级',
    };
    final direction = switch (settings.todoSortDirection) {
      SortDirection.asc => '升序',
      SortDirection.desc => '降序',
    };
    return '$field / $direction';
  }
}

class _SettingsHubCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsHubCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
