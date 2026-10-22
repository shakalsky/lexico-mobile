import 'package:lexico/features/decks/domain/entities/deck.dart';

/// Wire format of one deck, as served by `GET /decks`.
///
/// ```json
/// {
///   "id": "es-food",
///   "name": "Food",
///   "language": "Español",
///   "created_at": "2026-10-08T09:12:59.649Z"
/// }
/// ```
class DeckDto {
  const DeckDto({
    required this.id,
    required this.name,
    required this.language,
    required this.createdAt,
  });

  /// Throws a [TypeError] or [FormatException] when a field is missing or
  /// mistyped.
  factory DeckDto.fromJson(Map<String, dynamic> json) => DeckDto(
    id: json['id'] as String,
    name: json['name'] as String,
    language: json['language'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final String id;
  final String name;
  final String language;
  final DateTime createdAt;

  Deck toEntity() =>
      Deck(id: id, name: name, language: language, createdAt: createdAt);
}
