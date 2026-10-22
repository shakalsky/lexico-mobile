import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/app/injection.dart';
import 'package:lexico/core/theme/app_theme.dart';
import 'package:lexico/features/settings/domain/usecases/get_study_preferences.dart';
import 'package:lexico/features/vocabulary/domain/repositories/vocabulary_repository.dart';
import 'package:lexico/features/vocabulary/domain/services/spaced_repetition_scheduler.dart';
import 'package:lexico/features/vocabulary/domain/usecases/finish_study_session.dart';
import 'package:lexico/features/vocabulary/domain/usecases/get_learner_stats.dart';
import 'package:lexico/features/vocabulary/domain/usecases/record_review.dart';
import 'package:lexico/features/vocabulary/domain/usecases/start_study_session.dart';
import 'package:lexico/features/vocabulary/domain/usecases/sync_vocabulary.dart';
import 'package:lexico/features/vocabulary/presentation/bloc/home/home_bloc.dart';
import 'package:lexico/features/vocabulary/presentation/bloc/study/study_bloc.dart';
import 'package:lexico/features/vocabulary/presentation/pages/home_page.dart';

import '../../../../helpers/fake_settings_repository.dart';
import '../../../../helpers/fake_vocabulary_repository.dart';
import '../../../../helpers/fixtures.dart';

void main() {
  final now = DateTime(2026, 8, 21, 10);
  late FakeVocabularyRepository repository;

  /// Registers the real blocs and use cases over an in-memory repository, so
  /// the test drives the same wiring the app uses.
  void registerDependencies(FakeVocabularyRepository repo) {
    sl
      ..registerSingleton<VocabularyRepository>(repo)
      ..registerFactory(
        () => HomeBloc(
          syncVocabulary: SyncVocabulary(sl()),
          getLearnerStats: GetLearnerStats(sl()),
        ),
      )
      ..registerFactory(
        () => StudyBloc(
          startStudySession: StartStudySession(sl()),
          recordReview: RecordReview(sl(), const SpacedRepetitionScheduler()),
          finishStudySession: FinishStudySession(sl()),
          getStudyPreferences: GetStudyPreferences(FakeSettingsRepository()),
          clock: () => now,
        ),
      );
  }

  setUp(() {
    repository = FakeVocabularyRepository(cards: testDeck(3), clock: () => now);
    registerDependencies(repository);
  });

  tearDown(sl.reset);

  /// The streak dot and the loading spinner animate forever, so
  /// `pumpAndSettle` would never return: advance a fixed slice instead.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BlocProvider(
          create: (_) => sl<HomeBloc>()..add(const HomeStarted()),
          child: const HomePage(),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('the home screen shows what is waiting', (tester) async {
    await pumpApp(tester);

    expect(find.text('léxico'), findsOneWidget);
    expect(find.text('0 day streak'), findsOneWidget);
    expect(find.text('Start session'), findsOneWidget);
    expect(find.textContaining('3 words'), findsOneWidget);  });

  testWidgets('a card turns over to reveal the answer', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Start session'));
    await settle(tester);

    expect(find.text('palabra 0'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('word 0'), findsNothing);

    await tester.tap(find.text('palabra 0'));
    await settle(tester);

    expect(find.text('word 0'), findsOneWidget);
    expect(find.text('TAP TO TURN BACK'), findsOneWidget);
  });

  testWidgets('each card shows its difficulty badge', (tester) async {
    sl.unregister<VocabularyRepository>();
    repository = FakeVocabularyRepository(
      cards: [testCard(id: 'hard', question: 'el desafío', lapses: 8)],
      clock: () => now,
    );
    sl.registerSingleton<VocabularyRepository>(repository);

    await pumpApp(tester);
    await tester.tap(find.text('Start session'));
    await settle(tester);

    expect(find.text('el desafío'), findsOneWidget);
    expect(find.text('C1'), findsOneWidget);
  });

  testWidgets('answering every card lands on the summary', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Start session'));
    await settle(tester);

    // Two right, one wrong.
    await tester.tap(find.byKey(const Key('answer-knew-it')));
    await settle(tester);
    expect(find.text('2/3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('answer-knew-it')));
    await settle(tester);
    expect(find.text('3/3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('answer-needs-review')));
    await settle(tester);

    expect(find.text('Session complete'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
    expect(find.text('2 of 3 right'), findsOneWidget);
    expect(find.text('+24'), findsOneWidget);
    expect(find.text('Back tomorrow'), findsOneWidget);
    expect(find.text('palabra 2'), findsOneWidget);

    expect(repository.loggedSessions, 1);
    expect(repository.savedReviews, hasLength(3));
  });

  testWidgets('swiping right answers the top card', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Start session'));
    await settle(tester);

    await tester.fling(find.text('palabra 0'), const Offset(300, 0), 1200);
    await settle(tester);

    expect(find.text('2/3'), findsOneWidget);
    expect(repository.savedReviews.single.wordId, 'word-0');
    expect(repository.savedReviews.single.timesCorrect, 1);
  });

  testWidgets('swiping left sends the word back for review', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Start session'));
    await settle(tester);

    await tester.fling(find.text('palabra 0'), const Offset(-300, 0), 1200);
    await settle(tester);

    expect(find.text('2/3'), findsOneWidget);
    expect(repository.savedReviews.single.lapses, 1);
  });

  testWidgets('leaving early returns home and refreshes it', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Start session'));
    await settle(tester);

    await tester.tap(find.byKey(const Key('answer-knew-it')));
    await settle(tester);

    await tester.tap(find.byKey(const Key('session-quit')));
    await settle(tester);

    expect(find.text('léxico'), findsOneWidget);
    expect(find.text('1 day streak'), findsOneWidget);
    expect(repository.loggedSessions, 1, reason: 'partial work still counts');
  });

  testWidgets('with nothing due the learner can still study ahead', (
    tester,
  ) async {
    await sl.reset();
    registerDependencies(
      FakeVocabularyRepository(
        cards: testDeck(2, dueAt: now.add(const Duration(days: 3))),
        clock: () => now,
      ),
    );

    await pumpApp(tester);

    expect(find.textContaining('Nothing is due'), findsOneWidget);

    await tester.tap(find.text('Study ahead'));
    await settle(tester);

    expect(find.text('palabra 0'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('the button is disabled when there are no words', (tester) async {
    await sl.reset();
    registerDependencies(FakeVocabularyRepository(clock: () => now));

    await pumpApp(tester);

    expect(find.text('No words yet'), findsOneWidget);
    expect(find.textContaining('Add a deck'), findsOneWidget);

    await tester.tap(find.text('No words yet'));
    await settle(tester);

    expect(find.text('léxico'), findsOneWidget, reason: 'no session started');
  });
}
