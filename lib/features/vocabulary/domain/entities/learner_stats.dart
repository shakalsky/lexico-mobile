import 'package:equatable/equatable.dart';
import 'package:lexico/features/vocabulary/domain/entities/study_rules.dart';

/// The numbers behind the home screen.
class LearnerStats extends Equatable {
  const LearnerStats({
    required this.dueCount,
    required this.wordCount,
    required this.knownCount,
    required this.shakyCount,
    required this.accuracyPercent,
    required this.streakDays,
    required this.totalXp,
  });

  static const LearnerStats empty = LearnerStats(
    dueCount: 0,
    wordCount: 0,
    knownCount: 0,
    shakyCount: 0,
    accuracyPercent: 0,
    streakDays: 0,
    totalXp: 0,
  );

  final int dueCount;

  /// Every word in the studied decks, due or not.
  final int wordCount;
  final int knownCount;
  final int shakyCount;
  final int accuracyPercent;
  final int streakDays;
  final int totalXp;

  bool get hasWordsDue => dueCount > 0;

  /// Nothing is due, but there are words to study ahead.
  bool get canStudyAhead => dueCount == 0 && wordCount > 0;

  int get level => totalXp ~/ StudyRules.xpPerLevel + 1;

  int get xpIntoLevel => totalXp % StudyRules.xpPerLevel;

  double get levelProgress => xpIntoLevel / StudyRules.xpPerLevel;

  @override
  List<Object?> get props => [
    dueCount,
    wordCount,
    knownCount,
    shakyCount,
    accuracyPercent,
    streakDays,
    totalXp,
  ];
}
