import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight tracker for notification fired status.
///
/// Usable from any isolate (main, WorkManager, android_alarm_manager_plus).
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
