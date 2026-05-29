import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_i18n.dart';
import '../../providers/settings_provider.dart';
import '../model_selection_screen.dart';

/// Voice-related settings section.
class VoiceSettingsScreen extends ConsumerWidget {
  const VoiceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('settings.section.voice')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.model_training_outlined),
                  title: Text(context.tr('settings.voice.model')),
                  subtitle: Text(
                    settings.autoModelSelect
                        ? context.tr('settings.voice.currentAuto')
                        : '${context.tr('settings.voice.currentManualPrefix')}${settings.currentModelId}',
                  ),
                  trailing: Chip(
                    label: Text(settings.autoModelSelect
                        ? context.tr('common.auto')
                        : context.tr('common.manual')),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.manage_search_outlined),
                  title: Text(context.tr('settings.voice.manageModel')),
                  subtitle:
                      Text(context.tr('settings.voice.manageModelSubtitle')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ModelSelectionScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(context.tr('settings.voice.autoSelectModel')),
                  subtitle: Text(
                      context.tr('settings.voice.autoSelectModelSubtitle')),
                  value: settings.autoModelSelect,
                  onChanged: (value) {
                    ref
                        .read(settingsProvider.notifier)
                        .setAutoModelSelect(value);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(
                      context.tr('settings.voice.autoRemoveTrailingPeriod')),
                  subtitle: Text(
                    context
                        .tr('settings.voice.autoRemoveTrailingPeriodSubtitle'),
                  ),
                  value: settings.autoRemoveTrailingPeriod,
                  onChanged: (value) {
                    ref
                        .read(settingsProvider.notifier)
                        .setAutoRemoveTrailingPeriod(value);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
