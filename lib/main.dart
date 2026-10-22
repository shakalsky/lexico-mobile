// Default entrypoint for a plain `flutter run`: the dev flavor.
// Each flavor has its own entrypoint — see main_dev.dart and main_staging.dart.
import 'package:lexico/app/bootstrap.dart';
import 'package:lexico/core/config/flavor_config.dart';

void main() => bootstrap(FlavorConfig.dev);
