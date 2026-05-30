/// Notification mode for todo reminders
enum NotificationMode {
  /// No reminder mode selected
  none,

  /// Use awesome notifications
  awesome,

  /// Use local notifications
  local,

  /// Use system calendar sync
  calendar,
}

/// Extension to convert NotificationMode to string
extension NotificationModeExtension on NotificationMode {
  String get stringValue {
    switch (this) {
      case NotificationMode.none:
        return 'none';
      case NotificationMode.awesome:
        return 'awesome';
      case NotificationMode.local:
        return 'local';
      case NotificationMode.calendar:
        return 'calendar';
    }
  }

  static NotificationMode fromString(String value) {
    switch (value) {
      case 'none':
        return NotificationMode.none;
      case 'awesome':
        return NotificationMode.local;
      case 'local':
        return NotificationMode.local;
      case 'calendar':
        return NotificationMode.calendar;
      default:
        return NotificationMode.none;
    }
  }
}
