import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_i18n.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';
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
    } catch (e) {
      debugPrint('Reminder service initialization failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsService = SettingsService();
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
