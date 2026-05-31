import 'package:flutter/material.dart';
import '../models/settings_state.dart';
import '../themes/todo_priority_palette.dart';

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

    final cs = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
    ).copyWith(
      surface: brightness == Brightness.dark
          ? const Color(0xFF121212)
          : Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      // Priority palette extension and checkbox styling
      extensions: <ThemeExtension<dynamic>>[
        TodoPriorityPalette(
          urgent: brightness == Brightness.dark
              ? const Color(0xFFFF6B6B)
              : const Color(0xFFE5484D),
          high: brightness == Brightness.dark
              ? const Color(0xFFFFB86B)
              : const Color(0xFFF97316),
          // Use fixed example colors (do not follow seed/primary color)
          normal: brightness == Brightness.dark
              ? const Color(0xFF7AB8FF)
              : const Color(0xFF64748B), // Slate 500
          low: brightness == Brightness.dark
              ? const Color(0xFF0F172A)
              : const Color(0xFFF1F5F9), // near-background slate
        ),
      ],
      primarySwatch: _createMaterialColor(primaryColor),
      colorScheme: cs,
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
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          if (selected) {
            // slightly darker than primary
            return Color.alphaBlend(
              Colors.black.withAlpha((0.12 * 255).round()),
              cs.primary,
            ).withAlpha((0.95 * 255).round());
          }
          return cs.outlineVariant;
        }),
        checkColor: WidgetStateProperty.all(cs.onPrimary),
      ),
    );
  }

  /// Get the primary color based on settings
  Color _getPrimaryColor(SettingsState settings) {
    if (settings.themeMode == ThemeModeOption.custom &&
        settings.customThemeColor != null) {
      return settings.customThemeColor!;
    }

    // Default theme color: keep original default (blue). The app's first-run
    // behavior may use a deep-blue sample for previews, but we do not hard-code
    // the default theme color here so settings UI remains unconstrained.
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
