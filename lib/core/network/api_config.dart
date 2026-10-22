/// Network settings shared by every flavor. The base URL is per flavor:
/// see `FlavorConfig.apiBaseUrl`.
abstract final class ApiConfig {
  static const Duration connectTimeout = Duration(seconds: 8);
  static const Duration receiveTimeout = Duration(seconds: 12);

  /// The deck the learner is working through. One language pair for now.
  static const String defaultDeckId = 'es-en-core';
}
