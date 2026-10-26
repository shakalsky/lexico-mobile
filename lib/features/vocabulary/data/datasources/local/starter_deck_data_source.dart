import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:lexico/core/error/exception.dart';
import 'package:lexico/features/vocabulary/data/models/word_dto.dart';

/// The deck bundled with the app, used the first time the device runs while
/// the word service is unreachable. Without it a fresh offline install would
/// have nothing to study.
abstract interface class StarterDeckDataSource {
  Future<StarterDeck> load();
}

/// The bundled deck's details and words.
class StarterDeck {
  const StarterDeck({
    required this.name,
    required this.language,
    required this.words,
  });

  final String name;
  final String language;
  final List<WordDto> words;
}

class StarterDeckAssetDataSource implements StarterDeckDataSource {
  const StarterDeckAssetDataSource({
    this.assetPath = 'assets/decks/es_en_core.json',
    AssetBundle? bundle,
  }) : _bundle = bundle;

  final String assetPath;
  final AssetBundle? _bundle;

  @override
  Future<StarterDeck> load() async {
    try {
      final raw = await (_bundle ?? rootBundle).loadString(assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['words'] is! List) {
        throw const CacheException('Starter deck asset is malformed.');
      }

      // Named like the service names a seeded deck without a name.
      final id = decoded['deck_id'] as String;
      return StarterDeck(
        name: decoded['name'] as String? ?? id,
        language: decoded['language'] as String,
        words: (decoded['words'] as List)
            .whereType<Map<String, dynamic>>()
            .map(WordDto.fromJson)
            .toList(growable: false),
      );
    } on CacheException {
      rethrow;
    } catch (error) {
      throw CacheException('Could not read the starter deck: $error');
    }
  }
}
