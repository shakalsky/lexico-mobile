import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexico/app/injection.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/core/theme/app_typography.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_grade.dart';
import 'package:lexico/features/vocabulary/presentation/bloc/study/study_bloc.dart';
import 'package:lexico/features/vocabulary/presentation/pages/summary_view.dart';
import 'package:lexico/features/vocabulary/presentation/widgets/primary_button.dart';
import 'package:lexico/features/vocabulary/presentation/widgets/session_toast.dart';
import 'package:lexico/features/vocabulary/presentation/widgets/swipe_deck.dart';

/// Hosts one sitting: the swipe stack, then its summary.
class StudyPage extends StatelessWidget {
  const StudyPage({super.key});

  static Route<void> route() => MaterialPageRoute(
    builder: (_) => BlocProvider(
      create: (_) => sl<StudyBloc>()..add(const StudySessionRequested()),
      child: const StudyPage(),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.shell,
    body: SafeArea(
      child: BlocConsumer<StudyBloc, StudyState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == StudyStatus.abandoned) {
            Navigator.of(context).maybePop();
          }
        },
        builder: (context, state) => switch (state.status) {
          StudyStatus.initial || StudyStatus.loading => const _StudyLoading(),
          StudyStatus.studying ||
          StudyStatus.abandoned => _StudyStack(state: state),
          StudyStatus.finished => SummaryView(summary: state.summary!),
          StudyStatus.failure => _StudyError(message: state.message),
        },
      ),
    ),
  );
}

class _StudyLoading extends StatelessWidget {
  const _StudyLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      width: 26,
      height: 26,
      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
    ),
  );
}

class _StudyError extends StatelessWidget {
  const _StudyError({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 26),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Session paused',
          style: AppTypography.display(30),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          message ?? 'Something interrupted the session.',
          textAlign: TextAlign.center,
          style: AppTypography.body(14, color: AppColors.textMuted),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: 'Try again',
          onPressed: () =>
              context.read<StudyBloc>().add(const StudySessionRequested()),
        ),
        GhostButton(
          label: 'Back home',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    ),
  );
}

class _StudyStack extends StatefulWidget {
  const _StudyStack({required this.state});

  final StudyState state;

  @override
  State<_StudyStack> createState() => _StudyStackState();
}

class _StudyStackState extends State<_StudyStack> {
  final SwipeDeckController _deck = SwipeDeckController();

  void _answer(ReviewGrade grade) =>
      context.read<StudyBloc>().add(StudyAnswerSubmitted(grade));

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 26),
      child: Stack(
        children: [
          Column(
            children: [
              _SessionHeader(
                progress: state.progress,
                positionLabel: '${state.position}/${state.total}',
                onQuit: () =>
                    context.read<StudyBloc>().add(const StudySessionQuit()),
              ),
              const SizedBox(height: 26),
              Expanded(
                child: SwipeDeck(
                  controller: _deck,
                  cards: state.visibleCards,
                  isRevealed: state.isRevealed,
                  onFlip: () =>
                      context.read<StudyBloc>().add(const StudyCardFlipped()),
                  onAnswered: _answer,
                ),
              ),
              const SizedBox(height: 20),
              _AnswerButtons(
                onReview: () => _deck.swipe(ReviewGrade.needsReview),
                onKnewIt: () => _deck.swipe(ReviewGrade.knewIt),
              ),
            ],
          ),
          // Floats over the answer buttons, so the deck never changes size.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: SessionToast(
                toast: state.toast,
                messageLift: 8,
                showMissPictures: state.showMissPictures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.progress,
    required this.positionLabel,
    required this.onQuit,
  });

  final double progress;
  final String positionLabel;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Semantics(
        button: true,
        label: 'End session',
        child: GestureDetector(
          key: const Key('session-quit'),
          onTap: onQuit,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surfaceRaised,
              shape: BoxShape.circle,
            ),
            child: Text(
              '✕',
              style: AppTypography.body(16, color: AppColors.textMuted),
            ),
          ),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 5,
            color: AppColors.track,
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (context, width, child) =>
                  FractionallySizedBox(widthFactor: width, child: child),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(color: Color(0x990CA678), blurRadius: 14),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 14),
      Text(
        positionLabel,
        style: AppTypography.body(
          12.5,
          color: AppColors.textMuted,
          weight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _AnswerButtons extends StatelessWidget {
  const _AnswerButtons({required this.onReview, required this.onKnewIt});

  final VoidCallback onReview;
  final VoidCallback onKnewIt;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _CircleAction(
        key: const Key('answer-needs-review'),
        label: '✕',
        semanticLabel: 'Needs review',
        color: AppColors.danger,
        borderColor: const Color(0x4DFF5A5A),
        onTap: onReview,
      ),
      const SizedBox(width: 18),
      SizedBox(
        width: 96,
        child: Text(
          'review\nor knew it',
          textAlign: TextAlign.center,
          style: AppTypography.body(
            12,
            color: AppColors.textGhost,
            height: 1.35,
          ),
        ),
      ),
      const SizedBox(width: 18),
      _CircleAction(
        key: const Key('answer-knew-it'),
        label: '✓',
        semanticLabel: 'Knew it',
        color: AppColors.accentBright,
        borderColor: const Color(0x590CA678),
        onTap: onKnewIt,
      ),
    ],
  );
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.label,
    required this.semanticLabel,
    required this.color,
    required this.borderColor,
    required this.onTap,
    super.key,
  });

  final String label;
  final String semanticLabel;
  final Color color;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 62,
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor),
        ),
        child: Text(label, style: AppTypography.body(22, color: color)),
      ),
    ),
  );
}
