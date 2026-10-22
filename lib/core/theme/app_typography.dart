import 'package:flutter/material.dart';
import 'package:lexico/core/theme/app_colors.dart';

/// Manrope is shipped as a variable font, so weights are applied through
/// [FontVariation] as well as [FontWeight] to keep every platform in step.
abstract final class AppTypography {
  static const String serif = 'InstrumentSerif';
  static const String sans = 'Manrope';

  static TextStyle display(double size, {Color color = AppColors.textBright}) =>
      TextStyle(
        fontFamily: serif,
        fontSize: size,
        height: 1.05,
        color: color,
        letterSpacing: 0.2,
      );

  static TextStyle displayItalic(
    double size, {
    Color color = AppColors.textMuted,
  }) => display(size, color: color).copyWith(fontStyle: FontStyle.italic);

  static TextStyle body(
    double size, {
    Color color = AppColors.textSecondary,
    FontWeight weight = FontWeight.w400,
    double? height,
    double letterSpacing = 0,
  }) => TextStyle(
    fontFamily: sans,
    fontSize: size,
    color: color,
    height: height,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
  );

  /// Small uppercase eyebrow labels ("TODAY", "SESSION COMPLETE").
  static TextStyle eyebrow({
    Color color = AppColors.textFaint,
    double size = 12,
    double tracking = 1.9,
    FontWeight weight = FontWeight.w600,
  }) => body(size, color: color, weight: weight, letterSpacing: tracking);
}
