import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/core/theme/app_typography.dart';
import 'package:lexico/features/vocabulary/domain/entities/session_summary.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';
import 'package:lexico/features/vocabulary/presentation/bloc/study/study_bloc.dart';
import 'package:lexico/features/vocabulary/presentation/widgets/primary_button.dart';

/// The end-of-session screen: score, XP, streak and the words to revisit.
class SummaryView extends StatelessWidget {
  const SummaryView({required this.summary, super.key});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(26, 32, 26, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Session complete', style: AppTypography.eyebrow()),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${summary.accuracyPercent}%',
              style: AppTypography.display(88).copyWith(height: 0.9),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${summary.correctCount} of ${summary.reviewedCount} right',
                style: AppTypography.body(14, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: _SummaryTile(
                value: '+${summary.xpEarned}',
                label: 'XP earned',
                valueColor: AppColors.accentBright,
                background: const Color(0x1A0CA678),
                borderColor: const Color(0x3D0CA678),
                labelColor: AppColors.accentDim,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryTile(
                value: '${summary.streakDays}',
                label: 'day streak',
                valueColor: AppColors.textPrimary,
                background: AppColors.surface,
                borderColor: AppColors.hairline,
                labelColor: AppColors.textFaint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        if (summary.missedWords.isNotEmpty) ...[
          Text(
            'Back tomorrow',
            style: AppTypography.eyebrow(size: 11, tracking: 1.54),
          ),
          const SizedBox(height: 14),
          Expanded(child: _MissedList(words: summary.missedWords)),
        ] else ...[
          Text(
            'Nothing to revisit',
            style: AppTypography.eyebrow(size: 11, tracking: 1.54),
          ),
          const SizedBox(height: 14),
          Text(
            'Every card in this round landed. Well done.',
            style: AppTypography.body(14, color: AppColors.textMuted),
          ),
          const Spacer(),
        ],
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Another round',
          height: 56,
          onPressed: () =>
              context.read<StudyBloc>().add(const StudySessionRequested()),
        ),
        const SizedBox(height: 10),
        GhostButton(
          label: 'Done for today',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    ),
  );
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.value,
    required this.label,
    required this.valueColor,
    required this.background,
    required this.borderColor,
    required this.labelColor,
  });

  final String value;
  final String label;
  final Color valueColor;
  final Color background;
  final Color borderColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: borderColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTypography.display(30, color: valueColor)),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTypography.body(
            11.5,
            color: labelColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
  );
}

class _MissedList extends StatelessWidget {
  const _MissedList({required this.words});

  final List<VocabWord> words;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: EdgeInsets.zero,
    itemCount: words.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) => _MissedTile(word: words[index]),
  );
}

/// A "back tomorrow" row. When the word or its answer is cut off, tapping
/// expands it into a column showing the full text; tapping again collapses it.
class _MissedTile extends StatefulWidget {
  const _MissedTile({required this.word});

  final VocabWord word;

  @override
  State<_MissedTile> createState() => _MissedTileState();
}

class _MissedTileState extends State<_MissedTile> {
  static const _padding = EdgeInsets.symmetric(horizontal: 16, vertical: 14);
  static const _gap = 12.0;

  bool _expanded = false;

  bool _overflows(String text, TextStyle style, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    final exceeded = painter.didExceedMaxLines;
    painter.dispose();
    return exceeded;
  }

  @override
  Widget build(BuildContext context) {
    final questionStyle = AppTypography.word(
      16.5,
      color: AppColors.textPrimary,
    );
    final answerStyle = AppTypography.body(13.5, color: AppColors.textMuted);

    return LayoutBuilder(
      builder: (context, constraints) {
        // In the collapsed row each text gets at most half the inner width.
        final half = (constraints.maxWidth - _padding.horizontal - _gap) / 2;
        final truncated =
            _overflows(widget.word.question, questionStyle, half) ||
            _overflows(widget.word.answer, answerStyle, half);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: truncated || _expanded
              ? () => setState(() => _expanded = !_expanded)
              : null,
          child: Container(
            padding: _padding,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.hairline),
            ),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.word.question, style: questionStyle),
                        const SizedBox(height: 6),
                        Text(widget.word.answer, style: answerStyle),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.word.question,
                            style: questionStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: _gap),
                        Flexible(
                          child: Text(
                            widget.word.answer,
                            style: answerStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
