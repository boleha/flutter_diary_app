import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ColorScheme _colorScheme(AppColors colors, Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: colors.actionPrimaryBackground,
      brightness: brightness,
    ).copyWith(
      primary: colors.actionPrimaryBackground,
      onPrimary: colors.actionPrimaryForeground,
      primaryContainer: colors.calendarControlBackground,
      onPrimaryContainer: colors.calendarControlText,
      secondary: colors.actionPrimaryBackground,
      onSecondary: colors.actionPrimaryForeground,
      secondaryContainer: colors.surfaceSubtle,
      onSecondaryContainer: colors.textPrimary,
      tertiary: colors.actionPrimaryBackground,
      onTertiary: colors.actionPrimaryForeground,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      outline: colors.outlineStrong,
      outlineVariant: colors.outline,
      error: colors.danger,
      onError: colors.actionPrimaryForeground,
      surfaceContainerLowest: colors.background,
      surfaceContainerLow: colors.surface,
      surfaceContainer: colors.surfaceMuted,
      surfaceContainerHigh: colors.surfaceSubtle,
      surfaceContainerHighest: colors.surfaceCard,
      surfaceTint: Colors.transparent,
    );
  }

  static ThemeData buildLightTheme() {
    final colors = AppColors.light;
    return ThemeData(
      scaffoldBackgroundColor: colors.background,
      colorScheme: _colorScheme(colors, Brightness.light),
      useMaterial3: true,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 4,
        shadowColor: colors.shadowSoft,
        surfaceTintColor: Colors.transparent,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surfaceMuted,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: colors.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceSubtle,
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
        labelStyle: TextStyle(color: colors.textMuted, fontSize: 14),
        floatingLabelStyle: TextStyle(color: colors.textMuted, fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colors.actionPrimaryBackground,
            width: 1,
          ),
        ),
      ),
    );
  }

  static ThemeData buildDarkTheme() {
    final colors = AppColors.dark;
    return ThemeData(
      scaffoldBackgroundColor: colors.background,
      colorScheme: _colorScheme(colors, Brightness.dark),
      useMaterial3: true,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 4,
        shadowColor: colors.shadowSoft,
        surfaceTintColor: Colors.transparent,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: colors.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceSubtle,
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
        labelStyle: TextStyle(color: colors.textMuted, fontSize: 14),
        floatingLabelStyle: TextStyle(color: colors.textMuted, fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outlineStrong, width: 1),
        ),
      ),
    );
  }
}
