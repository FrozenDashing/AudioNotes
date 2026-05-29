import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_i18n.dart';
import '../models/settings_state.dart';
import '../models/todo_priority.dart';
import '../models/todo_sort.dart';
import '../providers/settings_provider.dart';
import '../sync/providers/sync_provider.dart';
import '../sync/coordinator/sync_coordinator.dart';
import '../utils/motion.dart';
import 'settings/appearance_settings_screen.dart';
import 'settings/general_settings_screen.dart';
import 'settings/todo_settings_screen.dart';
import 'settings/voice_settings_screen.dart';
import 'sync/webdav_settings_screen.dart';

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
        title: Text(context.tr('settings.title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          motionEntrance(
            context,
            _SettingsHubCard(
              icon: Icons.tune_outlined,
              accentColor: Theme.of(context).colorScheme.primary,
              title: context.tr('settings.section.general'),
              subtitle:
                  '${context.tr('settings.general.language')}：${_languageLabel(context, settings.languageCode)}',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GeneralSettingsScreen(),
                  ),
                );
              },
            ),
            duration: MotionTokens.page,
          ),
          const SizedBox(height: 12),
          motionEntrance(
            context,
            _SettingsHubCard(
              icon: Icons.palette_outlined,
              accentColor: Theme.of(context).colorScheme.primary,
              title: context.tr('settings.section.appearance'),
              subtitle:
                  '${context.tr('settings.summary.fontSize')}：${_fontSizeLabel(context, settings.fontSizeOption)} · ${context.tr('settings.summary.theme')}：${_themeModeLabel(context, settings.themeMode)}',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AppearanceSettingsScreen(),
                  ),
                );
              },
            ),
            duration: MotionTokens.page,
          ),
          const SizedBox(height: 12),
          motionEntrance(
            context,
            _SettingsHubCard(
              icon: Icons.checklist_outlined,
              accentColor: Theme.of(context).colorScheme.secondary,
              title: context.tr('settings.section.todo'),
              subtitle:
                  '${context.tr('settings.summary.defaultPriority')}：${_priorityLabel(context, settings.defaultTodoPriority)} · ${context.tr('settings.summary.completedAggregation')}：${settings.aggregateCompletedTodos ? context.tr('common.enabled') : context.tr('common.disabled')} · ${context.tr('settings.summary.sort')}：${_sortSummary(context, settings)}',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TodoSettingsScreen(),
                  ),
                );
              },
            ),
            duration: MotionTokens.page,
          ),
          const SizedBox(height: 12),
          motionEntrance(
            context,
            _SettingsHubCard(
              icon: Icons.graphic_eq_outlined,
              accentColor: Theme.of(context).colorScheme.tertiary,
              title: context.tr('settings.section.voice'),
              subtitle: settings.autoModelSelect
                  ? '${context.tr('settings.summary.model')}：${context.tr('settings.summary.autoSelect')} · ${context.tr('settings.summary.trailingPeriodRemoval')}：${settings.autoRemoveTrailingPeriod ? context.tr('common.enabled') : context.tr('common.disabled')}'
                  : '${context.tr('settings.summary.model')}：${settings.currentModelId} · ${context.tr('settings.summary.trailingPeriodRemoval')}：${settings.autoRemoveTrailingPeriod ? context.tr('common.enabled') : context.tr('common.disabled')}',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VoiceSettingsScreen(),
                  ),
                );
              },
            ),
            duration: MotionTokens.page,
          ),
          const SizedBox(height: 12),
          motionEntrance(
            context,
            _SettingsHubCard(
              icon: Icons.cloud_outlined,
              accentColor: Theme.of(context).colorScheme.primary,
              title: context.tr('settings.section.sync'),
              subtitle: _syncSummary(context, ref),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WebDavSettingsScreen(),
                  ),
                );
              },
            ),
            duration: MotionTokens.page,
          ),
          const SizedBox(height: 24),
          motionEntrance(
            context,
            OutlinedButton.icon(
              onPressed: () {
                ref.read(settingsProvider.notifier).resetToDefaults();
              },
              icon: const Icon(Icons.restart_alt),
              label: Text(context.tr('settings.restoreDefaults')),
            ),
            duration: MotionTokens.short,
            slideY: 0.02,
          ),
        ],
      ),
    );
  }

  String _languageLabel(BuildContext context, String code) {
    if (code == 'en') {
      return context.tr('settings.general.langEn');
    }
    return context.tr('settings.general.langZhCn');
  }

  String _themeModeLabel(BuildContext context, ThemeModeOption mode) {
    switch (mode) {
      case ThemeModeOption.system:
        return context.tr('settings.appearance.themeMode.system');
      case ThemeModeOption.light:
        return context.tr('settings.appearance.themeMode.light');
      case ThemeModeOption.dark:
        return context.tr('settings.appearance.themeMode.dark');
      case ThemeModeOption.custom:
        return context.tr('settings.appearance.themeMode.custom');
    }
  }

  String _fontSizeLabel(BuildContext context, FontSizeOption option) {
    switch (option) {
      case FontSizeOption.small:
        return context.tr('settings.appearance.fontSizeOption.small');
      case FontSizeOption.medium:
        return context.tr('settings.appearance.fontSizeOption.medium');
      case FontSizeOption.large:
        return context.tr('settings.appearance.fontSizeOption.large');
      case FontSizeOption.custom:
        return context.tr('settings.appearance.fontSizeOption.custom');
    }
  }

  String _priorityLabel(BuildContext context, TodoPriority priority) {
    switch (priority) {
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

  String _sortSummary(BuildContext context, SettingsState settings) {
    final field = switch (settings.todoSortField) {
      TodoSortField.manual => context.tr('settings.todo.sort.manual'),
      TodoSortField.createdAt => context.tr('settings.todo.sort.createdAt'),
      TodoSortField.dueAt => context.tr('settings.todo.sort.dueAt'),
      TodoSortField.priority => context.tr('settings.todo.sort.priority'),
    };
    final direction = switch (settings.todoSortDirection) {
      SortDirection.asc => context.tr('settings.todo.sort.asc'),
      SortDirection.desc => context.tr('settings.todo.sort.desc'),
    };
    return '$field / $direction';
  }

  String _syncSummary(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    if (!syncState.isConfigured) {
      return '${context.tr('settings.summary.syncStatus')}：${context.tr('common.disabled')}';
    }
    final statusStr = switch (syncState.status) {
      SyncStatus.idle => context.tr('common.enabled'),
      SyncStatus.syncing => context.tr('settings.sync.syncing'),
      SyncStatus.success => context.tr('settings.sync.success'),
      SyncStatus.error => context.tr('settings.sync.failed'),
      SyncStatus.conflict => context.tr('settings.sync.conflict.manual'),
    };
    return '${context.tr('settings.summary.syncStatus')}：$statusStr';
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

    return motionEntrance(
      context,
      Card(
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
      ),
    );
  }
}
