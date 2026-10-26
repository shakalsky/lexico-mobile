import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/vocabulary/domain/entities/learner_stats.dart';
import 'package:lexico/features/vocabulary/domain/usecases/get_learner_stats.dart';
import 'package:lexico/features/vocabulary/domain/usecases/sync_vocabulary.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required SyncVocabulary syncVocabulary,
    required GetLearnerStats getLearnerStats,
  }) : _syncVocabulary = syncVocabulary,
       _getLearnerStats = getLearnerStats,
       super(const HomeState()) {
    on<HomeStarted>(_onStarted);
    on<HomeRefreshed>(_onRefreshed);
  }

  final SyncVocabulary _syncVocabulary;
  final GetLearnerStats _getLearnerStats;

  /// Shows the stored numbers at once, then syncs and shows them again. A
  /// spinner shows only while there are no words stored yet.
  Future<void> _onStarted(HomeStarted event, Emitter<HomeState> emit) async {
    emit(state.copyWith(status: HomeStatus.loading));

    final stored = await _getLearnerStats(const NoParams());
    if (stored case Success(:final value) when value.wordCount > 0) {
      emit(state.copyWith(status: HomeStatus.ready, stats: value));
    }

    final sync = await _syncVocabulary(const NoParams());
    final syncFailure = sync.failureOrNull;
    if (syncFailure != null) {
      if (state.status != HomeStatus.ready) {
        emit(
          state.copyWith(
            status: HomeStatus.failure,
            message: syncFailure.message,
          ),
        );
      }
      return;
    }

    await _emitStats(emit);
  }

  Future<void> _onRefreshed(HomeRefreshed event, Emitter<HomeState> emit) =>
      _emitStats(emit);

  Future<void> _emitStats(Emitter<HomeState> emit) async {
    final stats = await _getLearnerStats(const NoParams());
    emit(
      stats.fold(
        (failure) => state.copyWith(
          status: HomeStatus.failure,
          message: failure.message,
        ),
        (value) => state.copyWith(status: HomeStatus.ready, stats: value),
      ),
    );
  }
}
