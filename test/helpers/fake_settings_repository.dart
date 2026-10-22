import 'package:lexico/core/error/failure.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/features/settings/domain/entities/study_preferences.dart';
import 'package:lexico/features/settings/domain/repositories/settings_repository.dart';

/// Keeps the preferences in memory. Set [failure] to make every call fail.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({this.preferences = const StudyPreferences()});

  StudyPreferences preferences;
  Failure? failure;

  @override
  Future<Result<StudyPreferences>> studyPreferences() async {
    final failure = this.failure;
    if (failure != null) return Result.failure(failure);
    return Result.success(preferences);
  }

  @override
  Future<Result<void>> setRepeatMissedWords({required bool enabled}) async {
    final failure = this.failure;
    if (failure != null) return Result.failure(failure);
    preferences = preferences.copyWith(repeatMissedWords: enabled);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> setWordsPerSession(int count) async {
    final failure = this.failure;
    if (failure != null) return Result.failure(failure);
    preferences = preferences.copyWith(wordsPerSession: count);
    return const Result.success(null);
  }
}
