import 'package:flutter/material.dart';
import '../models/settings_state.dart';

/// Service for managing app-wide settings
class SettingsService {
  /// Resolve the Material theme mode.
  ThemeMode getThemeMode(SettingsState settings) {
    switch (settings.themeMode) {
      case ThemeModeOption.dark:
        return ThemeMode.dark;
      case ThemeModeOption.system:
        return ThemeMode.system;
      case ThemeModeOption.light:
      case ThemeModeOption.custom:
        return ThemeMode.light;
    }
  }

  /// Apply theme based on current settings.
  ThemeData getThemeData(SettingsState settings) {
    return _buildThemeData(settings, Brightness.light);
  }

  /// Build the dark theme variant.
  ThemeData getDarkThemeData(SettingsState settings) {
    return _buildThemeData(settings, Brightness.dark);
  }

  /// Resolve the effective text scale factor, optionally using the system value.
  double getEffectiveTextScaleFactor(
    SettingsState settings, {
    double systemScale = 1.0,
  }) {
    if (settings.followSystemFontSize) {
      return systemScale;
    }

    switch (settings.fontSizeOption) {
      case FontSizeOption.small:
        return 0.85;
      case FontSizeOption.medium:
        return 1.0;
      case FontSizeOption.large:
        return 1.2;
      case FontSizeOption.custom:
        return settings.customFontScale;
    }
  }

  ThemeData _buildThemeData(SettingsState settings, Brightness brightness) {
    final primaryColor = _getPrimaryColor(settings);
    final fontScale = getEffectiveTextScaleFactor(settings);
    final textTheme = _getTextTheme(brightness);
    final textColor =
        brightness == Brightness.dark ? Colors.white : Colors.black;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primarySwatch: _createMaterialColor(primaryColor),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
      ).copyWith(
        surface: brightness == Brightness.dark
            ? const Color(0xFF121212)
            : Colors.white,
      ),
      textTheme: textTheme
          .apply(bodyColor: textColor, displayColor: textColor)
          .copyWith(
            displayLarge: _scaledTextStyle(textTheme.displayLarge, fontScale),
            displayMedium: _scaledTextStyle(textTheme.displayMedium, fontScale),
            displaySmall: _scaledTextStyle(textTheme.displaySmall, fontScale),
            headlineLarge: _scaledTextStyle(textTheme.headlineLarge, fontScale),
            headlineMedium:
                _scaledTextStyle(textTheme.headlineMedium, fontScale),
            headlineSmall: _scaledTextStyle(textTheme.headlineSmall, fontScale),
            titleLarge: _scaledTextStyle(textTheme.titleLarge, fontScale),
            titleMedium: _scaledTextStyle(textTheme.titleMedium, fontScale),
            titleSmall: _scaledTextStyle(textTheme.titleSmall, fontScale),
            bodyLarge: _scaledTextStyle(textTheme.bodyLarge, fontScale),
            bodyMedium: _scaledTextStyle(textTheme.bodyMedium, fontScale),
            bodySmall: _scaledTextStyle(textTheme.bodySmall, fontScale),
            labelLarge: _scaledTextStyle(textTheme.labelLarge, fontScale),
            labelMedium: _scaledTextStyle(textTheme.labelMedium, fontScale),
            labelSmall: _scaledTextStyle(textTheme.labelSmall, fontScale),
          ),
      primaryTextTheme: textTheme,
    );
  }

  /// Get the primary color based on settings
  Color _getPrimaryColor(SettingsState settings) {
    if (settings.themeMode == ThemeModeOption.custom &&
        settings.customThemeColor != null) {
      return settings.customThemeColor!;
    }

    return Colors.blue;
  }

  /// Get base text theme
  TextTheme _getTextTheme(Brightness brightness) {
    return brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;
  }

  /// Scale text style by factor
  TextStyle? _scaledTextStyle(TextStyle? style, double scale) {
    if (style == null) return null;
    return style.copyWith(
      fontSize: (style.fontSize ?? 14) * scale,
    );
  }

  /// Helper to create MaterialColor from Color
  MaterialColor _createMaterialColor(Color color) {
    List strengths = <double>[.05];
    Map<int, Color> swatch = {};
    final int r = (color.r * 255).round();
    final int g = (color.g * 255).round();
    final int b = (color.b * 255).round();

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.toARGB32(), swatch);
  }
}
