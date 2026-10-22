import 'package:equatable/equatable.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/vocabulary/domain/repositories/vocabulary_repository.dart';

class SetDeckStudiedParams extends Equatable {
  const SetDeckStudiedParams({required this.deckId, required this.studied});

  final String deckId;
  final bool studied;

  @override
  List<Object?> get props => [deckId, studied];
}

/// Switches a deck in or out of the study rotation.
class SetDeckStudied implements UseCase<void, SetDeckStudiedParams> {
  const SetDeckStudied(this._repository);

  final VocabularyRepository _repository;

  @override
  Future<Result<void>> call(SetDeckStudiedParams params) =>
      _repository.setDeckStudied(params.deckId, studied: params.studied);
}
