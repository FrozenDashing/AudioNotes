import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' as foundation;
import '../repositories/settings_repository.dart';
import '../models/settings_state.dart';
import '../models/todo_priority.dart';
import '../models/todo_sort.dart';
import '../models/todo_query_options.dart';
import '../models/notification_mode.dart';
import 'app_providers.dart';

/// Provider for accessing settings repository
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

/// Notifier for managing settings state
class SettingsNotifier extends Notifier<SettingsState> {
  late final SettingsRepository _repository;

  @override
  SettingsState build() {
    _repository = ref.read(settingsRepositoryProvider);
    final initial = SettingsState.initial();
    state = initial;
    unawaited(_loadSettings());
    return initial;
  }

  Future<void> _loadSettings() async {
    try {
      final loaded = await _repository.loadSettings();
      if (!ref.mounted) {
        return;
      }
      state = loaded;
    } catch (e) {
      if (ref.mounted) {
        state = SettingsState.initial();
      }
      foundation.debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _repository.saveSettings(state);
    } catch (e) {
      foundation.debugPrint('Error saving settings: $e');
    }
  }

  /// Update current model ID
  Future<void> setCurrentModelId(String modelId) async {
    state = state.copyWith(currentModelId: modelId);
    await _saveSettings();
  }

  /// Toggle auto model selection
  Future<void> setAutoModelSelect(bool enabled) async {
    state = state.copyWith(autoModelSelect: enabled);
    await _saveSettings();
  }

  /// Set theme mode
  Future<void> setThemeMode(ThemeModeOption mode) async {
    state = state.copyWith(themeMode: mode);
    await _saveSettings();
  }

  /// Set todo list sort field preference
  Future<void> setTodoSortField(TodoSortField field) async {
    state = state.copyWith(todoSortField: field);
    await _saveSettings();
    // Apply immediately to list
    await ref.read(todoListProvider.notifier).setQueryOptions(
          TodoQueryOptions(
            sortField: state.todoSortField,
            direction: state.todoSortDirection,
          ),
        );
  }

  /// Set todo list sort direction preference
  Future<void> setTodoSortDirection(SortDirection direction) async {
    state = state.copyWith(todoSortDirection: direction);
    await _saveSettings();
    // Apply immediately to list
    await ref.read(todoListProvider.notifier).setQueryOptions(
          TodoQueryOptions(
            sortField: state.todoSortField,
            direction: state.todoSortDirection,
          ),
        );
  }

  /// Set custom theme color
  Future<void> setCustomThemeColor(Color? color) async {
    state = state.copyWith(customThemeColor: color);
    await _saveSettings();
  }

  /// Set font size option
  Future<void> setFontSizeOption(FontSizeOption option) async {
    state = state.copyWith(fontSizeOption: option);
    await _saveSettings();
  }

  /// Set custom font scale
  Future<void> setCustomFontScale(double scale) async {
    state = state.copyWith(customFontScale: scale);
    await _saveSettings();
  }

  /// Set whether to follow system font size
  Future<void> setFollowSystemFontSize(bool follow) async {
    state = state.copyWith(followSystemFontSize: follow);
    await _saveSettings();
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    state = SettingsState.initial();
    await _saveSettings();
    await ref.read(todoListProvider.notifier).setQueryOptions(
          TodoQueryOptions(
            sortField: state.todoSortField,
            direction: state.todoSortDirection,
          ),
        );
  }

  /// Set default priority for newly created todos
  Future<void> setDefaultTodoPriority(TodoPriority p) async {
    state = state.copyWith(defaultTodoPriority: p);
    await _saveSettings();
  }

  /// Toggle whether completed todos are aggregated into one group
  Future<void> setAggregateCompletedTodos(bool enabled) async {
    state = state.copyWith(aggregateCompletedTodos: enabled);
    await _saveSettings();
    await ref.read(todoListProvider.notifier).loadTodos();
  }

  /// Toggle auto-removal of trailing sentence-ending period in recognition text
  Future<void> setAutoRemoveTrailingPeriod(bool enabled) async {
    state = state.copyWith(autoRemoveTrailingPeriod: enabled);
    await _saveSettings();
  }

  /// Set trash auto-purge retention interval.
  Future<void> setTrashAutoPurgeInterval(
      TrashAutoPurgeInterval interval) async {
    state = state.copyWith(trashAutoPurgeInterval: interval);
    await _saveSettings();
  }

  /// Set app language code used by i18n
  Future<void> setLanguageCode(String languageCode) async {
    state = state.copyWith(languageCode: languageCode);
    await _saveSettings();
  }

  /// Set notification mode for reminders
  Future<void> setNotificationMode(NotificationMode mode) async {
    state = state.copyWith(notificationMode: mode);
    await ref.read(reminderServiceProvider).setNotificationMode(mode);
  }

  /// Enable or disable quick text todo creation
  Future<void> setEnableQuickTextTodo(bool enabled) async {
    state = state.copyWith(enableQuickTextTodo: enabled);
    await _saveSettings();
  }
}

/// Provider for accessing settings
final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});
