import 'dart:async';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Static callback handlers for awesome_notifications events.
///
/// All methods must be top-level and annotated with @pragma("vm:entry-point")
/// so the Dart VM preserves them for native-to-Dart calls from background isolates.
class NotificationController {
  /// Callback invoked when the user taps a notification.
  /// Set by main.dart during initialization.
  static void Function(String todoId)? onNotificationTap;

  /// Fires when a new notification or schedule is created.
  @pragma('vm:entry-point')
  static Future<void> onNotificationCreatedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    debugPrint(
      'Notification created: id=${receivedNotification.id}, '
      'channelKey=${receivedNotification.channelKey}',
    );
  }

  /// Fires every time a notification is displayed on the system status bar.
  @pragma('vm:entry-point')
  static Future<void> onNotificationDisplayedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    debugPrint(
      'Notification displayed: id=${receivedNotification.id}',
    );
  }

  /// Fires when the user taps on a notification or action button.
  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    final payload = receivedAction.payload;
    final todoId = payload?['todoId'];

    debugPrint(
      'Notification action received: id=${receivedAction.id}, '
      'todoId=$todoId',
    );

    if (todoId != null && todoId.isNotEmpty) {
      // Forward to the app-level callback for navigation.
      // Set by main.dart during initialization.
      onNotificationTap?.call(todoId);
    }
  }

  /// Fires when the user dismisses a notification.
  @pragma('vm:entry-point')
  static Future<void> onDismissActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    debugPrint(
      'Notification dismissed: id=${receivedAction.id}',
    );
  }
}

/// Lightweight tracker for notification fired status.
///
/// Usable from any isolate (main, WorkManager).
class NotificationFiredTracker {
  static const String _firedPrefix = 'notification.fired.';

  /// Record that a notification was displayed for the given todo.
  static Future<void> recordFired(String todoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_firedPrefix$todoId', true);
    } catch (e) {
      debugPrint('Failed to record fired notification: $e');
    }
  }

  /// Consume and return the set of todo IDs whose notifications have fired
  /// since the last call. The keys are removed from SharedPreferences.
  static Future<Set<String>> consumeFired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final firedIds = <String>{};
      for (final key in prefs.getKeys()) {
        if (key.startsWith(_firedPrefix)) {
          final todoId = key.substring(_firedPrefix.length);
          if (prefs.getBool(key) == true) {
            firedIds.add(todoId);
          }
          await prefs.remove(key);
        }
      }
      return firedIds;
    } catch (e) {
      debugPrint('Failed to consume fired notifications: $e');
      return {};
    }
  }
}
