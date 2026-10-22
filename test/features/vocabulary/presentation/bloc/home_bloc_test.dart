import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/core/error/failure.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/features/vocabulary/domain/entities/learner_stats.dart';
import 'package:lexico/features/vocabulary/domain/usecases/get_learner_stats.dart';
import 'package:lexico/features/vocabulary/domain/usecases/sync_vocabulary.dart';
import 'package:lexico/features/vocabulary/presentation/bloc/home/home_bloc.dart';

import '../../../../helpers/fake_vocabulary_repository.dart';
import '../../../../helpers/fixtures.dart';

/// A repository that always refuses, to exercise the error path.
class _BrokenRepository extends FakeVocabularyRepository {
  @override
  Future<Result<int>> syncDecks() async =>
      const Result.failure(NetworkFailure('offline'));
}

void main() {
  final now = DateTime(2026, 8, 21, 10);

  HomeBloc buildBloc(FakeVocabularyRepository repository) => HomeBloc(
    syncVocabulary: SyncVocabulary(repository),
    getLearnerStats: GetLearnerStats(repository),
  );

  blocTest<HomeBloc, HomeState>(
    'syncs the deck, then publishes the stats',
    build: () => buildBloc(
      FakeVocabularyRepository(cards: testDeck(5), clock: () => now),
    ),
    act: (bloc) => bloc.add(const HomeStarted()),
    expect: () => [
      const HomeState(status: HomeStatus.loading),
      isA<HomeState>()
          .having((s) => s.status, 'status', HomeStatus.ready)
          .having((s) => s.stats.dueCount, 'dueCount', 5)
          .having((s) => s.stats.level, 'level', 1)
          .having((s) => s.hasWordsDue, 'hasWordsDue', isTrue),
    ],
  );

  blocTest<HomeBloc, HomeState>(
    'reports why the deck could not be prepared',
    build: () => buildBloc(_BrokenRepository()),
    act: (bloc) => bloc.add(const HomeStarted()),
    expect: () => [
      const HomeState(status: HomeStatus.loading),
      const HomeState(status: HomeStatus.failure, message: 'offline'),
    ],
  );

  group('refreshing after a session', () {
    late FakeVocabularyRepository repository;

    blocTest<HomeBloc, HomeState>(
      're-reads the stats without syncing again',
      build: () {
        repository = FakeVocabularyRepository(
          cards: testDeck(2),
          clock: () => now,
        );
        return buildBloc(repository);
      },
      act: (bloc) async {
        bloc.add(const HomeStarted());
        await Future<void>.delayed(Duration.zero);

        await repository.logSession(
          startedAt: now,
          endedAt: now,
          reviewedCount: 2,
          correctCount: 2,
          xpEarned: FakeVocabularyRepository.xpFor(2),
        );
        bloc.add(const HomeRefreshed());
      },
      skip: 2,
      expect: () => [
        isA<HomeState>()
            .having((s) => s.status, 'status', HomeStatus.ready)
            .having((s) => s.stats.totalXp, 'totalXp', 24)
            .having((s) => s.stats.streakDays, 'streakDays', 1)
            .having((s) => s.stats, 'stats', isNot(LearnerStats.empty)),
      ],
      verify: (_) => expect(
        repository.syncCalls,
        1,
        reason: 'a refresh must not hit the network again',
      ),
    );
  });
}
