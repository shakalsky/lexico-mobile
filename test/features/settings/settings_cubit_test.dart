import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/core/error/failure.dart';
import 'package:lexico/features/settings/domain/entities/study_preferences.dart';
import 'package:lexico/features/settings/domain/usecases/get_study_preferences.dart';
import 'package:lexico/features/settings/domain/usecases/set_repeat_missed_words.dart';
import 'package:lexico/features/settings/domain/usecases/set_words_per_session.dart';
import 'package:lexico/features/settings/presentation/cubit/settings_cubit.dart';

import '../../helpers/fake_settings_repository.dart';

void main() {
  late FakeSettingsRepository repository;

  SettingsCubit buildCubit({bool repeatMissedWords = false}) {
    repository = FakeSettingsRepository(
      preferences: StudyPreferences(repeatMissedWords: repeatMissedWords),
    );
    return SettingsCubit(
      getStudyPreferences: GetStudyPreferences(repository),
      setRepeatMissedWords: SetRepeatMissedWords(repository),
      setWordsPerSession: SetWordsPerSession(repository),
    );
  }

  blocTest<SettingsCubit, SettingsState>(
    'loads the stored preferences',
    build: () => buildCubit(repeatMissedWords: true),
    act: (cubit) => cubit.load(),
    expect: () => const [
      SettingsState(
        status: SettingsStatus.ready,
        preferences: StudyPreferences(repeatMissedWords: true),
      ),
    ],
  );

  blocTest<SettingsCubit, SettingsState>(
    'turning the switch on saves it',
    build: buildCubit,
    act: (cubit) => cubit.repeatMissedWordsChanged(enabled: true),
    expect: () => const [
      SettingsState(
        status: SettingsStatus.ready,
        preferences: StudyPreferences(repeatMissedWords: true),
      ),
    ],
    verify: (_) => expect(repository.preferences.repeatMissedWords, isTrue),
  );

  blocTest<SettingsCubit, SettingsState>(
    'rolls the switch back when saving fails',
    build: () => buildCubit()..load(),
    act: (cubit) async {
      await Future<void>.delayed(Duration.zero);
      repository.failure = const CacheFailure();
      await cubit.repeatMissedWordsChanged(enabled: true);
    },
    skip: 1,
    expect: () => [
      const SettingsState(
        status: SettingsStatus.ready,
        preferences: StudyPreferences(repeatMissedWords: true),
      ),
      isA<SettingsState>()
          .having((s) => s.preferences.repeatMissedWords, 'repeat', isFalse)
          .having((s) => s.message, 'message', isNotNull),
    ],
  );

  blocTest<SettingsCubit, SettingsState>(
    'picking a words-per-session count saves it',
    build: buildCubit,
    act: (cubit) => cubit.wordsPerSessionChanged(15),
    expect: () => const [
      SettingsState(
        status: SettingsStatus.ready,
        preferences: StudyPreferences(wordsPerSession: 15),
      ),
    ],
    verify: (_) => expect(repository.preferences.wordsPerSession, 15),
  );

  blocTest<SettingsCubit, SettingsState>(
    'refuses a words-per-session count out of range',
    build: buildCubit,
    act: (cubit) => cubit.wordsPerSessionChanged(0),
    expect: () => [
      const SettingsState(
        status: SettingsStatus.ready,
        preferences: StudyPreferences(wordsPerSession: 0),
      ),
      isA<SettingsState>()
          .having(
            (s) => s.preferences.wordsPerSession,
            'count',
            StudyPreferences.defaultWordsPerSession,
          )
          .having((s) => s.message, 'message', isNotNull),
    ],
    verify: (_) => expect(
      repository.preferences.wordsPerSession,
      StudyPreferences.defaultWordsPerSession,
    ),
  );
}
