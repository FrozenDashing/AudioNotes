import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        title: const Text('语音设置'),
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
                  title: const Text('语音模型'),
                  subtitle: Text(
                    settings.autoModelSelect
                        ? '当前：自动选择'
                        : '当前：${settings.currentModelId}',
                  ),
                  trailing: Chip(
                    label: Text(settings.autoModelSelect ? '自动' : '手动'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.manage_search_outlined),
                  title: const Text('管理模型'),
                  subtitle: const Text('下载、选择或删除语音识别模型'),
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
                  title: const Text('自动选择模型'),
                  subtitle: const Text('开启后系统会自动使用可用模型。'),
                  value: settings.autoModelSelect,
                  onChanged: (value) {
                    ref
                        .read(settingsProvider.notifier)
                        .setAutoModelSelect(value);
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
