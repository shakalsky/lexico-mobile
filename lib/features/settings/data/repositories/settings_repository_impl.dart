import 'package:lexico/core/error/exception.dart';
import 'package:lexico/core/error/exception_mapper.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/features/settings/data/datasources/settings_local_data_source.dart';
import 'package:lexico/features/settings/domain/entities/study_preferences.dart';
import 'package:lexico/features/settings/domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl(this._local);

  final SettingsLocalDataSource _local;

  @override
  Future<Result<StudyPreferences>> studyPreferences() async {
    try {
      const defaults = StudyPreferences();
      final repeat = await _local.repeatMissedWords();
      final count = await _local.wordsPerSession();
      return Result.success(
        StudyPreferences(
          repeatMissedWords: repeat ?? defaults.repeatMissedWords,
          // A value outside the allowed range falls back to the default.
          wordsPerSession:
              count != null && StudyPreferences.isValidWordsPerSession(count)
              ? count
              : defaults.wordsPerSession,
        ),
      );
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }
  }

  @override
  Future<Result<void>> setRepeatMissedWords({required bool enabled}) =>
      _write(() => _local.setRepeatMissedWords(enabled: enabled));

  @override
  Future<Result<void>> setWordsPerSession(int count) =>
      _write(() => _local.setWordsPerSession(count));

  Future<Result<void>> _write(Future<void> Function() body) async {
    try {
      await body();
      return const Result.success(null);
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }
  }
}
