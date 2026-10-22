import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/core/theme/app_typography.dart';
import 'package:lexico/features/vocabulary/domain/entities/learner_stats.dart';
import 'package:lexico/features/vocabulary/domain/entities/study_rules.dart';
import 'package:lexico/features/vocabulary/presentation/bloc/home/home_bloc.dart';
import 'package:lexico/features/vocabulary/presentation/pages/study_page.dart';
import 'package:lexico/features/vocabulary/presentation/widgets/primary_button.dart';
import 'package:lexico/features/vocabulary/presentation/widgets/stat_tile.dart';
import 'package:lexico/features/vocabulary/presentation/widgets/streak_pill.dart';
import 'package:lexico/features/vocabulary/presentation/widgets/xp_bar.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.shell,
    body: SafeArea(
      child: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) => switch (state.status) {
          HomeStatus.initial || HomeStatus.loading => const _HomeLoading(),
          HomeStatus.failure => _HomeError(message: state.message),
          HomeStatus.ready => _HomeReady(stats: state.stats),
        },
      ),
    ),
  );
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      width: 26,
      height: 26,
      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
    ),
  );
}

class _HomeError extends StatelessWidget {
  const _HomeError({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 26),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'The library is out of reach',
          style: AppTypography.display(30),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          message ?? 'Please try again.',
          textAlign: TextAlign.center,
          style: AppTypography.body(14, color: AppColors.textMuted),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: 'Try again',
          onPressed: () => context.read<HomeBloc>().add(const HomeStarted()),
        ),
      ],
    ),
  );
}

class _HomeReady extends StatelessWidget {
  const _HomeReady({required this.stats});

  final LearnerStats stats;

  Future<void> _openSession(BuildContext context) async {
    final homeBloc = context.read<HomeBloc>();
    await Navigator.of(context).push(StudyPage.route());
    if (!context.mounted) return;
    homeBloc.add(const HomeRefreshed());
  }

  @override
  Widget build(BuildContext context) {
    final hasWork = stats.hasWordsDue;
    final canStudy = hasWork || stats.canStudyAhead;

    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 20, 26, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('léxico', style: AppTypography.display(32)),
              StreakPill(days: stats.streakDays),
            ],
          ),
          const SizedBox(height: 52),
          Text('Today', style: AppTypography.eyebrow()),
          const SizedBox(height: 10),
          _TodayHeadline(dueCount: stats.dueCount),
          const SizedBox(height: 34),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Level ${stats.level} · ${StudyRules.courseLabel}',
                style: AppTypography.body(13, color: AppColors.textMuted),
              ),
              Text.rich(
                TextSpan(
                  text: '${stats.xpIntoLevel} ',
                  style: AppTypography.body(
                    13,
                    color: AppColors.textPrimary,
                    weight: FontWeight.w600,
                  ),
                  children: [
                    TextSpan(
                      text: '/ ${StudyRules.xpPerLevel} XP',
                      style: AppTypography.body(
                        13,
                        color: AppColors.textFaint,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          XpBar(progress: stats.levelProgress),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: StatTile(value: '${stats.knownCount}', label: 'known'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(value: '${stats.shakyCount}', label: 'shaky'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  value: '${stats.accuracyPercent}%',
                  label: 'accuracy',
                  valueColor: AppColors.accentBright,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            switch ((hasWork, canStudy)) {
              (true, _) =>
                'Turn the card to check. Swipe right if you knew it.',
              (false, true) =>
                'Nothing is due right now. Study ahead to get a head start.',
              (false, false) => 'Add a deck to start learning.',
            },
            textAlign: TextAlign.center,
            style: AppTypography.body(12.5, color: AppColors.textFaint),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: switch ((hasWork, canStudy)) {
              (true, _) => 'Start session',
              (false, true) => 'Study ahead',
              (false, false) => 'No words yet',
            },
            onPressed: canStudy ? () => _openSession(context) : null,
          ),
        ],
      ),
    );
  }
}

class _TodayHeadline extends StatelessWidget {
  const _TodayHeadline({required this.dueCount});

  final int dueCount;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      text: dueCount == 1 ? '1 word\n' : '$dueCount words\n',
      style: AppTypography.display(44),
      children: [
        TextSpan(
          text: dueCount == 0 ? 'all reviewed' : 'waiting for you',
          style: AppTypography.displayItalic(44),
        ),
      ],
    ),
  );
}
