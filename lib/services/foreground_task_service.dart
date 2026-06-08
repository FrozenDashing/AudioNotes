import 'dart:isolate';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Manages the persistent foreground service.
///
/// Chrono-style: a low-priority foreground notification keeps the app's
/// process alive, preventing Chinese ROMs (vivo OriginOS, OPPO ColorOS,
/// Xiaomi MIUI) from deprioritising or killing it when the app goes into
/// the background. Without this, [AndroidAlarmManager] callbacks may be
/// delayed or silently dropped.
class ForegroundTaskService {
  static const String _channelId = 'foreground_service';
  static const String _channelName = 'Background Service';
  static const String _channelDesc =
      'Keeps the app alive for reliable todo reminders';

  /// Initialise the foreground task framework (called once at app start).
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: _channelName,
        channelDescription: _channelDesc,
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start the foreground service.
  ///
  /// The OS will show a persistent low-priority notification so the system
  /// knows the app is doing background work.
  static Future<void> start() async {
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) return;

    await FlutterForegroundTask.startService(
      notificationTitle: 'Todo Reminders Active',
      notificationText: 'Background service is running for reminders',
      callback: _foregroundTaskCallback,
    );
  }

  /// Stop the foreground service.
  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }
}

/// Top-level callback required by [FlutterForegroundTask].
///
/// Sets up the task handler that runs in the foreground service isolate.
@pragma('vm:entry-point')
void _foregroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_TodoTaskHandler());
}

class _TodoTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // No-op: we only need the service alive for alarm scheduling.
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // No-op: periodic events are not needed for our use case.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // No-op.
  }

  @override
  void onNotificationButtonPressed(String id) {
    // No-op.
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }
}
