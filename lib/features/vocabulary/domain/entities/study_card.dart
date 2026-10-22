import 'package:equatable/equatable.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_state.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';

/// A word paired with its scheduling state — one card in the swipe stack.
class StudyCard extends Equatable {
  const StudyCard({required this.word, required this.review});

  final VocabWord word;
  final ReviewState review;

  String get id => word.id;

  @override
  List<Object?> get props => [word, review];
}
