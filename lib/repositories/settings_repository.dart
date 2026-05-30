import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart'; // For Color
import '../models/settings_state.dart';
import '../models/todo_priority.dart';
import '../models/todo_sort.dart';
import '../models/notification_mode.dart';

/// Repository for managing settings persistence
class SettingsRepository {
  static const String _currentModelIdKey = 'current_model_id';
  static const String _autoModelSelectKey = 'auto_model_select';
  static const String _themeModeKey = 'theme_mode';
  static const String _customThemeColorKey = 'custom_theme_color';
  static const String _fontSizeOptionKey = 'font_size_option';
  static const String _customFontScaleKey = 'custom_font_scale';
  static const String _followSystemFontSizeKey = 'follow_system_font_size';
  static const String _todoSortFieldKey = 'todo_sort_field';
  static const String _todoSortDirectionKey = 'todo_sort_direction';
  static const String _defaultTodoPriorityKey = 'default_todo_priority';
  static const String _aggregateCompletedTodosKey = 'aggregate_completed_todos';
  static const String _autoRemoveTrailingPeriodKey =
      'auto_remove_trailing_period';
  static const String _trashAutoPurgeIntervalKey = 'trash_auto_purge_interval';
  static const String _languageCodeKey = 'language_code';
  static const String _notificationModeKey = 'notification_mode';

  /// Load settings from shared preferences
  Future<SettingsState> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Get string values from preferences
    String themeModeStr = prefs.getString(_themeModeKey) ?? 'system';
    String fontSizeOptionStr = prefs.getString(_fontSizeOptionKey) ?? 'medium';

    final todoSortFieldStr = prefs.getString(_todoSortFieldKey) ?? 'manual';
    final todoSortDirectionStr =
        prefs.getString(_todoSortDirectionKey) ?? 'asc';

    return SettingsState(
      currentModelId: prefs.getString(_currentModelIdKey) ?? 'auto',
      autoModelSelect: prefs.getBool(_autoModelSelectKey) ?? true,
      themeMode: ThemeModeOption.values.firstWhere(
        (e) => e.toString().split('.')[1] == themeModeStr,
        orElse: () => ThemeModeOption.system,
      ),
      customThemeColor: prefs.getInt(_customThemeColorKey) != null
          ? Color(prefs.getInt(_customThemeColorKey)!)
          : null,
      fontSizeOption: FontSizeOption.values.firstWhere(
        (e) => e.toString().split('.')[1] == fontSizeOptionStr,
        orElse: () => FontSizeOption.medium,
      ),
      customFontScale: prefs.getDouble(_customFontScaleKey) ?? 1.0,
      followSystemFontSize: prefs.getBool(_followSystemFontSizeKey) ?? false,
      todoSortField: TodoSortField.values.firstWhere(
        (e) => e.toString().split('.')[1] == todoSortFieldStr,
        orElse: () => TodoSortField.manual,
      ),
      todoSortDirection: SortDirection.values.firstWhere(
        (e) => e.toString().split('.')[1] == todoSortDirectionStr,
        orElse: () => SortDirection.asc,
      ),
      defaultTodoPriority: TodoPriority.values.firstWhere(
        (e) =>
            e.toString().split('.')[1] ==
            (prefs.getString(_defaultTodoPriorityKey) ?? 'normal'),
        orElse: () => TodoPriority.normal,
      ),
      aggregateCompletedTodos:
          prefs.getBool(_aggregateCompletedTodosKey) ?? false,
      autoRemoveTrailingPeriod:
          prefs.getBool(_autoRemoveTrailingPeriodKey) ?? false,
      trashAutoPurgeInterval: TrashAutoPurgeInterval.values.firstWhere(
        (e) =>
            e.toString().split('.')[1] ==
            (prefs.getString(_trashAutoPurgeIntervalKey) ?? 'sevenDays'),
        orElse: () => TrashAutoPurgeInterval.sevenDays,
      ),
      languageCode: prefs.getString(_languageCodeKey) ?? 'zh_CN',
      notificationMode: NotificationModeExtension.fromString(
          prefs.getString(_notificationModeKey) ?? 'none'),
    );
  }

  /// Save settings to shared preferences
  Future<bool> saveSettings(SettingsState settings) async {
    final prefs = await SharedPreferences.getInstance();

    bool result = await prefs.setString(
            _currentModelIdKey, settings.currentModelId) &&
        await prefs.setBool(_autoModelSelectKey, settings.autoModelSelect) &&
        await prefs.setString(
            _themeModeKey, settings.themeMode.toString().split('.')[1]) &&
        (settings.customThemeColor != null
            ? await prefs.setInt(
                _customThemeColorKey, settings.customThemeColor!.toARGB32())
            : await prefs.remove(_customThemeColorKey)) &&
        await prefs.setString(_fontSizeOptionKey,
            settings.fontSizeOption.toString().split('.')[1]) &&
        await prefs.setDouble(_customFontScaleKey, settings.customFontScale) &&
        await prefs.setBool(
            _followSystemFontSizeKey, settings.followSystemFontSize);

    // Save sort preferences
    result = result &&
        await prefs.setString(
            _todoSortFieldKey, settings.todoSortField.toString().split('.')[1]);
    result = result &&
        await prefs.setString(_todoSortDirectionKey,
            settings.todoSortDirection.toString().split('.')[1]);

    // Save default todo priority
    result = result &&
        await prefs.setString(_defaultTodoPriorityKey,
            settings.defaultTodoPriority.toString().split('.')[1]);

    result = result &&
        await prefs.setBool(
            _aggregateCompletedTodosKey, settings.aggregateCompletedTodos);

    result = result &&
        await prefs.setBool(
            _autoRemoveTrailingPeriodKey, settings.autoRemoveTrailingPeriod);

    result = result &&
        await prefs.setString(_trashAutoPurgeIntervalKey,
            settings.trashAutoPurgeInterval.toString().split('.')[1]);

    result = result &&
        await prefs.setString(_languageCodeKey, settings.languageCode);

    return result;
  }

  /// Save notification mode
  Future<bool> saveNotificationMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_notificationModeKey, mode);
  }

  /// Load notification mode
  Future<String> loadNotificationMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_notificationModeKey) ?? 'none';
  }
}
