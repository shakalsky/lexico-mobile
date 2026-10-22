import 'package:equatable/equatable.dart';

/// A named collection of words on the word service.
class Deck extends Equatable {
  const Deck({
    required this.id,
    required this.name,
    required this.language,
    required this.createdAt,
  });

  final String id;

  /// Shown to the learner, e.g. `Food`.
  final String name;

  /// Display label of the language being learned, e.g. `Español`.
  final String language;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, name, language, createdAt];
}
