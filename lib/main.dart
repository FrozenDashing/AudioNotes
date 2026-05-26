import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      title: 'AudioNotes',
      debugShowCheckedModeBanner: false,
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
}
