import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lexico/app/injection.dart';
import 'package:lexico/app/lexico_app.dart';
import 'package:lexico/core/config/flavor_config.dart';

/// Shared startup for every flavor's entrypoint.
void bootstrap(FlavorConfig config) {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  configureDependencies(config);
  runApp(LexicoApp(title: config.appTitle));
}
