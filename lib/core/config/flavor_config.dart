enum Flavor { dev, staging }

/// What differs between builds of the app. Picked by the entrypoint
/// (`lib/main_<flavor>.dart`) and registered once at startup.
enum FlavorConfig {
  dev._(
    flavor: Flavor.dev,
    appTitle: 'Léxico Dev',
    apiBaseUrl: 'http://192.168.0.159:3000',
  ),
  staging._(
    flavor: Flavor.staging,
    appTitle: 'Léxico Staging',
    apiBaseUrl: 'http://192.168.0.159:3001',
  );

  const FlavorConfig._({
    required this.flavor,
    required this.appTitle,
    required String apiBaseUrl,
  }) : _apiBaseUrl = apiBaseUrl;

  final Flavor flavor;
  final String appTitle;
  final String _apiBaseUrl;

  /// The flavor's API, unless overridden at build time with
  /// `--dart-define=LEXICO_API_BASE_URL=https://…`.
  String get apiBaseUrl =>
      _apiBaseUrlOverride.isNotEmpty ? _apiBaseUrlOverride : _apiBaseUrl;

  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'LEXICO_API_BASE_URL',
  );
}
