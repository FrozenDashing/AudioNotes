import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_i18n.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/settings/notification_mode_selector.dart';

class GeneralSettingsScreen extends ConsumerWidget {
  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('settings.general.title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: Text(context.tr('settings.general.language')),
                  subtitle:
                      Text(context.tr('settings.general.languageSubtitle')),
                ),
                RadioGroup<String>(
                  groupValue: settings.languageCode,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    ref.read(settingsProvider.notifier).setLanguageCode(value);
                  },
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: 'zh_CN',
                        title: Text(context.tr('settings.general.langZhCn')),
                      ),
                      RadioListTile<String>(
                        value: 'en',
                        title: Text(context.tr('settings.general.langEn')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const NotificationModeSelector(),
        ],
      ),
    );
  }
}
