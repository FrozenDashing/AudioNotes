import 'dart:async';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_show_when_locked/flutter_show_when_locked.dart';

import 'l10n/app_i18n.dart';
import 'sync/background/webdav_background_sync.dart';
import 'screens/home_screen.dart';
import 'models/settings_state.dart';
import 'providers/app_providers.dart';
import 'providers/settings_provider.dart';
import 'services/local_notification_service.dart';
import 'services/notification_controller.dart';
import 'services/foreground_task_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted language before runApp so the MaterialApp locale
  // is correct from the very first frame
  final prefs = await SharedPreferences.getInstance();
  setPreloadedLanguageCode(prefs.getString('language_code'));

  // Initialize awesome_notifications
  await localNotificationService.initialize();

  // Initialize android_alarm_manager_plus for reliable background scheduling
  await AndroidAlarmManager.initialize();

  // Cancel stale alarms from the old notification system
  await localNotificationService.cancelStaleAlarms();

  // Initialize foreground service to keep process alive (Chrono pattern)
  ForegroundTaskService.init();
  // Start foreground service — vivo won't kill the process while a
  // foreground notification is visible
  unawaited(ForegroundTaskService.start());

  // Hide any stale lock-screen overlay (Chrono pattern)
  await FlutterShowWhenLocked().hide();

  await initializeWebDavBackgroundSync();

  runApp(const ProviderScope(child: AudioNotesApp()));
}

class AudioNotesApp extends ConsumerStatefulWidget {
  const AudioNotesApp({super.key});

  @override
  ConsumerState<AudioNotesApp> createState() => _AudioNotesAppState();
}

class _AudioNotesAppState extends ConsumerState<AudioNotesApp> {
  static const MethodChannel _launchChannel =
      MethodChannel('com.audionotes/launch');
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
    _launchChannel.setMethodCallHandler(_handleLaunchMethodCall);
    unawaited(_consumeWidgetRecordingLaunch());
    unawaited(_initializeServices());

    // Set up awesome_notifications event listeners
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: NotificationController.onActionReceivedMethod,
      onNotificationCreatedMethod:
          NotificationController.onNotificationCreatedMethod,
      onNotificationDisplayedMethod:
          NotificationController.onNotificationDisplayedMethod,
      onDismissActionReceivedMethod:
          NotificationController.onDismissActionReceivedMethod,
    );

    // Link notification tap to navigation handler
    NotificationController.onNotificationTap = (todoId) {
      foundation.debugPrint('Notification tapped: $todoId');
      // Navigate to home screen — the HomeScreen will detect
      // the launch todoId from its own route args or provider
    };
  }

  Future<void> _handleLaunchMethodCall(MethodCall call) async {
    if (call.method != 'startRecordingFromWidget') {
      return;
    }

    await _consumeWidgetRecordingLaunch();
  }

  Future<void> _initializeServices() async {
    final todoRepository = ref.read(todoRepositoryProvider);

    try {
      await ref.read(reminderServiceProvider).initialize();

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

    try {
      final todos = await todoRepository.getAllTodos(sortByOrder: true);
      await ref.read(widgetSyncServiceProvider).syncTodoSummary(todos);
    } catch (e) {
      foundation.debugPrint('Widget sync initialization failed: $e');
    }

    await _consumeWidgetRecordingLaunch();
  }

  Future<void> _consumeWidgetRecordingLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldStartRecording =
        prefs.getBool('flutter.widget.launch.recording') ?? false;
    if (!shouldStartRecording || !mounted) {
      return;
    }

    await prefs.setBool('flutter.widget.launch.recording', false);
    final recordingNotifier = ref.read(recordingStateProvider.notifier);
    if (ref.read(recordingStateProvider) == RecordingState.idle) {
      unawaited(recordingNotifier.start().catchError((error) {
        foundation.debugPrint('Widget launch recording failed: $error');
      }));
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
