/// How hard a word has proven to be, shown as a CEFR-style badge.
///
/// Set only by lapses (wrong answers ever), so it never goes down. A harder
/// card pays more XP for a correct answer. Matches lexico-web's CardLevel.
enum CardLevel {
  a0(minLapses: 0, xpPerCorrectAnswer: 12),
  a1(minLapses: 1, xpPerCorrectAnswer: 14),
  a2(minLapses: 2, xpPerCorrectAnswer: 16),
  b1(minLapses: 3, xpPerCorrectAnswer: 20),
  b2(minLapses: 5, xpPerCorrectAnswer: 24),
  c1(minLapses: 8, xpPerCorrectAnswer: 30),
  c2(minLapses: 12, xpPerCorrectAnswer: 36);

  const CardLevel({required this.minLapses, required this.xpPerCorrectAnswer});

  /// Fewest lapses that earn this badge.
  final int minLapses;
  final int xpPerCorrectAnswer;

  /// A never-seen word is A0; otherwise the highest badge its lapses reach.
  static CardLevel fromHistory({required int lapses, required int timesSeen}) {
    if (timesSeen == 0) return a0;
    return values.lastWhere((level) => lapses >= level.minLapses);
  }

  /// "A0", "B2", …
  String get label => name.toUpperCase();
}
