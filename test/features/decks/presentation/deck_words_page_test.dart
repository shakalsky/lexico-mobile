import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/core/error/failure.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/theme/app_theme.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/presentation/pages/deck_words_page.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/add_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/delete_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/edit_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/get_deck_words.dart';
import 'package:lexico/features/vocabulary/domain/usecases/refresh_deck_words.dart';
import 'package:lexico/features/vocabulary/domain/usecases/watch_sync_conflicts.dart';

import '../../../helpers/fake_decks_repository.dart';
import '../../../helpers/fake_vocabulary_repository.dart';
import '../../../helpers/fixtures.dart';

final Deck _food = testDeckEntity('es-food', name: 'Food');

const _sentence = VocabWord(
  id: 'es-sal',
  deckId: 'es-food',
  questionShort: null,
  answerShort: null,
  questionExample: '¿Me pasas la sal?',
  answerExample: 'Can you pass me the salt?',
);

void main() {
  late FakeVocabularyRepository vocabulary;

  /// The spinner animates forever, so `pumpAndSettle` would never return.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> openPage(
    WidgetTester tester,
    List<Result<List<VocabWord>>> results,
  ) async {
    vocabulary = FakeVocabularyRepository();
    vocabulary.deckWordResults['es-food'] = results;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              DeckWordsPage.route(
                _food,
                getDeckWords: GetDeckWords(vocabulary),
                refreshDeckWords: RefreshDeckWords(vocabulary),
                watchSyncConflicts: WatchSyncConflicts(vocabulary),
                addWord: AddWord(vocabulary),
                editWord: EditWord(vocabulary),
                deleteWord: DeleteWord(vocabulary),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    await settle(tester);
  }

  testWidgets('lists the words with how each one is going', (tester) async {
    const pan = VocabWord(
      id: 'es-pan',
      deckId: 'es-food',
      questionShort: 'el pan',
      answerShort: 'bread',
      questionExample: 'Compro pan cada mañana.',
      answerExample: 'I buy bread every morning.',
      showsCount: 4,
      successesCount: 3,
      failuresCount: 1,
    );
    await openPage(tester, [
      const Result.success([pan, _sentence]),
    ]);

    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Español · 2 words'), findsOneWidget);
    expect(find.text('el pan'), findsOneWidget);
    expect(find.text('bread'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    // A sentence card shows the sentence and its translation.
    expect(find.text('¿Me pasas la sal?'), findsOneWidget);
    expect(find.text('Can you pass me the salt?'), findsOneWidget);
    expect(find.text('new'), findsOneWidget);
  });

  testWidgets('a word never answered right shows no accuracy, not 0%', (
    tester,
  ) async {
    const missed = VocabWord(
      id: 'es-sal',
      deckId: 'es-food',
      questionShort: 'la sal',
      answerShort: 'salt',
      questionExample: 'Falta sal.',
      answerExample: 'It needs salt.',
      showsCount: 2,
      failuresCount: 2,
    );
    await openPage(tester, [
      const Result.success([missed]),
    ]);

    expect(find.text('-'), findsNothing);
    expect(find.text('0%'), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });

  group('swipe left to delete', () {
    Future<void> swipe(WidgetTester tester) async {
      await tester.drag(
        find.byKey(const Key('word-es-sal')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('asks first, then deletes the word', (tester) async {
      await openPage(tester, [
        const Result.success([_sentence]),
      ]);

      await swipe(tester);
      expect(find.text('Delete word?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm-delete')));
      await tester.pumpAndSettle();

      expect(vocabulary.deletedWords, [_sentence]);
      expect(find.byKey(const Key('word-es-sal')), findsNothing);
      expect(find.text('Deleted “¿Me pasas la sal?”'), findsOneWidget);
      expect(find.text('Español · 0 words'), findsOneWidget);
      // Let the notice time out.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('keeps the word when cancelled', (tester) async {
      await openPage(tester, [
        const Result.success([_sentence]),
      ]);

      await swipe(tester);
      await tester.tap(find.byKey(const Key('confirm-delete-cancel')));
      await tester.pumpAndSettle();

      expect(vocabulary.deletedWords, isEmpty);
      expect(find.byKey(const Key('word-es-sal')), findsOneWidget);
    });
  });

  testWidgets('says so when the deck is empty', (tester) async {
    await openPage(tester, [const Result.success([])]);

    expect(find.text('No words in this deck yet'), findsOneWidget);
    expect(find.text('Español · 0 words'), findsOneWidget);
  });

  testWidgets('offers a retry when loading fails', (tester) async {
    await openPage(tester, [
      const Result.failure(NetworkFailure('No connection.')),
      Result.success([testWord(id: 'es-pan', question: 'el pan')]),
    ]);

    expect(find.text("Couldn't load words"), findsOneWidget);
    expect(find.text('No connection.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await settle(tester);

    expect(find.text('el pan'), findsOneWidget);
  });

  testWidgets('pulling down reloads, and keeps the list if that fails', (
    tester,
  ) async {
    await openPage(tester, [
      Result.success([testWord(id: 'es-pan', question: 'el pan')]),
      const Result.failure(NetworkFailure('No connection.')),
    ]);

    await tester.fling(find.text('el pan'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('el pan'), findsOneWidget);
    expect(find.text("Couldn't refresh: No connection."), findsOneWidget);
    expect(vocabulary.deckWordCalls, 2);
  });

  testWidgets('word and meaning start hidden under a chevron', (tester) async {
    await openPage(tester, [const Result.success([])]);
    await tester.tap(find.byKey(const Key('new-word')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('word-form-example')), findsOneWidget);
    expect(find.byKey(const Key('word-form-translation')), findsOneWidget);
    expect(find.byKey(const Key('word-form-word')), findsNothing);
    expect(find.byKey(const Key('word-form-meaning')), findsNothing);

    await tester.tap(find.byKey(const Key('word-form-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('word-form-word')), findsOneWidget);
    expect(find.byKey(const Key('word-form-meaning')), findsOneWidget);

    // Typed text survives hiding the fields again, and still gets sent.
    await tester.enterText(find.byKey(const Key('word-form-word')), 'la sal');
    await tester.tap(find.byKey(const Key('word-form-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('word-form-word')), findsNothing);
    expect(find.text('la sal'), findsOneWidget, reason: 'shown in the row');
  });

  group('new word', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('new-word')));
      await tester.pumpAndSettle();
    }

    Future<void> fill(WidgetTester tester, Map<String, String> fields) async {
      if (fields.containsKey('word') || fields.containsKey('meaning')) {
        await tester.tap(find.byKey(const Key('word-form-more')));
        await tester.pumpAndSettle();
      }
      for (final MapEntry(:key, :value) in fields.entries) {
        await tester.enterText(find.byKey(Key('word-form-$key')), value);
      }
    }

    testWidgets('adds the word to the end of the list', (tester) async {
      await openPage(tester, [
        Result.success([testWord(id: 'es-pan', question: 'el pan')]),
      ]);

      await openSheet(tester);
      await fill(tester, {
        'word': ' la sal ',
        'meaning': 'salt',
        'example': '¿Me pasas la sal?',
        'translation': 'Can you pass me the salt?',
      });
      await tester.tap(find.text('Add word'));
      await tester.pumpAndSettle();

      expect(find.text('Add word'), findsNothing, reason: 'sheet closed');
      expect(find.text('la sal'), findsOneWidget);
      expect(find.text('Español · 2 words'), findsOneWidget);
      expect(find.text('Added “la sal”'), findsOneWidget);

      final added = vocabulary.addedWords.single;
      expect(added.deckId, 'es-food');
      expect(added.word.questionShort, 'la sal', reason: 'trimmed');
      expect(added.word.answerShort, 'salt');
    });

    testWidgets('an empty word makes a sentence card', (tester) async {
      await openPage(tester, [const Result.success([])]);

      await openSheet(tester);
      await fill(tester, {
        'example': '¿Me pasas la sal?',
        'translation': 'Can you pass me the salt?',
      });
      await tester.tap(find.text('Add word'));
      await tester.pumpAndSettle();

      final added = vocabulary.addedWords.single.word;
      expect(added.questionShort, isNull);
      expect(added.answerShort, isNull);
      expect(find.text('¿Me pasas la sal?'), findsOneWidget);
    });

    testWidgets('asks for the example and its translation', (tester) async {
      await openPage(tester, [const Result.success([])]);

      await openSheet(tester);
      await tester.tap(find.text('Add word'));
      await tester.pumpAndSettle();
      expect(find.text('Add an example sentence.'), findsOneWidget);

      await fill(tester, {'example': '¿Me pasas la sal?'});
      await tester.tap(find.text('Add word'));
      await tester.pumpAndSettle();
      expect(find.text('Add its translation.'), findsOneWidget);

      expect(vocabulary.addedWords, isEmpty);
    });

    testWidgets('explains a sentence already in the deck', (tester) async {
      await openPage(tester, [const Result.success([])]);
      vocabulary.addWordResults.add(
        const Result.failure(
          ServerFailure(
            'Question examples already in this deck: "¿Me pasas la sal?".',
            statusCode: 409,
            code: 'question_examples_taken',
          ),
        ),
      );

      await openSheet(tester);
      await fill(tester, {
        'example': '¿Me pasas la sal?',
        'translation': 'Can you pass me the salt?',
      });
      await tester.tap(find.text('Add word'));
      await tester.pumpAndSettle();

      expect(
        find.text('This example sentence is already in the deck.'),
        findsOneWidget,
      );
      expect(find.text('Add word'), findsOneWidget, reason: 'still open');
    });
  });

  group('editing', () {
    const pan = VocabWord(
      id: 'es-pan',
      deckId: 'es-food',
      questionShort: 'el pan',
      answerShort: 'bread',
      questionExample: 'Compro pan cada mañana.',
      answerExample: 'I buy bread every morning.',
      showsCount: 4,
      successesCount: 3,
      failuresCount: 1,
    );

    Future<void> openEditor(WidgetTester tester) async {
      await openPage(tester, [
        const Result.success([pan, _sentence]),
      ]);
      await tester.tap(find.byKey(const Key('word-es-pan')));
      await tester.pumpAndSettle();
    }

    String fieldText(WidgetTester tester, String key) => tester
        .widget<TextField>(
          find.descendant(
            of: find.byKey(Key('word-form-$key')),
            matching: find.byType(TextField),
          ),
        )
        .controller!
        .text;

    Future<void> expand(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('word-form-more')));
      await tester.pumpAndSettle();
    }

    testWidgets('tapping a word opens it, filled in', (tester) async {
      await openEditor(tester);

      expect(find.text('Edit word'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      // The word and meaning start hidden, but the row says what they hold.
      expect(find.byKey(const Key('word-form-word')), findsNothing);
      expect(find.text('el pan · bread'), findsOneWidget);

      await expand(tester);
      expect(fieldText(tester, 'word'), 'el pan');
      expect(fieldText(tester, 'meaning'), 'bread');
      expect(fieldText(tester, 'example'), 'Compro pan cada mañana.');
      expect(fieldText(tester, 'translation'), 'I buy bread every morning.');
    });

    testWidgets('saving updates the word in place', (tester) async {
      await openEditor(tester);
      await expand(tester);

      await tester.enterText(
        find.byKey(const Key('word-form-meaning')),
        'bread, loaf',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Edit word'), findsNothing, reason: 'sheet closed');
      expect(find.text('bread, loaf'), findsOneWidget);
      expect(find.text('Saved “el pan”'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget, reason: 'counters kept');

      final edit = vocabulary.editedWords.single;
      expect(edit.word, pan);
      expect(edit.draft.answerShort, 'bread, loaf');
      expect(edit.draft.questionShort, 'el pan');
    });

    testWidgets('saving without changes asks nothing of the service', (
      tester,
    ) async {
      await openEditor(tester);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Edit word'), findsNothing);
      expect(vocabulary.editedWords, isEmpty);
      expect(find.textContaining('Saved'), findsNothing);
    });

    testWidgets('clearing the word turns it into a sentence card', (
      tester,
    ) async {
      await openEditor(tester);
      await expand(tester);

      await tester.enterText(find.byKey(const Key('word-form-word')), '  ');
      await tester.enterText(find.byKey(const Key('word-form-meaning')), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final draft = vocabulary.editedWords.single.draft;
      expect(draft.questionShort, isNull);
      expect(draft.answerShort, isNull);
      expect(find.text('Compro pan cada mañana.'), findsOneWidget);
    });

    testWidgets('explains a sentence another word already has', (tester) async {
      vocabulary = FakeVocabularyRepository();
      await openEditor(tester);
      vocabulary.editWordResults.add(
        const Result.failure(
          ServerFailure(
            'Another word in this deck has that example.',
            statusCode: 409,
            code: 'question_example_taken',
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('word-form-example')),
        '¿Me pasas la sal?',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('This example sentence is already in the deck.'),
        findsOneWidget,
      );
      expect(find.text('Edit word'), findsOneWidget, reason: 'still open');
    });
  });
}
