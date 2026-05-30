import 'package:flutter/material.dart';
import '../models/todo_sort.dart';
import '../models/todo_priority.dart';
import '../models/notification_mode.dart';

/// Enum for theme modes
enum ThemeModeOption { system, light, dark, custom }

/// Enum for font sizes
enum FontSizeOption { small, medium, large, custom }

/// Retention period for items kept in the trash.
enum TrashAutoPurgeInterval {
  oneDay,
  threeDays,
  sevenDays,
  thirtyDays,
  never,
}

/// Model representing app settings state
class SettingsState {
  /// Current model ID
  final String currentModelId;

  /// Whether to auto-select model
  final bool autoModelSelect;

  /// Theme mode option
  final ThemeModeOption themeMode;

  /// Custom theme color (when themeMode is custom)
  final Color? customThemeColor;

  /// Font size option
  final FontSizeOption fontSizeOption;

  /// Custom font scale (when fontSizeOption is custom)
  final double customFontScale;

  /// Whether to follow system font size (accessibility)
  final bool followSystemFontSize;

  /// Todo list sort field preference
  final TodoSortField todoSortField;

  /// Todo list sort direction preference
  final SortDirection todoSortDirection;

  /// Default priority for new todos
  final TodoPriority defaultTodoPriority;

  /// Whether completed todos are aggregated into a dedicated completed group
  final bool aggregateCompletedTodos;

  /// Whether to auto-remove trailing sentence-ending period from recognition text
  final bool autoRemoveTrailingPeriod;

  /// How long deleted todos should stay in trash before auto-purging.
  final TrashAutoPurgeInterval trashAutoPurgeInterval;

  /// Selected app language code (e.g. zh_CN, en)
  final String languageCode;

  /// Notification mode for reminders
  final NotificationMode notificationMode;

  SettingsState({
    required this.currentModelId,
    required this.autoModelSelect,
    required this.themeMode,
    this.customThemeColor,
    required this.fontSizeOption,
    this.customFontScale = 1.0,
    required this.followSystemFontSize,
    this.todoSortField = TodoSortField.manual,
    this.todoSortDirection = SortDirection.asc,
    this.defaultTodoPriority = TodoPriority.normal,
    this.aggregateCompletedTodos = false,
    this.autoRemoveTrailingPeriod = false,
    this.trashAutoPurgeInterval = TrashAutoPurgeInterval.sevenDays,
    this.languageCode = 'zh_CN',
    this.notificationMode = NotificationMode.none,
  });

  /// Default settings
  factory SettingsState.initial() {
    return SettingsState(
      currentModelId: 'auto',
      autoModelSelect: true,
      themeMode: ThemeModeOption.system,
      customThemeColor: null,
      fontSizeOption: FontSizeOption.medium,
      customFontScale: 1.0,
      followSystemFontSize: false,
      todoSortField: TodoSortField.manual,
      todoSortDirection: SortDirection.asc,
      defaultTodoPriority: TodoPriority.normal,
      aggregateCompletedTodos: false,
      autoRemoveTrailingPeriod: false,
      trashAutoPurgeInterval: TrashAutoPurgeInterval.sevenDays,
      languageCode: 'zh_CN',
      notificationMode: NotificationMode.none,
    );
  }

  /// Copy with method for updating specific fields
  SettingsState copyWith({
    String? currentModelId,
    bool? autoModelSelect,
    ThemeModeOption? themeMode,
    Color? customThemeColor,
    FontSizeOption? fontSizeOption,
    double? customFontScale,
    bool? followSystemFontSize,
    TodoSortField? todoSortField,
    SortDirection? todoSortDirection,
    TodoPriority? defaultTodoPriority,
    bool? aggregateCompletedTodos,
    bool? autoRemoveTrailingPeriod,
    TrashAutoPurgeInterval? trashAutoPurgeInterval,
    String? languageCode,
    NotificationMode? notificationMode,
  }) {
    return SettingsState(
      currentModelId: currentModelId ?? this.currentModelId,
      autoModelSelect: autoModelSelect ?? this.autoModelSelect,
      themeMode: themeMode ?? this.themeMode,
      customThemeColor: customThemeColor ?? this.customThemeColor,
      fontSizeOption: fontSizeOption ?? this.fontSizeOption,
      customFontScale: customFontScale ?? this.customFontScale,
      followSystemFontSize: followSystemFontSize ?? this.followSystemFontSize,
      todoSortField: todoSortField ?? this.todoSortField,
      todoSortDirection: todoSortDirection ?? this.todoSortDirection,
      defaultTodoPriority: defaultTodoPriority ?? this.defaultTodoPriority,
      aggregateCompletedTodos:
          aggregateCompletedTodos ?? this.aggregateCompletedTodos,
      autoRemoveTrailingPeriod:
          autoRemoveTrailingPeriod ?? this.autoRemoveTrailingPeriod,
      trashAutoPurgeInterval:
          trashAutoPurgeInterval ?? this.trashAutoPurgeInterval,
      languageCode: languageCode ?? this.languageCode,
      notificationMode: notificationMode ?? this.notificationMode,
    );
  }
}
