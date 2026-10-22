import 'package:equatable/equatable.dart';
import 'package:lexico/features/vocabulary/domain/entities/card_level.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_grade.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';

/// One answered card within the running session.
class ReviewOutcome extends Equatable {
  const ReviewOutcome({
    required this.word,
    required this.grade,
    required this.level,
    required this.answeredAt,
  });

  final VocabWord word;
  final ReviewGrade grade;

  /// The badge the card had when it was answered, before this answer.
  final CardLevel level;
  final DateTime answeredAt;

  bool get isCorrect => grade.isCorrect;

  int get xpEarned => isCorrect ? level.xpPerCorrectAnswer : 0;

  @override
  List<Object?> get props => [word, grade, level, answeredAt];
}
