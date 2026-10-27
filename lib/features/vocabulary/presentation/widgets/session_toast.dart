import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lexico/core/widgets/app_notice.dart';
import 'package:lexico/features/vocabulary/presentation/bloc/study/study_bloc.dart';

/// The confirmation that rises after each answer: a green strip with the
/// message for a right answer, a random emoji for a wrong one.
class SessionToast extends StatefulWidget {
  const SessionToast({required this.toast, this.messageLift = 0, super.key});

  /// `null` hides it; the last toast stays painted while it fades out.
  final StudyToast? toast;

  /// How far the text strip sits above the bottom; the emoji is not lifted.
  final double messageLift;

  @override
  State<SessionToast> createState() => _SessionToastState();
}

class _SessionToastState extends State<SessionToast> {
  static const _failEmoji = ['🫡', '🫪', '🥹', '🫠', '💀', '🥀'];

  final _random = math.Random();
  final List<String> _bag = [];
  StudyToast? _last;
  String _emoji = _failEmoji.first;

  @override
  void initState() {
    super.initState();
    _pickEmojiFor(widget.toast);
  }

  @override
  void didUpdateWidget(SessionToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.toast, oldWidget.toast)) _pickEmojiFor(widget.toast);
  }

  /// Deals the next emoji from a shuffled bag, so every one shows before any
  /// repeats and the same one never shows twice running.
  void _pickEmojiFor(StudyToast? toast) {
    if (toast == null || toast.isPositive) return;
    if (_bag.isEmpty) {
      _bag
        ..addAll(_failEmoji)
        ..shuffle(_random);
      if (_bag.length > 1 && _bag.last == _emoji) {
        _bag.insert(0, _bag.removeLast());
      }
    }
    _emoji = _bag.removeLast();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.toast != null;
    final toast = _last = widget.toast ?? _last;
    final positive = toast?.isPositive ?? true;

    return IgnorePointer(
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.35),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: positive
              ? Padding(
                  padding: EdgeInsets.only(bottom: widget.messageLift),
                  child: AppNotice(message: toast?.message ?? '', maxLines: 2),
                )
              : Text(_emoji, style: const TextStyle(fontSize: 44)),
        ),
      ),
    );
  }
}
