import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/core/error/failure.dart';
import 'package:lexico/features/settings/domain/entities/study_preferences.dart';
import 'package:lexico/features/settings/domain/usecases/get_study_preferences.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_grade.dart';
import 'package:lexico/features/vocabulary/domain/entities/study_card.dart';
import 'package:lexico/features/vocabulary/domain/services/spaced_repetition_scheduler.dart';
import 'package:lexico/features/vocabulary/domain/usecases/finish_study_session.dart';
import 'package:lexico/features/vocabulary/domain/usecases/record_review.dart';
import 'package:lexico/features/vocabulary/domain/usecases/start_study_session.dart';
import 'package:lexico/features/vocabulary/presentation/bloc/study/study_bloc.dart';

import '../../../../helpers/fake_settings_repository.dart';
import '../../../../helpers/fake_vocabulary_repository.dart';
import '../../../../helpers/fixtures.dart';

void main() {
  final now = DateTime(2026, 8, 21, 10);
  late FakeVocabularyRepository repository;
  late FakeSettingsRepository settings;

  StudyBloc buildBloc(
    List<StudyCard> cards, {
    bool repeatMissedWords = false,
    int wordsPerSession = StudyPreferences.defaultWordsPerSession,
    Failure? settingsFailure,
  }) {
    repository = FakeVocabularyRepository(cards: cards, clock: () => now);
    settings = FakeSettingsRepository(
      preferences: StudyPreferences(
        repeatMissedWords: repeatMissedWords,
        wordsPerSession: wordsPerSession,
      ),
    )..failure = settingsFailure;
    return StudyBloc(
      startStudySession: StartStudySession(repository),
      recordReview: RecordReview(repository, const SpacedRepetitionScheduler()),
      finishStudySession: FinishStudySession(repository),
      getStudyPreferences: GetStudyPreferences(settings),
      clock: () => now,
    );
  }

  /// Starts a session and answers with [grades] in order.
  Future<void> answer(StudyBloc bloc, List<ReviewGrade> grades) async {
    bloc.add(const StudySessionRequested());
    await Future<void>.delayed(Duration.zero);
    for (final grade in grades) {
      bloc.add(StudyAnswerSubmitted(grade));
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('starting a session', () {
    blocTest<StudyBloc, StudyState>(
      'deals the due cards',
      build: () => buildBloc(testDeck(3)),
      act: (bloc) => bloc.add(const StudySessionRequested()),
      expect: () => [
        isA<StudyState>().having(
          (s) => s.status,
          'status',
          StudyStatus.loading,
        ),
        isA<StudyState>()
            .having((s) => s.status, 'status', StudyStatus.studying)
            .having((s) => s.cards, 'cards', hasLength(3))
            .having((s) => s.position, 'position', 1)
            .having((s) => s.total, 'total', 3),
      ],
    );

    blocTest<StudyBloc, StudyState>(
      'deals no more cards than the words-per-session setting',
      build: () => buildBloc(testDeck(12), wordsPerSession: 5),
      act: (bloc) => bloc.add(const StudySessionRequested()),
      skip: 1,
      expect: () => [
        isA<StudyState>().having((s) => s.cards, 'cards', hasLength(5)),
      ],
    );

    blocTest<StudyBloc, StudyState>(
      'studies ahead with the soonest words when nothing is due',
      build: () => buildBloc([
        testCard(id: 'later', dueAt: now.add(const Duration(days: 5))),
        testCard(id: 'soon', dueAt: now.add(const Duration(days: 1))),
      ]),
      act: (bloc) => bloc.add(const StudySessionRequested()),
      skip: 1,
      expect: () => [
        isA<StudyState>()
            .having((s) => s.status, 'status', StudyStatus.studying)
            .having((s) => s.cards.map((c) => c.id), 'cards', [
              'soon',
              'later',
            ]),
      ],
    );

    blocTest<StudyBloc, StudyState>(
      'fails when there are no words at all',
      build: () => buildBloc(const []),
      act: (bloc) => bloc.add(const StudySessionRequested()),
      expect: () => [
        isA<StudyState>().having(
          (s) => s.status,
          'status',
          StudyStatus.loading,
        ),
        isA<StudyState>()
            .having((s) => s.status, 'status', StudyStatus.failure)
            .having((s) => s.message, 'message', contains('no words to study')),
      ],
    );
  });

  blocTest<StudyBloc, StudyState>(
    'flipping toggles the revealed face',
    build: () => buildBloc(testDeck(2)),
    act: (bloc) async {
      bloc.add(const StudySessionRequested());
      await Future<void>.delayed(Duration.zero);
      bloc
        ..add(const StudyCardFlipped())
        ..add(const StudyCardFlipped());
    },
    skip: 2,
    expect: () => [
      isA<StudyState>().having((s) => s.isRevealed, 'isRevealed', isTrue),
      isA<StudyState>().having((s) => s.isRevealed, 'isRevealed', isFalse),
    ],
  );

  group('answering', () {
    blocTest<StudyBloc, StudyState>(
      'advances to the next card and confirms with a toast',
      build: () => buildBloc(testDeck(3)),
      act: (bloc) async {
        bloc.add(const StudySessionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const StudyAnswerSubmitted(ReviewGrade.knewIt));
      },
      skip: 2,
      expect: () => [
        isA<StudyState>()
            .having((s) => s.index, 'index', 1)
            .having((s) => s.position, 'position', 2)
            .having((s) => s.isRevealed, 'isRevealed', isFalse)
            .having((s) => s.outcomes, 'outcomes', hasLength(1))
            .having((s) => s.toast?.message, 'toast', 'knew it · +12 XP')
            .having((s) => s.toast?.isPositive, 'positive', isTrue),
      ],
      verify: (_) {
        expect(repository.savedReviews.single.repetitions, 1);
        expect(repository.savedReviews.single.timesCorrect, 1);
        expect(repository.reportedAnswers, [true]);
      },
    );

    blocTest<StudyBloc, StudyState>(
      'pays XP by the badge the card had when answered',
      // 3 lapses → B1 → 20 XP.
      build: () => buildBloc([testCard(id: 'hard', lapses: 3), ...testDeck(1)]),
      act: (bloc) async {
        bloc.add(const StudySessionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const StudyAnswerSubmitted(ReviewGrade.knewIt));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const StudyAnswerSubmitted(ReviewGrade.knewIt));
      },
      skip: 2,
      expect: () => [
        isA<StudyState>().having(
          (s) => s.toast?.message,
          'toast',
          'knew it · +20 XP',
        ),
        isA<StudyState>()
            .having((s) => s.status, 'status', StudyStatus.finished)
            .having((s) => s.summary!.xpEarned, 'xp', 20 + 12),
      ],
    );

    blocTest<StudyBloc, StudyState>(
      'names the answer when the word is missed',
      build: () => buildBloc(testDeck(3)),
      act: (bloc) async {
        bloc.add(const StudySessionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const StudyAnswerSubmitted(ReviewGrade.needsReview));
      },
      skip: 2,
      expect: () => [
        isA<StudyState>()
            .having(
              (s) => s.toast?.message,
              'toast',
              'saved for review · word 0',
            )
            .having((s) => s.toast?.isPositive, 'positive', isFalse),
      ],
      verify: (_) {
        expect(repository.savedReviews.single.lapses, 1);
        expect(repository.reportedAnswers, [false]);
      },
    );

    blocTest<StudyBloc, StudyState>(
      'clears the toast on its own',
      build: () => buildBloc(testDeck(3)),
      act: (bloc) async {
        bloc.add(const StudySessionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const StudyAnswerSubmitted(ReviewGrade.knewIt));
      },
      wait: StudyBloc.toastDuration + const Duration(milliseconds: 50),
      skip: 3,
      expect: () => [isA<StudyState>().having((s) => s.toast, 'toast', isNull)],
    );
  });

  group('finishing', () {
    blocTest<StudyBloc, StudyState>(
      'summarises the sitting after the last card',
      build: () => buildBloc(testDeck(2)),
      act: (bloc) async {
        bloc.add(const StudySessionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const StudyAnswerSubmitted(ReviewGrade.knewIt));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const StudyAnswerSubmitted(ReviewGrade.needsReview));
      },
      skip: 3,
      expect: () => [
        isA<StudyState>()
            .having((s) => s.status, 'status', StudyStatus.finished)
            .having((s) => s.toast, 'toast', isNull)
            .having((s) => s.summary!.reviewedCount, 'reviewed', 2)
            .having((s) => s.summary!.correctCount, 'correct', 1)
            .having((s) => s.summary!.accuracyPercent, 'accuracy', 50)
            .having((s) => s.summary!.xpEarned, 'xp', 12)
            .having((s) => s.summary!.streakDays, 'streak', 1)
            .having(
              (s) => s.summary!.missedWords.map((w) => w.answer),
              'missed',
              ['word 1'],
            ),
      ],
      verify: (_) {
        expect(repository.loggedSessions, 1);
        expect(repository.totalXp, FakeVocabularyRepository.xpFor(1));
      },
    );

    blocTest<StudyBloc, StudyState>(
      'requesting another round deals a fresh stack',
      build: () => buildBloc(testDeck(2)),
      act: (bloc) async {
        bloc.add(const StudySessionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const StudySessionRequested());
      },
      skip: 2,
      expect: () => [
        isA<StudyState>().having(
          (s) => s.status,
          'status',
          StudyStatus.loading,
        ),
        isA<StudyState>()
            .having((s) => s.status, 'status', StudyStatus.studying)
            .having((s) => s.index, 'index', 0)
            .having((s) => s.outcomes, 'outcomes', isEmpty)
            .having((s) => s.summary, 'summary', isNull),
      ],
    );
  });

  group('repeating missed words', () {
    const knew = ReviewGrade.knewIt;
    const missed = ReviewGrade.needsReview;

    blocTest<StudyBloc, StudyState>(
      'is off by default: a missed word is not dealt again',
      build: () => buildBloc(testDeck(2)),
      act: (bloc) => answer(bloc, [missed]),
      skip: 2,
      expect: () => [
        isA<StudyState>()
            .having((s) => s.repeatMissedWords, 'repeat', isFalse)
            .having((s) => s.total, 'total', 2)
            .having(
              (s) => s.toast?.message,
              'toast',
              'saved for review · word 0',
            ),
      ],
    );

    blocTest<StudyBloc, StudyState>(
      'puts a missed word back at the end of the stack',
      build: () => buildBloc(testDeck(3), repeatMissedWords: true),
      act: (bloc) => answer(bloc, [missed]),
      skip: 2,
      expect: () => [
        isA<StudyState>()
            .having((s) => s.repeatMissedWords, 'repeat', isTrue)
            .having((s) => s.index, 'index', 1)
            // The repeat neither counts as a new word nor fills the bar.
            .having((s) => s.total, 'total', 3)
            .having((s) => s.position, 'position', 1)
            .having((s) => s.progress, 'progress', 0)
            .having((s) => s.cards.map((c) => c.id), 'order', [
              'word-0',
              'word-1',
              'word-2',
              'word-0',
            ])
            .having(
              (s) => s.toast?.message,
              'toast',
              'back at the end · word 0',
            ),
      ],
    );

    blocTest<StudyBloc, StudyState>(
      'keeps dealing the word until it is answered right',
      build: () => buildBloc(testDeck(2), repeatMissedWords: true),
      // word-0 ✗, word-1 ✓, word-0 ✗, word-0 ✓
      act: (bloc) => answer(bloc, [missed, knew, missed, knew]),
      verify: (bloc) {
        final state = bloc.state;
        expect(state.status, StudyStatus.finished);
        expect(state.cards.map((c) => c.id), [
          'word-0',
          'word-1',
          'word-0',
          'word-0',
        ]);
        // Only the first answer to each word is graded.
        expect(state.summary!.reviewedCount, 2);
        expect(state.summary!.correctCount, 1);
        expect(state.summary!.xpEarned, 12);
        expect(state.summary!.missedWords.map((w) => w.answer), ['word 0']);
        expect(repository.savedReviews.map((r) => r.wordId), [
          'word-0',
          'word-1',
        ]);
        expect(repository.reportedAnswers, [false, true]);
      },
    );

    blocTest<StudyBloc, StudyState>(
      'fills the bar only for words that will not be dealt again',
      build: () => buildBloc(testDeck(2), repeatMissedWords: true),
      // word-0 ✗, word-1 ✓ — word-0 is still waiting at the end.
      act: (bloc) => answer(bloc, [missed, knew]),
      skip: 3,
      expect: () => [
        isA<StudyState>()
            .having((s) => s.currentCard?.id, 'top card', 'word-0')
            .having((s) => s.total, 'total', 2)
            .having((s) => s.position, 'position', 2)
            .having((s) => s.progress, 'progress', 0.5),
      ],
    );

    blocTest<StudyBloc, StudyState>(
      'a right answer on a repeat earns no XP',
      build: () => buildBloc(testDeck(2), repeatMissedWords: true),
      // word-0 ✗, word-1 ✓, word-0 ✓
      act: (bloc) => answer(bloc, [missed, knew, knew]),
      verify: (bloc) {
        expect(bloc.state.status, StudyStatus.finished);
        expect(bloc.state.summary!.correctCount, 1);
        expect(bloc.state.summary!.xpEarned, 12);
        expect(repository.totalXp, FakeVocabularyRepository.xpFor(1));
      },
    );

    blocTest<StudyBloc, StudyState>(
      'a miss on the last card deals it again instead of finishing',
      build: () => buildBloc(testDeck(1), repeatMissedWords: true),
      act: (bloc) => answer(bloc, [missed]),
      skip: 2,
      expect: () => [
        isA<StudyState>()
            .having((s) => s.status, 'status', StudyStatus.studying)
            .having((s) => s.currentCard?.id, 'top card', 'word-0')
            .having((s) => s.position, 'position', 1)
            .having((s) => s.total, 'total', 1)
            .having((s) => s.progress, 'progress', 0),
      ],
      verify: (_) => expect(repository.loggedSessions, 0),
    );

    blocTest<StudyBloc, StudyState>(
      'shows a practice toast when a repeat is answered right',
      build: () => buildBloc(testDeck(2), repeatMissedWords: true),
      act: (bloc) => answer(bloc, [missed, missed, knew]),
      skip: 4,
      expect: () => [
        isA<StudyState>().having(
          (s) => s.toast?.message,
          'toast',
          'got it this time',
        ),
      ],
    );

    blocTest<StudyBloc, StudyState>(
      'falls back to the default when settings cannot be read',
      build: () => buildBloc(
        testDeck(2),
        repeatMissedWords: true,
        settingsFailure: const CacheFailure(),
      ),
      act: (bloc) => answer(bloc, [missed]),
      skip: 2,
      expect: () => [
        isA<StudyState>()
            .having((s) => s.repeatMissedWords, 'repeat', isFalse)
            .having((s) => s.total, 'total', 2),
      ],
    );
  });

  group('quitting', () {
    blocTest<StudyBloc, StudyState>(
      'logs the answers given so far',
      build: () => buildBloc(testDeck(4)),
      act: (bloc) async {
        bloc.add(const StudySessionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const StudyAnswerSubmitted(ReviewGrade.knewIt));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const StudySessionQuit());
      },
      skip: 3,
      expect: () => [
        isA<StudyState>()
            .having((s) => s.status, 'status', StudyStatus.abandoned)
            .having((s) => s.toast, 'toast', isNull),
      ],
      verify: (_) {
        expect(repository.loggedSessions, 1);
        expect(repository.totalXp, FakeVocabularyRepository.xpFor(1));
      },
    );

    blocTest<StudyBloc, StudyState>(
      'logs nothing when no card was answered',
      build: () => buildBloc(testDeck(4)),
      act: (bloc) async {
        bloc.add(const StudySessionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const StudySessionQuit());
      },
      skip: 2,
      expect: () => [
        isA<StudyState>().having(
          (s) => s.status,
          'status',
          StudyStatus.abandoned,
        ),
      ],
      verify: (_) => expect(repository.loggedSessions, 0),
    );
  });
}
