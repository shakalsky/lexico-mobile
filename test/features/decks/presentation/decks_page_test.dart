import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/core/error/failure.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/theme/app_theme.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/domain/usecases/create_deck.dart';
import 'package:lexico/features/decks/domain/usecases/delete_deck.dart';
import 'package:lexico/features/decks/domain/usecases/edit_deck.dart';
import 'package:lexico/features/decks/domain/usecases/get_decks.dart';
import 'package:lexico/features/decks/domain/usecases/refresh_decks.dart';
import 'package:lexico/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:lexico/features/decks/presentation/pages/decks_page.dart';
import 'package:lexico/features/vocabulary/domain/usecases/add_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/delete_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/edit_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/get_deck_words.dart';
import 'package:lexico/features/vocabulary/domain/usecases/get_studied_deck_ids.dart';
import 'package:lexico/features/vocabulary/domain/usecases/refresh_deck_words.dart';
import 'package:lexico/features/vocabulary/domain/usecases/set_deck_studied.dart';
import 'package:lexico/features/vocabulary/domain/usecases/watch_sync_conflicts.dart';

import '../../../helpers/fake_decks_repository.dart';
import '../../../helpers/fake_vocabulary_repository.dart';
import '../../../helpers/fixtures.dart';

final Deck _core = testDeckEntity('es-en-core', name: 'Core');
final Deck _food = testDeckEntity('es-food', name: 'Food', day: 9);

void main() {
  late FakeDecksRepository repository;
  late FakeVocabularyRepository vocabulary;

  /// The spinner animates forever, so `pumpAndSettle` would never return.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpDecks(
    WidgetTester tester, {
    required List<Result<List<Deck>>> decks,
    List<Result<Deck>>? created,
  }) async {
    repository = FakeDecksRepository(decks: decks, created: created);
    vocabulary = FakeVocabularyRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BlocProvider(
          create: (_) => DecksBloc(
            getDecks: GetDecks(repository),
            refreshDecks: RefreshDecks(repository),
            getStudiedDeckIds: GetStudiedDeckIds(vocabulary),
            setDeckStudied: SetDeckStudied(vocabulary),
            deleteDeck: DeleteDeck(repository),
          )..add(const DecksRequested()),
          child: DecksView(
            createDeck: CreateDeck(repository),
            editDeck: EditDeck(repository),
            getDeckWords: GetDeckWords(vocabulary),
            refreshDeckWords: RefreshDeckWords(vocabulary),
            watchSyncConflicts: WatchSyncConflicts(vocabulary),
            addWord: AddWord(vocabulary),
            editWord: EditWord(vocabulary),
            deleteWord: DeleteWord(vocabulary),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('lists every deck with its study switch', (tester) async {
    await pumpDecks(
      tester,
      decks: [
        Result.success([_core, _food]),
      ],
    );

    expect(find.text('Core'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Español · added Oct 8, 2026'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('study-es-en-core')),
        matching: find.text('Studying'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('study-es-food')),
        matching: find.text('Study'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the switch turns studying on and off', (tester) async {
    await pumpDecks(
      tester,
      decks: [
        Result.success([_core, _food]),
      ],
    );

    await tester.tap(find.byKey(const Key('study-es-food')));
    await settle(tester);
    expect(find.text('Studying'), findsNWidgets(2));
    expect(vocabulary.studiedIds, {'es-en-core', 'es-food'});

    await tester.tap(find.byKey(const Key('study-es-en-core')));
    await settle(tester);
    expect(find.text('Studying'), findsOneWidget);
    expect(vocabulary.studiedIds, {'es-food'});
  });

  testWidgets('tapping a deck opens its words', (tester) async {
    await pumpDecks(
      tester,
      decks: [
        Result.success([_core, _food]),
      ],
    );
    vocabulary.deckWordResults['es-food'] = [
      Result.success([
        testWord(id: 'es-pan', question: 'el pan', answer: 'bread'),
      ]),
    ];

    await tester.tap(find.byKey(const Key('deck-es-food')));
    await tester.pumpAndSettle();

    expect(find.text('el pan'), findsOneWidget);
    expect(find.text('bread'), findsOneWidget);
    expect(find.text('Español · 1 word'), findsOneWidget);
  });

  testWidgets('tapping the study button does not open the deck', (
    tester,
  ) async {
    await pumpDecks(
      tester,
      decks: [
        Result.success([_food]),
      ],
    );

    await tester.tap(find.byKey(const Key('study-es-food')));
    await tester.pumpAndSettle();

    expect(vocabulary.deckWordCalls, 0);
    expect(find.byKey(const Key('deck-es-food')), findsOneWidget);
  });

  testWidgets('a failed switch flips back and says why', (tester) async {
    await pumpDecks(
      tester,
      decks: [
        Result.success([_core, _food]),
      ],
    );
    vocabulary.setStudiedFailure = const CacheFailure('disk full');

    await tester.tap(find.byKey(const Key('study-es-food')));
    await settle(tester);

    expect(find.text('Studying'), findsOneWidget);
    expect(find.text("Couldn't save: disk full"), findsOneWidget);
  });

  group('swipe left to delete', () {
    Future<void> swipe(WidgetTester tester) async {
      await tester.drag(
        find.byKey(const Key('deck-es-food')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('asks first, then deletes the deck', (tester) async {
      await pumpDecks(
        tester,
        decks: [
          Result.success([_core, _food]),
        ],
      );

      await swipe(tester);
      expect(find.text('Delete deck?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm-delete')));
      await tester.pumpAndSettle();

      expect(repository.deleted, [_food]);
      expect(find.byKey(const Key('deck-es-food')), findsNothing);
      expect(find.byKey(const Key('deck-es-en-core')), findsOneWidget);
      expect(find.text('Deleted “Food”'), findsOneWidget);
      // Let the notice time out.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('keeps the deck when cancelled', (tester) async {
      await pumpDecks(
        tester,
        decks: [
          Result.success([_core, _food]),
        ],
      );

      await swipe(tester);
      await tester.tap(find.byKey(const Key('confirm-delete-cancel')));
      await tester.pumpAndSettle();

      expect(repository.deleted, isEmpty);
      expect(find.byKey(const Key('deck-es-food')), findsOneWidget);
    });
  });

  testWidgets('says so when there are no decks', (tester) async {
    await pumpDecks(tester, decks: [const Result.success([])]);

    expect(find.text('No decks yet'), findsOneWidget);
  });

  testWidgets('offers a retry when loading fails', (tester) async {
    await pumpDecks(
      tester,
      decks: [
        const Result.failure(NetworkFailure('No connection.')),
        Result.success([_food]),
      ],
    );

    expect(find.text("Couldn't load decks"), findsOneWidget);
    expect(find.text('No connection.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await settle(tester);

    expect(find.text('Food'), findsOneWidget);
    expect(repository.refreshCalls, 2);
  });

  testWidgets('pulling down reloads the list', (tester) async {
    await pumpDecks(
      tester,
      decks: [
        Result.success([_core]),
        Result.success([_core, _food]),
      ],
    );
    expect(find.text('Food'), findsNothing);

    await tester.fling(find.text('Core'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsOneWidget);
    expect(repository.refreshCalls, 2);
  });

  group('new deck', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('new-deck')));
      await tester.pumpAndSettle();
    }

    testWidgets('creates a deck and adds it to the list', (tester) async {
      await pumpDecks(
        tester,
        decks: [
          Result.success([_core]),
        ],
        created: [Result.success(_food)],
      );

      await openSheet(tester);
      expect(find.text('New deck'), findsWidgets);

      await tester.enterText(find.byKey(const Key('new-deck-name')), 'Food');
      await tester.tap(find.text('Create deck'));
      await tester.pumpAndSettle();

      expect(find.text('Create deck'), findsNothing, reason: 'sheet closed');
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Created “Food”'), findsOneWidget);
      expect(repository.createCalls, [(name: 'Food', language: 'English')]);
      expect(repository.refreshCalls, 1, reason: 'no reload needed');
    });

    testWidgets('sends the language picked from the menu', (tester) async {
      await pumpDecks(
        tester,
        decks: [const Result.success([])],
        created: [Result.success(_food)],
      );

      await openSheet(tester);
      expect(find.text('English'), findsOneWidget, reason: 'the default');

      await tester.tap(find.byKey(const Key('new-deck-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Polski').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('new-deck-name')), 'Food');
      await tester.tap(find.text('Create deck'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, [(name: 'Food', language: 'Polski')]);
    });

    testWidgets('keeps the sheet open and explains a failure', (tester) async {
      await pumpDecks(
        tester,
        decks: [
          Result.success([_core]),
        ],
        created: [const Result.failure(NetworkFailure('No connection.'))],
      );

      await openSheet(tester);
      await tester.enterText(find.byKey(const Key('new-deck-name')), 'Food');
      await tester.tap(find.text('Create deck'));
      await tester.pumpAndSettle();

      expect(find.text('No connection.'), findsOneWidget);
      expect(find.text('Create deck'), findsOneWidget);
    });

    testWidgets('asks for a name', (tester) async {
      await pumpDecks(tester, decks: [const Result.success([])]);

      await openSheet(tester);
      await tester.tap(find.text('Create deck'));
      await tester.pumpAndSettle();

      expect(find.text('Give the deck a name.'), findsOneWidget);
      expect(repository.createCalls, isEmpty);
    });

    testWidgets('closing the sheet changes nothing', (tester) async {
      await pumpDecks(
        tester,
        decks: [
          Result.success([_core]),
        ],
      );

      await openSheet(tester);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.text('Create deck'), findsNothing);
      expect(find.text('Core'), findsOneWidget);
      expect(repository.createCalls, isEmpty);
    });
  });

  group('long press to edit', () {
    /// What each haptic call asked for; `null` is Android's long-press one.
    late List<Object?> haptics;

    setUp(() {
      haptics = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              haptics.add(call.arguments);
            }
            return null;
          });
    });

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    double scaleOf(WidgetTester tester, String deckId) => tester
        .widget<ScaleTransition>(
          find.descendant(
            of: find.byKey(Key('deck-$deckId')),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;

    Future<void> openSheet(WidgetTester tester) async {
      await tester.longPress(find.byKey(const Key('deck-es-food')));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'the tile shrinks while held, then buzzes and opens the sheet',
      (tester) async {
        await pumpDecks(
          tester,
          decks: [
            Result.success([_core, _food]),
          ],
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const Key('deck-es-food'))),
        );
        await tester.pump(); // Starts the animation's clock.
        await tester.pump(const Duration(milliseconds: 300));
        expect(scaleOf(tester, 'es-food'), lessThan(1));
        expect(haptics, isEmpty);

        await tester.pump(const Duration(milliseconds: 300));
        expect(haptics, hasLength(1));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.text('Edit deck'), findsOneWidget);
        expect(scaleOf(tester, 'es-food'), 1, reason: 'sprang back');
        final field = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const Key('edit-deck-name')),
            matching: find.byType(TextField),
          ),
        );
        expect(field.controller!.text, 'Food');
      },
    );

    testWidgets('letting go early neither buzzes nor opens the sheet', (
      tester,
    ) async {
      await pumpDecks(
        tester,
        decks: [
          Result.success([_core, _food]),
        ],
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('deck-es-food'))),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await settle(tester);

      expect(find.text('Edit deck'), findsNothing);
      expect(haptics, isEmpty);
    });

    testWidgets('saves the new name and shows it in the list', (tester) async {
      await pumpDecks(
        tester,
        decks: [
          Result.success([_core, _food]),
        ],
      );

      await openSheet(tester);
      await tester.enterText(
        find.byKey(const Key('edit-deck-name')),
        '  Food and drink ',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Edit deck'), findsNothing, reason: 'sheet closed');
      expect(find.text('Food and drink'), findsOneWidget);
      expect(find.text('Saved “Food and drink”'), findsOneWidget);
      expect(repository.editCalls, [
        (id: 'es-food', name: 'Food and drink', language: 'Español'),
      ]);
    });

    testWidgets('changes the language from the menu', (tester) async {
      await pumpDecks(
        tester,
        decks: [
          Result.success([_food]),
        ],
      );

      await openSheet(tester);
      expect(
        find.descendant(
          of: find.byKey(const Key('edit-deck-language')),
          matching: find.text('Español'),
        ),
        findsOneWidget,
        reason: 'the deck language is offered though it is not built in',
      );

      await tester.tap(find.byKey(const Key('edit-deck-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Polski').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Español · added Oct 9, 2026'), findsNothing);
      expect(find.text('Polski · added Oct 9, 2026'), findsOneWidget);
      expect(repository.editCalls, [
        (id: 'es-food', name: 'Food', language: 'Polski'),
      ]);
    });

    testWidgets('keeping the name closes the sheet without saving', (
      tester,
    ) async {
      await pumpDecks(
        tester,
        decks: [
          Result.success([_core, _food]),
        ],
      );

      await openSheet(tester);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Edit deck'), findsNothing);
      expect(find.textContaining('Saved'), findsNothing);
      expect(repository.editCalls, isEmpty);
    });

    testWidgets('asks for a name', (tester) async {
      await pumpDecks(
        tester,
        decks: [
          Result.success([_food]),
        ],
      );

      await openSheet(tester);
      await tester.enterText(find.byKey(const Key('edit-deck-name')), '  ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Give the deck a name.'), findsOneWidget);
      expect(repository.editCalls, isEmpty);
    });

    testWidgets('keeps the sheet open and explains a failure', (tester) async {
      await pumpDecks(
        tester,
        decks: [
          Result.success([_food]),
        ],
      );
      repository.editFailure = const CacheFailure('Disk full.');

      await openSheet(tester);
      await tester.enterText(find.byKey(const Key('edit-deck-name')), 'Meals');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Disk full.'), findsOneWidget);
      expect(find.text('Edit deck'), findsOneWidget);
    });
  });
}
