import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lexico/app/injection.dart';
import 'package:lexico/app/lexico_app.dart';
import 'package:lexico/core/config/flavor_config.dart';
import 'package:lexico/features/vocabulary/data/sync/sync_engine.dart';

/// Shared startup for every flavor's entrypoint.
Future<void> bootstrap(FlavorConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  configureDependencies(config);
  // Changes made offline go out as soon as the app is back in front.
  AppLifecycleListener(onResume: sl<SyncEngine>().schedulePush);
  runApp(LexicoApp(title: config.appTitle));
}
