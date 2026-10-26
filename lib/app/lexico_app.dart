import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexico/app/injection.dart';
import 'package:lexico/app/shell/app_shell.dart';
import 'package:lexico/core/theme/app_theme.dart';
import 'package:lexico/features/vocabulary/domain/usecases/watch_sync_conflicts.dart';
import 'package:lexico/features/vocabulary/presentation/bloc/home/home_bloc.dart';
import 'package:lexico/features/vocabulary/presentation/widgets/sync_conflict_listener.dart';

class LexicoApp extends StatelessWidget {
  const LexicoApp({this.title = 'Léxico', super.key});

  final String title;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: title,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    home: BlocProvider(
      create: (_) => sl<HomeBloc>()..add(const HomeStarted()),
      child: SyncConflictListener(
        conflicts: sl<WatchSyncConflicts>()(),
        child: const AppShell(),
      ),
    ),
  );
}
