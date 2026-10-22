import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/settings/domain/repositories/settings_repository.dart';

/// Turns "Repeat missed words" on or off. The param is the new value.
class SetRepeatMissedWords implements UseCase<void, bool> {
  const SetRepeatMissedWords(this._repository);

  final SettingsRepository _repository;

  @override
  Future<Result<void>> call(bool enabled) =>
      _repository.setRepeatMissedWords(enabled: enabled);
}
