import 'package:lexico/core/error/failure.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/settings/domain/entities/study_preferences.dart';
import 'package:lexico/features/settings/domain/repositories/settings_repository.dart';

/// Saves how many cards a study session deals. The param is the new count.
class SetWordsPerSession implements UseCase<void, int> {
  const SetWordsPerSession(this._repository);

  final SettingsRepository _repository;

  @override
  Future<Result<void>> call(int count) async {
    if (!StudyPreferences.isValidWordsPerSession(count)) {
      return Result.failure(
        ValidationFailure(
          'Pick between ${StudyPreferences.minWordsPerSession} and '
          '${StudyPreferences.maxWordsPerSession} words.',
        ),
      );
    }
    return _repository.setWordsPerSession(count);
  }
}
