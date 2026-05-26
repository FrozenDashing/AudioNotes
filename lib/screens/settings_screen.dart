import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../models/settings_state.dart';
import '../widgets/theme_color_picker.dart';
import '../widgets/font_size_slider.dart';
import 'model_selection_screen.dart';

/// Settings screen with model switch, theme color, and font size options
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
          // Section A: Voice Model
          _buildVoiceModelSection(context, ref, settings),

          const Divider(height: 32),

          // Section B: Theme Color
          _buildThemeColorSection(context, ref, settings),

          const Divider(height: 32),

          // Section C: Font Size
          _buildFontSizeSection(context, ref, settings),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(settingsProvider.notifier).resetToDefaults();
                  },
                  child: const Text('恢复默认'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceModelSection(
      BuildContext context, WidgetRef ref, SettingsState settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '语音模型',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    settings.autoModelSelect
                        ? '当前模型: 自动选择'
                        : '当前模型: ${settings.currentModelId}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    settings.autoModelSelect ? '自动' : '手动',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  onPressed: () async {
                    final selectedModelId = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ModelSelectionScreen(),
                      ),
                    );

                    if (selectedModelId != null && context.mounted) {
                      await ref
                          .read(settingsProvider.notifier)
                          .setCurrentModelId(selectedModelId);
                      await ref
                          .read(settingsProvider.notifier)
                          .setAutoModelSelect(false);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('自动选择模型'),
                const Spacer(),
                Switch(
                  value: settings.autoModelSelect,
                  onChanged: (value) {
                    ref
                        .read(settingsProvider.notifier)
                        .setAutoModelSelect(value);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeColorSection(
      BuildContext context, WidgetRef ref, SettingsState settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '主题色',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ThemeColorPicker(
              currentThemeMode: settings.themeMode,
              currentCustomColor: settings.customThemeColor,
              onThemeModeChanged: (mode) {
                ref.read(settingsProvider.notifier).setThemeMode(mode);
              },
              onCustomColorChanged: (color) {
                ref.read(settingsProvider.notifier).setCustomThemeColor(color);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontSizeSection(
      BuildContext context, WidgetRef ref, SettingsState settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '字号',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FontSizeSlider(
              currentFontSizeOption: settings.fontSizeOption,
              currentCustomScale: settings.customFontScale,
              followSystemFontSize: settings.followSystemFontSize,
              onFontSizeOptionChanged: (option) {
                ref.read(settingsProvider.notifier).setFontSizeOption(option);
              },
              onCustomScaleChanged: (scale) {
                ref.read(settingsProvider.notifier).setCustomFontScale(scale);
              },
              onFollowSystemFontSizeChanged: (value) {
                ref
                    .read(settingsProvider.notifier)
                    .setFollowSystemFontSize(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}
