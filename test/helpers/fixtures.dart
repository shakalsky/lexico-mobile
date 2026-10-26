import 'package:lexico/features/vocabulary/data/models/word_dto.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_state.dart';
import 'package:lexico/features/vocabulary/domain/entities/study_card.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';

const String testDeckId = 'es-en-core';

VocabWord testWord({
  String id = 'es-atardecer',
  String? question = 'el atardecer',
  String? answer = 'sunset',
}) => VocabWord(
  id: id,
  deckId: testDeckId,
  questionShort: question,
  answerShort: answer,
  questionExample: 'Caminamos por la playa al atardecer.',
  answerExample: 'We walked along the beach at sunset.',
);

StudyCard testCard({
  String id = 'es-atardecer',
  String question = 'el atardecer',
  String answer = 'sunset',
  DateTime? dueAt,
  int lapses = 0,
}) {
  final due = dueAt ?? DateTime(2026, 8, 21);
  final fresh = ReviewState.fresh(id, due);
  return StudyCard(
    word: testWord(id: id, question: question, answer: answer),
    // A card with lapses has been seen at least that many times.
    review: lapses == 0
        ? fresh
        : fresh.copyWith(lapses: lapses, timesSeen: lapses),
  );
}

WordDto testDto({
  String id = 'es-atardecer',
  String? question = 'el atardecer',
  String example = 'Caminamos por la playa al atardecer.',
  int shows = 0,
  int successes = 0,
  int failures = 0,
}) => WordDto(
  id: id,
  questionShort: question,
  answerShort: 'sunset',
  questionExample: example,
  answerExample: 'We walked along the beach at sunset.',
  showsCount: shows,
  successesCount: successes,
  failuresCount: failures,
);

/// A deck of [count] distinct cards, all due.
List<StudyCard> testDeck(int count, {DateTime? dueAt}) => List.generate(
  count,
  (i) => testCard(
    id: 'word-$i',
    question: 'palabra $i',
    answer: 'word $i',
    dueAt: dueAt,
  ),
  growable: false,
);
