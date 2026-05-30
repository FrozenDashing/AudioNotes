import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_i18n.dart';
import 'screens/home_screen.dart';
import 'models/settings_state.dart';
import 'providers/settings_provider.dart';
import 'providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize shared preferences
  await SharedPreferences.getInstance();

  runApp(
    const ProviderScope(
      child: AudioNotesApp(),
    ),
  );
}

class AudioNotesApp extends ConsumerStatefulWidget {
  const AudioNotesApp({super.key});

  @override
  ConsumerState<AudioNotesApp> createState() => _AudioNotesAppState();
}

class _AudioNotesAppState extends ConsumerState<AudioNotesApp> {
  final FlutterI18nDelegate _i18nDelegate = FlutterI18nDelegate(
    translationLoader: FileTranslationLoader(
      basePath: 'assets/i18n',
      fallbackFile: 'en',
      useCountryCode: true,
    ),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_initializeServices());
  }

  Future<void> _initializeServices() async {
    try {
      await ref.read(notificationServiceProvider).initialize();
      await ref.read(reminderServiceProvider).syncPendingReminders();

      final settingsRepository = ref.read(settingsRepositoryProvider);
      final settings = await settingsRepository.loadSettings();
      if (settings.trashAutoPurgeInterval != TrashAutoPurgeInterval.never) {
        final cutoff = DateTime.now().subtract(
          switch (settings.trashAutoPurgeInterval) {
            TrashAutoPurgeInterval.oneDay => const Duration(days: 1),
            TrashAutoPurgeInterval.threeDays => const Duration(days: 3),
            TrashAutoPurgeInterval.sevenDays => const Duration(days: 7),
            TrashAutoPurgeInterval.thirtyDays => const Duration(days: 30),
            TrashAutoPurgeInterval.never => Duration.zero,
          },
        );

        final todoRepository = ref.read(todoRepositoryProvider);
        final deletedTodos = await todoRepository.getDeletedTodos();
        for (final todo in deletedTodos) {
          final deletedAt = todo.deletedAt;
          if (deletedAt != null && deletedAt.isBefore(cutoff)) {
            await ref.read(reminderServiceProvider).clearReminder(todo.id);
            await todoRepository.purgeTodoPermanently(todo.id);
          }
        }
      }
    } catch (e) {
      foundation.debugPrint('Reminder service initialization failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsService = ref.watch(settingsServiceProvider);
    final systemScale = MediaQuery.textScalerOf(context).scale(1.0);
    final effectiveTextScale = settingsService.getEffectiveTextScaleFactor(
      settings,
      systemScale: systemScale,
    );

    return MaterialApp(
      onGenerateTitle: (context) => context.tr('app.title'),
      debugShowCheckedModeBanner: false,
      locale: _localeFromCode(settings.languageCode),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en'),
      ],
      localizationsDelegates: [
        _i18nDelegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: settingsService.getThemeData(settings),
      darkTheme: settingsService.getDarkThemeData(settings),
      themeMode: settingsService.getThemeMode(settings),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(effectiveTextScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const HomeScreen(),
    );
  }

  Locale _localeFromCode(String code) {
    if (code == 'en') {
      return const Locale('en');
    }
    if (code == 'zh' || code == 'zh_CN') {
      return const Locale('zh', 'CN');
    }
    return const Locale('zh', 'CN');
  }
}
