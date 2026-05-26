import 'package:flutter/material.dart';

/// Enum for theme modes
enum ThemeModeOption { system, light, dark, custom }

/// Enum for font sizes
enum FontSizeOption { small, medium, large, custom }

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

  SettingsState({
    required this.currentModelId,
    required this.autoModelSelect,
    required this.themeMode,
    this.customThemeColor,
    required this.fontSizeOption,
    this.customFontScale = 1.0,
    required this.followSystemFontSize,
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
  }) {
    return SettingsState(
      currentModelId: currentModelId ?? this.currentModelId,
      autoModelSelect: autoModelSelect ?? this.autoModelSelect,
      themeMode: themeMode ?? this.themeMode,
      customThemeColor: customThemeColor ?? this.customThemeColor,
      fontSizeOption: fontSizeOption ?? this.fontSizeOption,
      customFontScale: customFontScale ?? this.customFontScale,
      followSystemFontSize: followSystemFontSize ?? this.followSystemFontSize,
    );
  }
}