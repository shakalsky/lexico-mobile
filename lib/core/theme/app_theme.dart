import 'package:flutter/material.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/core/theme/app_typography.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.accentBright,
      surface: AppColors.shell,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.shell,
      fontFamily: AppTypography.sans,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textTheme: TextTheme(
        displayLarge: AppTypography.display(44),
        headlineMedium: AppTypography.display(26),
        bodyLarge: AppTypography.body(16),
        bodyMedium: AppTypography.body(13.5),
        labelSmall: AppTypography.eyebrow(),
      ),
    );
  }
}
