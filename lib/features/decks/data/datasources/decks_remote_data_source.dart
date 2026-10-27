import 'package:dio/dio.dart';
import 'package:lexico/core/error/exception.dart';
import 'package:lexico/core/network/guard_request.dart';
import 'package:lexico/features/decks/data/models/deck_dto.dart';

abstract interface class DecksRemoteDataSource {
  /// `GET /decks` → `{ "decks": [ … ] }`, oldest first.
  Future<List<DeckDto>> fetchDecks();

  /// `POST /decks` with `{ "id", "name", "language" }` →
  /// `201 { "deck": … }`. A deck with [id] already there is refused with
  /// `deck_id_taken`.
  Future<DeckDto> createDeck({
    required String id,
    required String name,
    required String language,
  });

  /// `PATCH /decks/{deckId}` with `{ "name"?, "language"? }` →
  /// `{ "deck": … }`. Only the fields given are sent; at least one is
  /// needed. A deck that isn't there is refused with `deck_not_found`.
  Future<DeckDto> editDeck(String deckId, {String? name, String? language});

  /// `DELETE /decks/{deckId}` → `204`, no body. Deletes the deck and all of
  /// its words. A deck that isn't there is refused with `deck_not_found`.
  Future<void> deleteDeck(String deckId);
}

class DecksRemoteDataSourceImpl implements DecksRemoteDataSource {
  const DecksRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<DeckDto>> fetchDecks() => guardRequest(() async {
    final response = await _dio.get<Map<String, dynamic>>('/decks');
    final decks = response.data?['decks'];
    if (decks is! List) {
      throw const ServerException('Decks response had no "decks" list.');
    }
    try {
      return decks
          .cast<Map<String, dynamic>>()
          .map(DeckDto.fromJson)
          .toList(growable: false);
    } on FormatException catch (error) {
      throw ServerException('A deck had an unreadable date: $error');
    }
  });

  @override
  Future<DeckDto> createDeck({
    required String id,
    required String name,
    required String language,
  }) => guardRequest(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/decks',
      data: {'id': id, 'name': name, 'language': language},
    );
    final deck = response.data?['deck'];
    if (deck is! Map<String, dynamic>) {
      throw const ServerException('Create response had no "deck".');
    }
    try {
      return DeckDto.fromJson(deck);
    } on FormatException catch (error) {
      throw ServerException('The new deck had an unreadable date: $error');
    }
  });

  @override
  Future<DeckDto> editDeck(String deckId, {String? name, String? language}) =>
      guardRequest(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          '/decks/${Uri.encodeComponent(deckId)}',
          data: {'name': ?name, 'language': ?language},
        );
        final deck = response.data?['deck'];
        if (deck is! Map<String, dynamic>) {
          throw const ServerException('Edit response had no "deck".');
        }
        try {
          return DeckDto.fromJson(deck);
        } on FormatException catch (error) {
          throw ServerException(
            'The edited deck had an unreadable date: $error',
          );
        }
      });

  @override
  Future<void> deleteDeck(String deckId) => guardRequest(
    () => _dio.delete<void>('/decks/${Uri.encodeComponent(deckId)}'),
  );
}
