import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lexico/core/widgets/app_notice.dart';
import 'package:lexico/features/vocabulary/presentation/bloc/study/study_bloc.dart';

/// The confirmation that rises after each answer: a green strip with the
/// message for a right answer, a random picture for a wrong one.
class SessionToast extends StatefulWidget {
  const SessionToast({
    required this.toast,
    this.messageLift = 0,
    this.showMissPictures = true,
    super.key,
  });

  /// `null` hides it; the last toast stays painted while it fades out.
  final StudyToast? toast;

  /// How far the text message sits above the bottom.
  final double messageLift;

  /// When off, a wrong answer shows nothing.
  final bool showMissPictures;

  @override
  State<SessionToast> createState() => _SessionToastState();
}

class _SessionToastState extends State<SessionToast> {
  /// How far a wrong-answer picture sits above the bottom.
  static const double _pictureLift = 4;

  static const _failPictures = [
    'bird',
    'coffin',
    'confused-face',
    'cucumber',
    'eggplant',
    'face-with-hand-over-mouth',
    'face-with-raised-eyebrow',
    'flushed-face',
    'japanese-secret-button',
    'koala',
    'moai',
    'new-moon-face',
    'penguin',
    'pinched-fingers-light-skin-tone',
    'pinching-hand-light-skin-tone',
    'pleading-face',
    'skull',
    'smiling-face-with-tear',
    'wilted-flower',
    'woman-facepalming-light-skin-tone',
  ];

  final _random = math.Random();
  final List<String> _bag = [];
  StudyToast? _last;
  String _picture = _failPictures.first;

  @override
  void initState() {
    super.initState();
    _pickPictureFor(widget.toast);
  }

  @override
  void didUpdateWidget(SessionToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.toast, oldWidget.toast)) {
      _pickPictureFor(widget.toast);
    }
  }

  /// Deals the next picture from a shuffled bag, so every one shows before
  /// any repeats and the same one never shows twice running.
  void _pickPictureFor(StudyToast? toast) {
    if (toast == null || toast.isPositive) return;
    if (_bag.isEmpty) {
      _bag
        ..addAll(_failPictures)
        ..shuffle(_random);
      if (_bag.length > 1 && _bag.last == _picture) {
        _bag.insert(0, _bag.removeLast());
      }
    }
    _picture = _bag.removeLast();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.toast != null;
    final toast = _last = widget.toast ?? _last;
    final positive = toast?.isPositive ?? true;
    if (!positive && !widget.showMissPictures) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.35),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: positive ? widget.messageLift : _pictureLift,
            ),
            child: positive
                ? AppNotice(message: toast?.message ?? '', maxLines: 2)
                : SvgPicture.asset(
                    'assets/images/fail/$_picture.svg',
                    width: 56,
                    height: 56,
                  ),
          ),
        ),
      ),
    );
  }
}
