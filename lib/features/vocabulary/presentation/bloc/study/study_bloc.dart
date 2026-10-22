import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/settings/domain/entities/study_preferences.dart';
import 'package:lexico/features/settings/domain/usecases/get_study_preferences.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_grade.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_outcome.dart';
import 'package:lexico/features/vocabulary/domain/entities/session_summary.dart';
import 'package:lexico/features/vocabulary/domain/entities/study_card.dart';
import 'package:lexico/features/vocabulary/domain/usecases/finish_study_session.dart';
import 'package:lexico/features/vocabulary/domain/usecases/record_review.dart';
import 'package:lexico/features/vocabulary/domain/usecases/start_study_session.dart';

part 'study_event.dart';
part 'study_state.dart';

class StudyBloc extends Bloc<StudyEvent, StudyState> {
  StudyBloc({
    required StartStudySession startStudySession,
    required RecordReview recordReview,
    required FinishStudySession finishStudySession,
    required GetStudyPreferences getStudyPreferences,
    DateTime Function() clock = DateTime.now,
  }) : _startStudySession = startStudySession,
       _recordReview = recordReview,
       _finishStudySession = finishStudySession,
       _getStudyPreferences = getStudyPreferences,
       _clock = clock,
       super(const StudyState()) {
    on<StudySessionRequested>(_onSessionRequested);
    on<StudyCardFlipped>(_onCardFlipped);
    on<StudyAnswerSubmitted>(_onAnswerSubmitted);
    on<StudyToastDismissed>(_onToastDismissed);
    on<StudySessionQuit>(_onSessionQuit);
  }

  static const Duration toastDuration = Duration(milliseconds: 1100);

  final StartStudySession _startStudySession;
  final RecordReview _recordReview;
  final FinishStudySession _finishStudySession;
  final GetStudyPreferences _getStudyPreferences;
  final DateTime Function() _clock;

  Timer? _toastTimer;

  Future<void> _onSessionRequested(
    StudySessionRequested event,
    Emitter<StudyState> emit,
  ) async {
    _toastTimer?.cancel();
    emit(const StudyState(status: StudyStatus.loading));

    // Unreadable settings must not block studying: fall back to defaults.
    final preferences =
        (await _getStudyPreferences(const NoParams())).valueOrNull ??
        const StudyPreferences();

    final result = await _startStudySession(
      StartStudySessionParams(limit: preferences.wordsPerSession),
    );
    final repeatMissedWords = preferences.repeatMissedWords;

    emit(
      result.fold(
        (failure) =>
            StudyState(status: StudyStatus.failure, message: failure.message),
        (cards) => StudyState(
          status: StudyStatus.studying,
          cards: cards,
          startedAt: _clock(),
          repeatMissedWords: repeatMissedWords,
        ),
      ),
    );
  }

  void _onCardFlipped(StudyCardFlipped event, Emitter<StudyState> emit) {
    if (state.status != StudyStatus.studying) return;
    emit(state.copyWith(isRevealed: !state.isRevealed));
  }

  Future<void> _onAnswerSubmitted(
    StudyAnswerSubmitted event,
    Emitter<StudyState> emit,
  ) async {
    final card = state.currentCard;
    if (card == null || state.status != StudyStatus.studying) return;

    final answeredAt = _clock();

    // Only the first answer to a word is graded. A repeat of a missed word
    // is practice: it doesn't touch the schedule, the server or the XP.
    final isRepeat = state.outcomes.any((o) => o.word.id == card.id);
    var outcomes = state.outcomes;

    if (!isRepeat) {
      final saved = await _recordReview(
        RecordReviewParams(
          card: card,
          grade: event.grade,
          answeredAt: answeredAt,
        ),
      );

      final saveFailure = saved.failureOrNull;
      if (saveFailure != null) {
        emit(
          state.copyWith(
            status: StudyStatus.failure,
            message: saveFailure.message,
            clearToast: true,
          ),
        );
        return;
      }

      outcomes = [
        ...outcomes,
        ReviewOutcome(
          word: card.word,
          grade: event.grade,
          level: card.review.level,
          answeredAt: answeredAt,
        ),
      ];
    }

    final requeue = state.repeatMissedWords && !event.grade.isCorrect;
    final cards = requeue ? [...state.cards, card] : state.cards;

    final isLastCard = state.index + 1 >= cards.length;
    if (isLastCard) {
      await _finish(emit, outcomes: outcomes, endedAt: answeredAt);
      return;
    }

    emit(
      state.copyWith(
        cards: cards,
        index: state.index + 1,
        isRevealed: false,
        outcomes: outcomes,
        toast: _toastFor(
          event.grade,
          card,
          isRepeat: isRepeat,
          requeued: requeue,
        ),
      ),
    );
    _scheduleToastDismissal();
  }

  void _onToastDismissed(StudyToastDismissed event, Emitter<StudyState> emit) {
    if (state.toast == null) return;
    emit(state.copyWith(clearToast: true));
  }

  Future<void> _onSessionQuit(
    StudySessionQuit event,
    Emitter<StudyState> emit,
  ) async {
    _toastTimer?.cancel();

    // Answers already given still count, so log the partial sitting.
    if (state.outcomes.isNotEmpty && state.status == StudyStatus.studying) {
      await _finishStudySession(
        FinishStudySessionParams(
          startedAt: state.startedAt ?? _clock(),
          endedAt: _clock(),
          outcomes: state.outcomes,
        ),
      );
    }

    emit(state.copyWith(status: StudyStatus.abandoned, clearToast: true));
  }

  Future<void> _finish(
    Emitter<StudyState> emit, {
    required List<ReviewOutcome> outcomes,
    required DateTime endedAt,
  }) async {
    _toastTimer?.cancel();

    final result = await _finishStudySession(
      FinishStudySessionParams(
        startedAt: state.startedAt ?? endedAt,
        endedAt: endedAt,
        outcomes: outcomes,
      ),
    );

    emit(
      result.fold(
        (failure) => state.copyWith(
          status: StudyStatus.failure,
          message: failure.message,
          outcomes: outcomes,
          clearToast: true,
        ),
        (summary) => state.copyWith(
          status: StudyStatus.finished,
          index: state.cards.length,
          outcomes: outcomes,
          summary: summary,
          isRevealed: false,
          clearToast: true,
        ),
      ),
    );
  }

  StudyToast _toastFor(
    ReviewGrade grade,
    StudyCard card, {
    required bool isRepeat,
    required bool requeued,
  }) => switch ((grade.isCorrect, isRepeat, requeued)) {
    (true, false, _) => StudyToast(
      message: 'knew it · +${card.review.level.xpPerCorrectAnswer} XP',
      isPositive: true,
    ),
    (true, true, _) => const StudyToast(
      message: 'got it this time',
      isPositive: true,
    ),
    (false, _, true) => StudyToast(
      message: 'back at the end · ${card.word.answer}',
      isPositive: false,
    ),
    (false, _, false) => StudyToast(
      message: 'saved for review · ${card.word.answer}',
      isPositive: false,
    ),
  };

  void _scheduleToastDismissal() {
    _toastTimer?.cancel();
    _toastTimer = Timer(toastDuration, () {
      if (!isClosed) add(const StudyToastDismissed());
    });
  }

  @override
  Future<void> close() {
    _toastTimer?.cancel();
    return super.close();
  }
}
