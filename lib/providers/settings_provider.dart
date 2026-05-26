import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/settings_repository.dart';
import '../models/settings_state.dart';

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
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _repository.saveSettings(state);
    } catch (e) {
      debugPrint('Error saving settings: $e');
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
  }
}

/// Provider for accessing settings
final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});
