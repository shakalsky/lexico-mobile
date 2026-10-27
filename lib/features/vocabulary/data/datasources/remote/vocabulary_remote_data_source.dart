import 'package:dio/dio.dart';
import 'package:lexico/core/error/exception.dart';
import 'package:lexico/core/network/guard_request.dart';
import 'package:lexico/features/vocabulary/data/models/word_draft_json.dart';
import 'package:lexico/features/vocabulary/data/models/word_dto.dart';
import 'package:lexico/features/vocabulary/domain/entities/word_draft.dart';

/// The parts of the Léxico API the app uses. See `lexico-api/API.md`.
abstract interface class VocabularyRemoteDataSource {
  /// `GET /decks/{deckId}/words` → `{ "words": [ … ] }`, in deck order.
  Future<List<WordDto>> fetchWords(String deckId);

  /// `POST /decks/{deckId}/words` with `{ "words": [ … ] }` →
  /// `201 { "words": [ … ] }`: the created words, in request order. All or
  /// nothing — if one is refused, none are added. Each word keeps the `id`
  /// it was given, so sending the same words again is refused rather than
  /// adding them twice.
  Future<List<WordDto>> addWords(
    String deckId,
    List<({String id, WordDraft draft})> words,
  );

  /// `PATCH /words/{wordId}` with all four text fields → `{ "word": … }`.
  Future<WordDto> editWord(String wordId, WordDraft draft);

  /// `DELETE /words/{wordId}` → `204`, no body. Deletes the word and its
  /// counters.
  Future<void> deleteWord(String wordId);

  /// `POST /words/{wordId}/reviews` with `{ "correct": … }` → `{ "word": … }`.
  ///
  /// Not idempotent: every call is counted, so never retry it blindly.
  Future<WordDto> submitReview(String wordId, {required bool correct});
}

class VocabularyRemoteDataSourceImpl implements VocabularyRemoteDataSource {
  const VocabularyRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<WordDto>> fetchWords(String deckId) => guardRequest(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/decks/${Uri.encodeComponent(deckId)}/words',
    );
    final words = response.data?['words'];
    if (words is! List) {
      throw const ServerException('Deck response had no "words" list.');
    }
    return words
        .cast<Map<String, dynamic>>()
        .map(WordDto.fromJson)
        .toList(growable: false);
  });

  @override
  Future<List<WordDto>> addWords(
    String deckId,
    List<({String id, WordDraft draft})> words,
  ) => guardRequest(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/decks/${Uri.encodeComponent(deckId)}/words',
      data: {
        'words': [
          for (final word in words) {'id': word.id, ...word.draft.toJson()},
        ],
      },
    );
    final created = response.data?['words'];
    if (created is! List) {
      throw const ServerException('Add response had no "words" list.');
    }
    return created
        .cast<Map<String, dynamic>>()
        .map(WordDto.fromJson)
        .toList(growable: false);
  });

  @override
  Future<WordDto> editWord(String wordId, WordDraft draft) =>
      guardRequest(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          '/words/${Uri.encodeComponent(wordId)}',
          data: draft.toJson(),
        );
        final word = response.data?['word'];
        if (word is! Map<String, dynamic>) {
          throw const ServerException('Edit response had no "word".');
        }
        return WordDto.fromJson(word);
      });

  @override
  Future<void> deleteWord(String wordId) => guardRequest(
    () => _dio.delete<void>('/words/${Uri.encodeComponent(wordId)}'),
  );

  @override
  Future<WordDto> submitReview(String wordId, {required bool correct}) =>
      guardRequest(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/words/${Uri.encodeComponent(wordId)}/reviews',
          data: {'correct': correct},
        );
        final word = response.data?['word'];
        if (word is! Map<String, dynamic>) {
          throw const ServerException('Review response had no "word".');
        }
        return WordDto.fromJson(word);
      });
}
