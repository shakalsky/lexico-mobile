import 'package:equatable/equatable.dart';
import 'package:lexico/features/vocabulary/domain/entities/card_level.dart';

/// Everything the scheduler knows about one word's history.
class ReviewState extends Equatable {
  const ReviewState({
    required this.wordId,
    required this.repetitions,
    required this.intervalDays,
    required this.easeFactor,
    required this.dueAt,
    required this.lapses,
    required this.timesSeen,
    required this.timesCorrect,
    this.lastReviewedAt,
  });

  /// A word that has never been answered: due immediately.
  factory ReviewState.fresh(String wordId, DateTime now) => ReviewState(
    wordId: wordId,
    repetitions: 0,
    intervalDays: 0,
    easeFactor: defaultEaseFactor,
    dueAt: now,
    lapses: 0,
    timesSeen: 0,
    timesCorrect: 0,
  );

  static const double defaultEaseFactor = 2.5;
  static const double minEaseFactor = 1.3;
  static const double maxEaseFactor = 2.8;

  /// Clean repetitions after which a word counts as known.
  static const int knownRepetitionThreshold = 3;

  /// Consecutive correct answers with no lapse in between.
  final int repetitions;

  /// Days until the next showing; `0` means "again in this same day".
  final int intervalDays;

  /// SM-2 style multiplier: how fast this word's interval grows.
  final double easeFactor;
  final String wordId;
  final DateTime dueAt;
  final DateTime? lastReviewedAt;
  final int lapses;
  final int timesSeen;
  final int timesCorrect;

  /// Three clean repetitions and the word has moved into long-term memory.
  bool get isKnown => repetitions >= knownRepetitionThreshold;

  /// Answered wrong at some point and not yet re-established.
  bool get isShaky => lapses > 0 && !isKnown;

  bool get isNew => timesSeen == 0;

  /// The difficulty badge; also decides the XP a correct answer earns.
  CardLevel get level =>
      CardLevel.fromHistory(lapses: lapses, timesSeen: timesSeen);

  bool isDue(DateTime now) => !dueAt.isAfter(now);

  ReviewState copyWith({
    int? repetitions,
    int? intervalDays,
    double? easeFactor,
    DateTime? dueAt,
    DateTime? lastReviewedAt,
    int? lapses,
    int? timesSeen,
    int? timesCorrect,
  }) => ReviewState(
    wordId: wordId,
    repetitions: repetitions ?? this.repetitions,
    intervalDays: intervalDays ?? this.intervalDays,
    easeFactor: easeFactor ?? this.easeFactor,
    dueAt: dueAt ?? this.dueAt,
    lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    lapses: lapses ?? this.lapses,
    timesSeen: timesSeen ?? this.timesSeen,
    timesCorrect: timesCorrect ?? this.timesCorrect,
  );

  @override
  List<Object?> get props => [
    wordId,
    repetitions,
    intervalDays,
    easeFactor,
    dueAt,
    lastReviewedAt,
    lapses,
    timesSeen,
    timesCorrect,
  ];
}
