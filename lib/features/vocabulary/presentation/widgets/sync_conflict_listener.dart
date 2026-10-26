import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lexico/features/vocabulary/domain/entities/sync_conflict.dart';
import 'package:lexico/features/vocabulary/presentation/sync_conflict_message.dart';

/// Tells the learner, in a snack bar, about each change made offline that
/// the word service refused once it was sent. Wraps the whole app, so the
/// message shows whichever screen is open.
class SyncConflictListener extends StatefulWidget {
  const SyncConflictListener({
    required this.conflicts,
    required this.child,
    super.key,
  });

  final Stream<SyncConflict> conflicts;
  final Widget child;

  @override
  State<SyncConflictListener> createState() => _SyncConflictListenerState();
}

class _SyncConflictListenerState extends State<SyncConflictListener> {
  late final StreamSubscription<SyncConflict> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.conflicts.listen(_show);
  }

  void _show(SyncConflict conflict) {
    // Several conflicts queue up rather than replace each other.
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(conflict.message),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
