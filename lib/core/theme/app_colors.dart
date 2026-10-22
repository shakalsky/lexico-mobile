import 'package:flutter/material.dart';

/// Palette lifted from the Léxico design canvas.
abstract final class AppColors {
  static const Color canvas = Color(0xFF08090A);
  static const Color shell = Color(0xFF0B0D0C);
  static const Color surface = Color(0xFF111514);
  static const Color surfaceRaised = Color(0xFF141817);
  static const Color track = Color(0xFF181C1A);

  static const Color cardTop = Color(0xFF181D1B);
  static const Color cardBottom = Color(0xFF121615);
  static const Color cardBackTop = Color(0xFF12211C);
  static const Color cardBackBottom = Color(0xFF0F1614);

  static const Color accent = Color(0xFF0CA678);
  static const Color accentBright = Color(0xFF3FDBA4);
  static const Color accentHover = Color(0xFF2FD39B);
  static const Color onAccent = Color(0xFF04150E);
  static const Color accentMuted = Color(0xFF4E7A6B);
  static const Color accentDim = Color(0xFF5F8C7A);

  static const Color textPrimary = Color(0xFFEDEFED);
  static const Color textBright = Color(0xFFF3F5F3);
  static const Color textOnBack = Color(0xFFEFF7F3);
  static const Color textSecondary = Color(0xFF9AA29D);
  static const Color textSecondaryBack = Color(0xFF9AB0A7);
  static const Color textMuted = Color(0xFF7C8480);
  static const Color textFaint = Color(0xFF5F6863);
  static const Color textGhost = Color(0xFF4E5652);
  static const Color textGhostBack = Color(0xFF41645A);

  static const Color caution = Color(0xFFE8B661);
  static const Color danger = Color(0xFFFF8A8A);
  static const Color dangerBright = Color(0xFFFF9E9E);

  static const Color hairline = Color(0x14FFFFFF);
  static const Color hairlineStrong = Color(0x1FFFFFFF);

  static const LinearGradient cardFrontGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [cardTop, cardBottom],
  );

  static const LinearGradient cardBackGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [cardBackTop, cardBackBottom],
  );

  static const LinearGradient xpGradient = LinearGradient(
    colors: [accent, accentBright],
  );
}
