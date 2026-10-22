import 'package:lexico/features/vocabulary/data/datasources/local/app_database.dart';

/// A joined `words` + `reviews` row, as it comes out of the database.
class StudyCardRow {
  const StudyCardRow({required this.word, required this.review});

  final WordRow word;
  final ReviewRow review;
}

/// Aggregated answer counters used to derive accuracy.
class AnswerTotalsRow {
  const AnswerTotalsRow({required this.timesSeen, required this.timesCorrect});

  final int timesSeen;
  final int timesCorrect;
}
