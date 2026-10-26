import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:lexico/core/error/exception.dart';
import 'package:lexico/features/decks/data/datasources/decks_local_data_source.dart';
import 'package:lexico/features/decks/data/datasources/decks_remote_data_source.dart';
import 'package:lexico/features/decks/data/mappers/deck_mappers.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/local_transaction.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/pending_changes_local_data_source.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/vocabulary_local_data_source.dart';
import 'package:lexico/features/vocabulary/data/datasources/remote/vocabulary_remote_data_source.dart';
import 'package:lexico/features/vocabulary/data/mappers/vocabulary_mappers.dart';
import 'package:lexico/features/vocabulary/data/models/pending_change.dart';
import 'package:lexico/features/vocabulary/data/models/word_dto.dart';
import 'package:lexico/features/vocabulary/domain/entities/sync_conflict.dart';
import 'package:lexico/features/vocabulary/domain/entities/word_draft.dart';

/// Keeps the device and the word service in step. The device is the source
/// of truth for the app: every change is stored locally first and queued,
/// and this class sends the queue, then pulls the service's copy over the
/// stored one.
///
/// Rules:
/// - Changes are sent oldest first. Sending stops at the first one that
///   can't get through, so a word is never sent before its deck.
/// - A change the service refuses (a 4xx) is dropped, its deck is pulled
///   back in line with the service, and the refusal is published on
///   [conflicts] so the learner can be told.
/// - A deck with changes still waiting is never overwritten by a pull.
/// - An answer that may have reached the service is never sent again, since
///   the service counts every answer.
///
/// Every sync step runs one at a time, so a pull never interleaves with a
/// push. Waiting changes go out as soon as the device comes back online.
class SyncEngine {
  SyncEngine({
    required VocabularyRemoteDataSource wordsRemote,
    required DecksRemoteDataSource decksRemote,
    required VocabularyLocalDataSource local,
    required DecksLocalDataSource decksLocal,
    required PendingChangesLocalDataSource pending,
    required LocalTransaction transaction,
    DateTime Function() clock = DateTime.now,
    List<Duration> retryDelays = defaultRetryDelays,
    int maxAttempts = 5,
    Stream<bool> onlineChanges = const Stream.empty(),
  }) : _wordsRemote = wordsRemote,
       _decksRemote = decksRemote,
       _local = local,
       _decksLocal = decksLocal,
       _pending = pending,
       _transaction = transaction,
       _clock = clock,
       _retryDelays = retryDelays,
       _maxAttempts = maxAttempts {
    _onlineChanges = onlineChanges.listen((online) {
      if (!online) return;
      // A fresh connection: try now rather than wait out the back-off.
      _clearRetry();
      schedulePush();
    });
  }

  /// How long to wait before trying again after a push could not get
  /// through, growing with each failure in a row. The last one repeats.
  static const List<Duration> defaultRetryDelays = [
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
  ];

  final VocabularyRemoteDataSource _wordsRemote;
  final DecksRemoteDataSource _decksRemote;
  final VocabularyLocalDataSource _local;
  final DecksLocalDataSource _decksLocal;
  final PendingChangesLocalDataSource _pending;
  final LocalTransaction _transaction;
  final DateTime Function() _clock;
  final List<Duration> _retryDelays;

  /// Server errors after which a change is given up on.
  final int _maxAttempts;

  late final StreamSubscription<bool> _onlineChanges;
  final StreamController<SyncConflict> _conflicts =
      StreamController.broadcast();
  Future<void> _tail = Future.value();
  Future<bool>? _queuedPush;
  Timer? _retryTimer;
  int _retriesInARow = 0;
  bool _disposed = false;

  /// Changes the service refused, published once the device has been
  /// brought back in line with it. Answers to cards are left out: a lost
  /// answer only costs the service's counters.
  Stream<SyncConflict> get conflicts => _conflicts.stream;

  /// Sends every waiting change. Completes with `true` once nothing is left
  /// waiting, or `false` when the rest has to wait for a later try, which is
  /// then scheduled on its own. Calls made while a push is waiting to start
  /// share it.
  ///
  /// Throws a [CacheException] only.
  Future<bool> push() => _queuedPush ??= _serialized(() {
    _queuedPush = null;
    return _drain();
  });

  /// Starts a [push] without waiting for it. Used after every local change.
  void schedulePush() {
    if (_disposed) return;
    unawaited(
      push().then<void>(
        (_) {},
        onError: (Object error) =>
            debugPrint('Léxico: could not send changes — $error'),
      ),
    );
  }

  /// Sends waiting changes, then stores the service's deck list. Decks the
  /// service no longer has are removed from the device, unless they have
  /// changes waiting.
  ///
  /// Throws an [AppException] when the list can't be fetched or stored.
  Future<void> refreshDecks() => _serialized(() async {
    await _drain();
    final decks = await _decksRemote.fetchDecks();
    await _transaction(() async {
      await _decksLocal.saveDecks([for (final deck in decks) deck.toRow()]);
      final keep = {
        for (final deck in decks) deck.id,
        ...await _pending.deckIds(),
      };
      for (final id in await _decksLocal.deckIds()) {
        if (!keep.contains(id)) await _local.deleteDeck(id);
      }
    });
  });

  /// Sends waiting changes, then stores the service's copy of [deckId]. A
  /// deck with changes still waiting is left as it is.
  ///
  /// Throws an [AppException] when the deck can't be fetched or stored. A
  /// deck the service no longer has is removed from the device first.
  Future<void> refreshDeck(String deckId) => _serialized(() async {
    await _drain();
    await _pullDeck(deckId);
  });

  /// Sends waiting changes, then refreshes every studied deck. A deck that
  /// can't be fetched keeps what is stored; once the service is found
  /// unreachable the remaining decks aren't tried.
  ///
  /// Throws a [CacheException] only.
  Future<void> refreshStudiedDecks() => _serialized(() async {
    await _drain();
    for (final deckId in await _local.studiedDeckIds()) {
      try {
        await _pullDeck(deckId);
      } on NetworkException catch (error) {
        debugPrint('Léxico: kept stored decks — ${error.message}');
        return;
      } on ServerException catch (error) {
        debugPrint('Léxico: kept stored words for $deckId — ${error.message}');
      }
    }
  });

  /// Stops retrying. Changes still waiting are sent by the next push.
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    unawaited(_onlineChanges.cancel());
    unawaited(_conflicts.close());
  }

  Future<void> _pullDeck(String deckId) async {
    if (await _pending.hasChangesFor(deckId)) return;

    final List<WordDto> words;
    try {
      words = await _wordsRemote.fetchWords(deckId);
    } on ServerException catch (error) {
      if (error.code == 'deck_not_found') {
        debugPrint('Léxico: removed stored deck $deckId — ${error.message}');
        await _transaction(() async {
          if (!await _pending.hasChangesFor(deckId)) {
            await _local.deleteDeck(deckId);
          }
        });
      }
      rethrow;
    }

    // An empty reply keeps what is stored rather than leaving nothing to
    // study.
    if (words.isEmpty) return;

    // Checked again in the same transaction: a change may have been made
    // while the words were on their way.
    await _transaction(() async {
      if (await _pending.hasChangesFor(deckId)) return;
      await _local.replaceDeck(deckId, deckRows(deckId, words), _clock());
    });
  }

  Future<bool> _drain() async {
    final refused = <_Refusal>[];
    final allSent = await _sendAll(refused);
    if (refused.isNotEmpty) await _settle(refused);
    return allSent;
  }

  /// Pulls the decks of [refused] changes so the device matches the service
  /// again, then tells the learner what was lost.
  Future<void> _settle(List<_Refusal> refused) async {
    try {
      for (final deckId in {for (final r in refused) r.change.deckId}) {
        try {
          await _pullDeck(deckId);
        } on CacheException {
          rethrow;
        } on AppException catch (error) {
          debugPrint('Léxico: could not re-sync $deckId — ${error.message}');
        }
      }
    } finally {
      for (final refusal in refused) {
        final conflict = _conflictFor(refusal);
        if (conflict != null && !_conflicts.isClosed) _conflicts.add(conflict);
      }
    }
  }

  SyncConflict? _conflictFor(_Refusal refusal) {
    final error = refusal.error;
    final reason = switch (error.code) {
      'question_examples_taken' ||
      'question_example_taken' ||
      'duplicate_question_examples' => SyncConflictReason.duplicateExample,
      'deck_not_found' => SyncConflictReason.deckGone,
      'word_not_found' => SyncConflictReason.wordGone,
      _ => SyncConflictReason.refused,
    };
    final (change, subject) = switch (refusal.change) {
      DeckCreated(:final name) => (SyncedChange.deckCreated, name),
      WordAdded(:final draft) => (SyncedChange.wordAdded, draft.subject),
      WordEdited(:final draft) => (SyncedChange.wordEdited, draft.subject),
      WordReviewed() => (null, ''),
    };
    if (change == null) return null;
    return SyncConflict(
      change: change,
      reason: reason,
      deckId: refusal.change.deckId,
      subject: subject,
      serverMessage: error.message,
    );
  }

  Future<bool> _sendAll(List<_Refusal> refused) async {
    while (true) {
      final next = await _pending.oldest();
      if (next == null) {
        _clearRetry();
        return true;
      }

      final (outcome, refusal) = await _send(next.change);
      switch (outcome) {
        case _Outcome.refused:
          debugPrint(
            'Léxico: ${next.change.kind} refused — ${refusal!.message}',
          );
          refused.add((change: next.change, error: refusal));
          await _pending.remove(next.id);
        case _Outcome.done:
          await _pending.remove(next.id);
        case _Outcome.retry when next.attempts + 1 >= _maxAttempts:
          debugPrint('Léxico: gave up sending ${next.change.kind}.');
          await _pending.remove(next.id);
        case _Outcome.retry:
          await _pending.markFailed(next.id);
          _scheduleRetry();
          return false;
        case _Outcome.offline:
          _scheduleRetry();
          return false;
      }
    }
  }

  Future<(_Outcome, ServerException?)> _send(PendingChange change) async {
    try {
      switch (change) {
        case DeckCreated(:final deckId, :final name, :final language):
          await _decksRemote.createDeck(
            id: deckId,
            name: name,
            language: language,
          );
        case WordAdded(:final deckId, :final wordId, :final draft):
          await _wordsRemote.addWords(deckId, [(id: wordId, draft: draft)]);
        case WordEdited(:final wordId, :final draft):
          await _wordsRemote.editWord(wordId, draft);
        case WordReviewed(:final wordId, :final correct):
          await _wordsRemote.submitReview(wordId, correct: correct);
      }
      return (_Outcome.done, null);
    } on NetworkException catch (error) {
      if (change is WordReviewed && error.mayHaveArrived) {
        debugPrint(
          'Léxico: answer to ${change.wordId} may not have been counted — '
          '${error.message}',
        );
        return (_Outcome.done, null);
      }
      return (_Outcome.offline, null);
    } on ServerException catch (error) {
      return (_judge(change, error), error);
    }
  }

  /// What to do with a change the service answered with an error.
  _Outcome _judge(PendingChange change, ServerException error) {
    final status = error.statusCode;

    // No status: the service accepted the change, but its reply could not
    // be read.
    if (status == null) return _Outcome.done;

    // The id is taken: an earlier attempt got through.
    if ((change is DeckCreated && error.code == 'deck_id_taken') ||
        (change is WordAdded && error.code == 'word_ids_taken')) {
      return _Outcome.done;
    }

    if (status == 408 || status == 429 || status >= 500) return _Outcome.retry;

    return _Outcome.refused;
  }

  void _scheduleRetry() {
    if (_disposed || _retryDelays.isEmpty || _retryTimer != null) return;
    final delay = _retryDelays[min(_retriesInARow, _retryDelays.length - 1)];
    _retriesInARow++;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      schedulePush();
    });
  }

  void _clearRetry() {
    _retriesInARow = 0;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Runs [body] after every step started before it has finished.
  Future<T> _serialized<T>(Future<T> Function() body) {
    final result = _tail.then((_) => body());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}

typedef _Refusal = ({PendingChange change, ServerException error});

enum _Outcome {
  /// Sent: remove it from the queue.
  done,

  /// Refused for good: remove it from the queue and tell the learner.
  refused,

  /// The service failed; try again later.
  retry,

  /// The service could not be reached; try again later.
  offline,
}

extension on WordDraft {
  /// How the learner knows the word.
  String get subject => questionShort ?? questionExample;
}
