import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:lexico/core/config/flavor_config.dart';
import 'package:lexico/core/network/dio_client.dart';
import 'package:lexico/core/network/network_monitor.dart';
import 'package:lexico/features/decks/data/datasources/decks_local_data_source.dart';
import 'package:lexico/features/decks/data/datasources/decks_remote_data_source.dart';
import 'package:lexico/features/decks/data/repositories/decks_repository_impl.dart';
import 'package:lexico/features/decks/domain/repositories/decks_repository.dart';
import 'package:lexico/features/decks/domain/usecases/create_deck.dart';
import 'package:lexico/features/decks/domain/usecases/get_decks.dart';
import 'package:lexico/features/decks/domain/usecases/refresh_decks.dart';
import 'package:lexico/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:lexico/features/settings/data/datasources/settings_local_data_source.dart';
import 'package:lexico/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:lexico/features/settings/domain/repositories/settings_repository.dart';
import 'package:lexico/features/settings/domain/usecases/get_study_preferences.dart';
import 'package:lexico/features/settings/domain/usecases/set_repeat_missed_words.dart';
import 'package:lexico/features/settings/domain/usecases/set_words_per_session.dart';
import 'package:lexico/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/app_database.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/local_transaction.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/pending_changes_local_data_source.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/starter_deck_data_source.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/vocabulary_local_data_source.dart';
import 'package:lexico/features/vocabulary/data/datasources/remote/vocabulary_remote_data_source.dart';
import 'package:lexico/features/vocabulary/data/repositories/vocabulary_repository_impl.dart';
import 'package:lexico/features/vocabulary/data/sync/sync_engine.dart';
import 'package:lexico/features/vocabulary/domain/repositories/vocabulary_repository.dart';
import 'package:lexico/features/vocabulary/domain/services/spaced_repetition_scheduler.dart';
import 'package:lexico/features/vocabulary/domain/usecases/add_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/edit_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/finish_study_session.dart';
import 'package:lexico/features/vocabulary/domain/usecases/get_deck_words.dart';
import 'package:lexico/features/vocabulary/domain/usecases/get_learner_stats.dart';
import 'package:lexico/features/vocabulary/domain/usecases/get_studied_deck_ids.dart';
import 'package:lexico/features/vocabulary/domain/usecases/record_review.dart';
import 'package:lexico/features/vocabulary/domain/usecases/refresh_deck_words.dart';
import 'package:lexico/features/vocabulary/domain/usecases/set_deck_studied.dart';
import 'package:lexico/features/vocabulary/domain/usecases/start_study_session.dart';
import 'package:lexico/features/vocabulary/domain/usecases/sync_vocabulary.dart';
import 'package:lexico/features/vocabulary/domain/usecases/watch_sync_conflicts.dart';
import 'package:lexico/features/vocabulary/presentation/bloc/home/home_bloc.dart';
import 'package:lexico/features/vocabulary/presentation/bloc/study/study_bloc.dart';

final GetIt sl = GetIt.instance;

/// Composition root: the only place that knows every concrete class.
void configureDependencies(FlavorConfig config) {
  sl
    // ── Infrastructure ──────────────────────────────────────────────────
    ..registerSingleton<FlavorConfig>(config)
    ..registerLazySingleton<Dio>(
      () => DioClient.create(baseUrl: config.apiBaseUrl),
    )
    ..registerLazySingleton<NetworkMonitor>(ConnectivityNetworkMonitor.new)
    ..registerLazySingleton<AppDatabase>(AppDatabase.new)
    ..registerLazySingleton(() => LocalTransaction(sl()))
    // ── Data sources ────────────────────────────────────────────────────
    ..registerLazySingleton<VocabularyRemoteDataSource>(
      () => VocabularyRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<VocabularyLocalDataSource>(
      () => VocabularyLocalDataSourceImpl(sl()),
    )
    ..registerLazySingleton<StarterDeckDataSource>(
      StarterDeckAssetDataSource.new,
    )
    ..registerLazySingleton<DecksRemoteDataSource>(
      () => DecksRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<DecksLocalDataSource>(
      () => DecksLocalDataSourceImpl(sl()),
    )
    ..registerLazySingleton<PendingChangesLocalDataSource>(
      () => PendingChangesLocalDataSourceImpl(sl()),
    )
    // ── Sync ────────────────────────────────────────────────────────────
    ..registerLazySingleton(
      () => SyncEngine(
        wordsRemote: sl(),
        decksRemote: sl(),
        local: sl(),
        decksLocal: sl(),
        pending: sl(),
        transaction: sl(),
        onlineChanges: sl<NetworkMonitor>().onlineChanges,
      ),
      dispose: (sync) => sync.dispose(),
    )
    ..registerLazySingleton<SettingsLocalDataSource>(
      SettingsLocalDataSourceImpl.new,
    )
    // ── Domain ──────────────────────────────────────────────────────────
    ..registerLazySingleton<VocabularyRepository>(
      () => VocabularyRepositoryImpl(
        local: sl(),
        decksLocal: sl(),
        pending: sl(),
        transaction: sl(),
        sync: sl(),
        starterDeck: sl(),
      ),
    )
    ..registerLazySingleton(() => const SpacedRepetitionScheduler())
    ..registerLazySingleton(() => SyncVocabulary(sl()))
    ..registerLazySingleton(() => GetLearnerStats(sl()))
    ..registerLazySingleton(() => StartStudySession(sl()))
    ..registerLazySingleton(() => RecordReview(sl(), sl()))
    ..registerLazySingleton(() => FinishStudySession(sl()))
    ..registerLazySingleton(() => GetStudiedDeckIds(sl()))
    ..registerLazySingleton(() => SetDeckStudied(sl()))
    ..registerLazySingleton(() => GetDeckWords(sl()))
    ..registerLazySingleton(() => RefreshDeckWords(sl()))
    ..registerLazySingleton(() => WatchSyncConflicts(sl()))
    ..registerLazySingleton(() => AddWord(sl()))
    ..registerLazySingleton(() => EditWord(sl()))
    ..registerLazySingleton<DecksRepository>(
      () => DecksRepositoryImpl(
        local: sl(),
        pending: sl(),
        transaction: sl(),
        sync: sl(),
      ),
    )
    ..registerLazySingleton(() => GetDecks(sl()))
    ..registerLazySingleton(() => RefreshDecks(sl()))
    ..registerLazySingleton(() => CreateDeck(sl()))
    ..registerLazySingleton<SettingsRepository>(
      () => SettingsRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => GetStudyPreferences(sl()))
    ..registerLazySingleton(() => SetRepeatMissedWords(sl()))
    ..registerLazySingleton(() => SetWordsPerSession(sl()))
    // ── Presentation ────────────────────────────────────────────────────
    ..registerFactory(
      () => HomeBloc(syncVocabulary: sl(), getLearnerStats: sl()),
    )
    ..registerFactory(
      () => DecksBloc(
        getDecks: sl(),
        refreshDecks: sl(),
        getStudiedDeckIds: sl(),
        setDeckStudied: sl(),
      ),
    )
    ..registerFactory(
      () => StudyBloc(
        startStudySession: sl(),
        recordReview: sl(),
        finishStudySession: sl(),
        getStudyPreferences: sl(),
      ),
    )
    ..registerFactory(
      () => SettingsCubit(
        getStudyPreferences: sl(),
        setRepeatMissedWords: sl(),
        setWordsPerSession: sl(),
      ),
    );
}
