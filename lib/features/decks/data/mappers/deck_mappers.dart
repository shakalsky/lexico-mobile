import 'package:lexico/features/decks/data/models/deck_dto.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/app_database.dart';

extension DeckDtoMapper on DeckDto {
  DeckRow toRow() =>
      DeckRow(id: id, name: name, language: language, createdAt: createdAt);
}

extension DeckRowMapper on DeckRow {
  Deck toEntity() =>
      Deck(id: id, name: name, language: language, createdAt: createdAt);
}
