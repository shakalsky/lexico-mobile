import 'package:lexico/core/result/result.dart';
import 'package:lexico/features/settings/domain/entities/study_preferences.dart';

abstract interface class SettingsRepository {
  /// The stored preferences, or the defaults when nothing was saved yet.
  Future<Result<StudyPreferences>> studyPreferences();

  Future<Result<void>> setRepeatMissedWords({required bool enabled});

  Future<Result<void>> setWordsPerSession(int count);

  Future<Result<void>> setShowMissPictures({required bool enabled});
}
