import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/settings/domain/entities/study_preferences.dart';
import 'package:lexico/features/settings/domain/repositories/settings_repository.dart';

class GetStudyPreferences implements UseCase<StudyPreferences, NoParams> {
  const GetStudyPreferences(this._repository);

  final SettingsRepository _repository;

  @override
  Future<Result<StudyPreferences>> call(NoParams params) =>
      _repository.studyPreferences();
}
