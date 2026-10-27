import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lexico/core/widgets/app_notice.dart';
import 'package:lexico/features/vocabulary/domain/entities/sync_conflict.dart';
import 'package:lexico/features/vocabulary/presentation/sync_conflict_message.dart';

/// Tells the learner, in an app notice, about each change made offline that
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
    if (!mounted) return;
    // Several conflicts queue up rather than replace each other.
    AppNotices.show(
      context,
      conflict.message,
      tone: AppNoticeTone.error,
      duration: const Duration(seconds: 6),
      queue: true,
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
