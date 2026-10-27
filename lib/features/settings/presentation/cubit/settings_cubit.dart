import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/settings/domain/entities/study_preferences.dart';
import 'package:lexico/features/settings/domain/usecases/get_study_preferences.dart';
import 'package:lexico/features/settings/domain/usecases/set_repeat_missed_words.dart';
import 'package:lexico/features/settings/domain/usecases/set_show_miss_pictures.dart';
import 'package:lexico/features/settings/domain/usecases/set_words_per_session.dart';

enum SettingsStatus { loading, ready }

class SettingsState extends Equatable {
  const SettingsState({
    this.status = SettingsStatus.loading,
    this.preferences = const StudyPreferences(),
    this.message,
  });

  final SettingsStatus status;
  final StudyPreferences preferences;

  /// Why the last read or write failed, if it did.
  final String? message;

  @override
  List<Object?> get props => [status, preferences, message];
}

/// Drives the settings screen.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required GetStudyPreferences getStudyPreferences,
    required SetRepeatMissedWords setRepeatMissedWords,
    required SetWordsPerSession setWordsPerSession,
    required SetShowMissPictures setShowMissPictures,
  }) : _getStudyPreferences = getStudyPreferences,
       _setRepeatMissedWords = setRepeatMissedWords,
       _setWordsPerSession = setWordsPerSession,
       _setShowMissPictures = setShowMissPictures,
       super(const SettingsState());

  final GetStudyPreferences _getStudyPreferences;
  final SetRepeatMissedWords _setRepeatMissedWords;
  final SetWordsPerSession _setWordsPerSession;
  final SetShowMissPictures _setShowMissPictures;

  Future<void> load() async {
    final result = await _getStudyPreferences(const NoParams());
    emit(
      result.fold(
        (failure) => SettingsState(
          status: SettingsStatus.ready,
          message: failure.message,
        ),
        (preferences) => SettingsState(
          status: SettingsStatus.ready,
          preferences: preferences,
        ),
      ),
    );
  }

  /// Flips the switch right away and rolls it back if saving fails.
  Future<void> repeatMissedWordsChanged({required bool enabled}) => _save(
    state.preferences.copyWith(repeatMissedWords: enabled),
    () => _setRepeatMissedWords(enabled),
  );

  /// Flips the switch right away and rolls it back if saving fails.
  Future<void> showMissPicturesChanged({required bool enabled}) => _save(
    state.preferences.copyWith(showMissPictures: enabled),
    () => _setShowMissPictures(enabled),
  );

  /// Shows the new count right away and rolls it back if saving fails.
  Future<void> wordsPerSessionChanged(int count) async {
    if (count == state.preferences.wordsPerSession) return;
    await _save(
      state.preferences.copyWith(wordsPerSession: count),
      () => _setWordsPerSession(count),
    );
  }

  Future<void> _save(
    StudyPreferences next,
    Future<Result<void>> Function() write,
  ) async {
    final previous = state.preferences;
    emit(SettingsState(status: SettingsStatus.ready, preferences: next));

    final failure = (await write()).failureOrNull;
    if (failure != null) {
      emit(
        SettingsState(
          status: SettingsStatus.ready,
          preferences: previous,
          message: failure.message,
        ),
      );
    }
  }
}
