import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/core/theme/app_typography.dart';
import 'package:lexico/features/vocabulary/domain/entities/card_level.dart';
import 'package:lexico/features/vocabulary/domain/entities/study_rules.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';
import 'package:lexico/features/vocabulary/presentation/widgets/card_level_tile.dart';

/// A card that turns over to reveal the answer.
///
/// Both faces are always built; the rotation angle decides which one is
/// painted, so there is no flicker mid-turn.
class WordCard extends StatelessWidget {
  const WordCard({
    required this.word,
    required this.level,
    required this.isRevealed,
    super.key,
  });

  final VocabWord word;
  final CardLevel level;
  final bool isRevealed;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: isRevealed ? math.pi : 0),
    duration: const Duration(milliseconds: 500),
    curve: Curves.easeInOutCubic,
    builder: (context, angle, _) {
      final showBack = angle > math.pi / 2;
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0009)
          ..rotateY(angle),
        child: showBack
            // Un-mirror the back face.
            ? Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..rotateY(math.pi),
                child: _CardBack(word: word, level: level),
              )
            : _CardFront(word: word, level: level),
      );
    },
  );
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.gradient,
    required this.borderColor,
    required this.child,
  });

  final Gradient gradient;
  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
    decoration: BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: borderColor),
      boxShadow: const [
        BoxShadow(
          color: Color(0x8C000000),
          blurRadius: 60,
          offset: Offset(0, 30),
        ),
      ],
    ),
    child: child,
  );
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.word, required this.level});

  final VocabWord word;
  final CardLevel level;

  @override
  Widget build(BuildContext context) => _CardShell(
    gradient: AppColors.cardFrontGradient,
    borderColor: AppColors.hairlineStrong,
    child: _CardFace(
      eyebrow: word.isSentence ? 'Sentence' : StudyRules.courseLabel,
      eyebrowColor: AppColors.textGhost,
      level: level,
      headline: Text(
        word.question,
        style: AppTypography.display(word.isSentence ? 32 : 46),
      ),
      detail: word.questionDetail,
      detailColor: AppColors.textSecondary,
      dividerColor: AppColors.hairlineStrong,
      hint: const _FlipHint(
        label: 'tap to turn over',
        color: AppColors.textGhost,
        borderColor: Color(0xFF3A423E),
      ),
    ),
  );
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.word, required this.level});

  final VocabWord word;
  final CardLevel level;

  @override
  Widget build(BuildContext context) => _CardShell(
    gradient: AppColors.cardBackGradient,
    borderColor: const Color(0x380CA678),
    child: _CardFace(
      eyebrow: 'English',
      eyebrowColor: AppColors.textGhost,
      level: level,
      headline: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            word.answer,
            style: AppTypography.display(
              word.answerShort == null ? 30 : 42,
              color: AppColors.textOnBack,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            word.question,
            style: AppTypography.body(13, color: AppColors.accentMuted),
          ),
        ],
      ),
      detail: word.answerDetail,
      detailColor: AppColors.textSecondaryBack,
      dividerColor: const Color(0x290CA678),
      hint: const _FlipHint(
        label: 'tap to turn back',
        color: AppColors.textGhostBack,
        borderColor: Color(0xFF2C4A40),
      ),
    ),
  );
}

/// The layout both faces share: eyebrow and difficulty badge, headline, then
/// the example sentence under a divider. With no [detail] the headline gets
/// the space instead.
class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.eyebrow,
    required this.eyebrowColor,
    required this.level,
    required this.headline,
    required this.detail,
    required this.detailColor,
    required this.dividerColor,
    required this.hint,
  });

  final String eyebrow;
  final Color eyebrowColor;
  final CardLevel level;
  final Widget headline;
  final String? detail;
  final Color detailColor;
  final Color dividerColor;
  final Widget hint;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                eyebrow.toUpperCase(),
                style: AppTypography.body(
                  11,
                  color: eyebrowColor,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            CardLevelTile(level: level),
          ],
        ),
        if (detail == null)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(child: headline),
            ),
          )
        else ...[
          const SizedBox(height: 38),
          headline,
          const SizedBox(height: 26),
          Divider(height: 1, thickness: 1, color: dividerColor),
          Expanded(
            child: Center(
              child: Text(
                detail,
                style: AppTypography.body(19, color: detailColor, height: 1.5),
              ),
            ),
          ),
        ],
        hint,
      ],
    );
  }
}

class _FlipHint extends StatelessWidget {
  const _FlipHint({
    required this.label,
    required this.color,
    required this.borderColor,
  });

  final String label;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 16,
        height: 16,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor),
        ),
        child: Text('↻', style: AppTypography.body(9, color: color)),
      ),
      const SizedBox(width: 8),
      Text(
        label.toUpperCase(),
        style: AppTypography.body(11.5, color: color, letterSpacing: 1.15),
      ),
    ],
  );
}
