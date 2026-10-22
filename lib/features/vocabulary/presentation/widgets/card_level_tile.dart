import 'package:flutter/material.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/core/theme/app_typography.dart';
import 'package:lexico/features/vocabulary/domain/entities/card_level.dart';

/// The small difficulty badge in the corner of a word card.
///
/// Grey for a new word, green for A, amber for B, red for C.
class CardLevelTile extends StatelessWidget {
  const CardLevelTile({required this.level, super.key});

  final CardLevel level;

  Color get _color => switch (level) {
    CardLevel.a0 => AppColors.textFaint,
    CardLevel.a1 || CardLevel.a2 => AppColors.accentBright,
    CardLevel.b1 || CardLevel.b2 => AppColors.caution,
    CardLevel.c1 || CardLevel.c2 => AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return Semantics(
      label: 'Difficulty ${level.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          level.label,
          style: AppTypography.body(
            11,
            color: color,
            weight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}
