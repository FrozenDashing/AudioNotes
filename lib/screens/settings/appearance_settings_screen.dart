import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_i18n.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/font_size_slider.dart';
import '../../widgets/theme_color_picker.dart';
import '../../utils/motion.dart';

/// Appearance settings section.
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('settings.section.appearance')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          motionEntrance(
            context,
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('settings.appearance.themeColor'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ThemeColorPicker(
                      currentThemeMode: settings.themeMode,
                      currentCustomColor: settings.customThemeColor,
                      onThemeModeChanged: (mode) {
                        ref.read(settingsProvider.notifier).setThemeMode(mode);
                      },
                      onCustomColorChanged: (color) {
                        ref
                            .read(settingsProvider.notifier)
                            .setCustomThemeColor(color);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          motionEntrance(
            context,
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('settings.appearance.fontSize'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    FontSizeSlider(
                      currentFontSizeOption: settings.fontSizeOption,
                      currentCustomScale: settings.customFontScale,
                      followSystemFontSize: settings.followSystemFontSize,
                      onFontSizeOptionChanged: (option) {
                        ref
                            .read(settingsProvider.notifier)
                            .setFontSizeOption(option);
                      },
                      onCustomScaleChanged: (scale) {
                        ref
                            .read(settingsProvider.notifier)
                            .setCustomFontScale(scale);
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
            ),
          ),
        ],
      ),
    );
  }
}
