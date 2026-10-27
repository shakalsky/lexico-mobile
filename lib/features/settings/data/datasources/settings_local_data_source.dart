import 'package:lexico/core/error/exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SettingsLocalDataSource {
  /// `null` when the learner never changed the setting.
  Future<bool?> repeatMissedWords();

  Future<void> setRepeatMissedWords({required bool enabled});

  /// `null` when the learner never changed the setting.
  Future<int?> wordsPerSession();

  Future<void> setWordsPerSession(int count);

  /// `null` when the learner never changed the setting.
  Future<bool?> showMissPictures();

  Future<void> setShowMissPictures({required bool enabled});
}

class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {
  SettingsLocalDataSourceImpl([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String repeatMissedWordsKey = 'study.repeatMissedWords';
  static const String wordsPerSessionKey = 'study.wordsPerSession';
  static const String showMissPicturesKey = 'study.showMissPictures';

  final SharedPreferencesAsync _preferences;

  @override
  Future<bool?> repeatMissedWords() =>
      _guard(() => _preferences.getBool(repeatMissedWordsKey));

  @override
  Future<void> setRepeatMissedWords({required bool enabled}) =>
      _guard(() => _preferences.setBool(repeatMissedWordsKey, enabled));

  @override
  Future<int?> wordsPerSession() =>
      _guard(() => _preferences.getInt(wordsPerSessionKey));

  @override
  Future<void> setWordsPerSession(int count) =>
      _guard(() => _preferences.setInt(wordsPerSessionKey, count));

  @override
  Future<bool?> showMissPictures() =>
      _guard(() => _preferences.getBool(showMissPicturesKey));

  @override
  Future<void> setShowMissPictures({required bool enabled}) =>
      _guard(() => _preferences.setBool(showMissPicturesKey, enabled));

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on Object catch (error) {
      throw CacheException('Settings storage failed: $error');
    }
  }
}
