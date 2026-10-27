import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/core/theme/app_theme.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_grade.dart';
import 'package:lexico/features/vocabulary/domain/entities/study_card.dart';
import 'package:lexico/features/vocabulary/presentation/widgets/swipe_deck.dart';

import '../../../../helpers/fixtures.dart';

void main() {
  final deck = testDeck(2);
  final controller = SwipeDeckController();

  Widget host({
    required List<StudyCard> cards,
    required int topIndex,
    required ValueChanged<ReviewGrade> onAnswered,
  }) => MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: SwipeDeck(
        controller: controller,
        cards: cards,
        topIndex: topIndex,
        isRevealed: false,
        onFlip: () {},
        onAnswered: onAnswered,
      ),
    ),
  );

  testWidgets(
    'an answered card stays away until the stack moves on, and the deck '
    'takes no second answer meanwhile',
    (tester) async {
      final answers = <ReviewGrade>[];
      await tester.pumpWidget(
        host(cards: deck, topIndex: 0, onAnswered: answers.add),
      );
      final topCard = find.text(deck.first.word.question);
      final center = tester.getCenter(topCard);

      controller.swipe(ReviewGrade.needsReview);
      await tester.pumpAndSettle();
      expect(answers, [ReviewGrade.needsReview]);

      // The bloc is still saving: the old card must not snap back.
      expect(tester.getCenter(topCard), isNot(center));
      controller.swipe(ReviewGrade.knewIt);
      await tester.pumpAndSettle();
      expect(answers, hasLength(1));

      // The stack advances (here the missed card comes straight back).
      await tester.pumpWidget(
        host(cards: deck, topIndex: 1, onAnswered: answers.add),
      );
      expect(tester.getCenter(topCard), center);

      controller.swipe(ReviewGrade.knewIt);
      await tester.pumpAndSettle();
      expect(answers, [ReviewGrade.needsReview, ReviewGrade.knewIt]);
    },
  );
}
