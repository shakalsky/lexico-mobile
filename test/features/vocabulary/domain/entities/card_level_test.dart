import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/features/vocabulary/domain/entities/card_level.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_state.dart';

void main() {
  CardLevel levelAfter(int lapses) =>
      CardLevel.fromHistory(lapses: lapses, timesSeen: lapses + 1);

  test('a never-seen word is A0', () {
    expect(CardLevel.fromHistory(lapses: 0, timesSeen: 0), CardLevel.a0);
  });

  test('a seen word with no lapses stays A0', () {
    expect(levelAfter(0), CardLevel.a0);
  });

  test('lapses climb the badge at the lexico-web thresholds', () {
    final expected = {
      1: CardLevel.a1,
      2: CardLevel.a2,
      3: CardLevel.b1,
      4: CardLevel.b1,
      5: CardLevel.b2,
      7: CardLevel.b2,
      8: CardLevel.c1,
      11: CardLevel.c1,
      12: CardLevel.c2,
      40: CardLevel.c2,
    };
    expected.forEach((lapses, level) {
      expect(levelAfter(lapses), level, reason: '$lapses lapses');
    });
  });

  test('harder badges pay more XP', () {
    expect(CardLevel.values.map((l) => l.xpPerCorrectAnswer), [
      12,
      14,
      16,
      20,
      24,
      30,
      36,
    ]);
  });

  test('labels read like CEFR levels', () {
    expect(CardLevel.b2.label, 'B2');
  });

  test('a review state exposes its badge', () {
    final state = ReviewState.fresh(
      'w',
      DateTime(2026),
    ).copyWith(lapses: 3, timesSeen: 5);
    expect(state.level, CardLevel.b1);
  });
}
