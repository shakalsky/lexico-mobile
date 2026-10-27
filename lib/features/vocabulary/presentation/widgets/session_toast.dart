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

  /// Whether the last build showed the toast (rather than hiding it).
  bool _visible = false;

  /// A miss picture is painted, counting its fade-out.
  bool _pictureOnScreen = false;

  /// The current toast is a miss that came while the last picture was still
  /// on screen: no new picture, the old one just carries on as it was.
  bool _keepOldPicture = false;
  bool _oldPictureVisible = false;

  @override
  void initState() {
    super.initState();
    _onToast(widget.toast);
    _warmNextPicture();
  }

  @override
  void didUpdateWidget(SessionToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.toast, oldWidget.toast)) _onToast(widget.toast);
  }

  void _onToast(StudyToast? toast) {
    if (toast == null) return;
    if (toast.isPositive) {
      _pictureOnScreen = false;
      _keepOldPicture = false;
      return;
    }
    if (_pictureOnScreen) {
      _keepOldPicture = true;
      _oldPictureVisible = _visible;
      return;
    }
    _keepOldPicture = false;
    _dealPicture();
    _pictureOnScreen = widget.showMissPictures;
  }

  /// Deals the next picture from a shuffled bag, so every one shows before
  /// any repeats and the same one never shows twice running.
  void _dealPicture() {
    _fillBagIfEmpty();
    _picture = _bag.removeLast();
    _warmNextPicture();
  }

  void _fillBagIfEmpty() {
    if (_bag.isNotEmpty) return;
    _bag
      ..addAll(_failPictures)
      ..shuffle(_random);
    if (_bag.length > 1 && _bag.last == _picture) {
      _bag.insert(0, _bag.removeLast());
    }
  }

  /// Parses the picture the next miss will show while nothing is moving,
  /// so the miss doesn't stall on it (debug builds parse on the UI thread).
  void _warmNextPicture() {
    if (!widget.showMissPictures) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fillBagIfEmpty();
      // Same context as the SvgPicture below, so it lands under the same
      // cache key.
      SvgAssetLoader(_assetFor(_bag.last)).loadBytes(context).ignore();
    });
  }

  static String _assetFor(String picture) => 'assets/images/fail/$picture.svg';

  @override
  Widget build(BuildContext context) {
    final visible = _visible =
        widget.toast != null && (!_keepOldPicture || _oldPictureVisible);
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
          onEnd: () {
            if (!_visible) _pictureOnScreen = false;
          },
          child: Padding(
            padding: EdgeInsets.only(
              bottom: positive ? widget.messageLift : _pictureLift,
            ),
            child: positive
                ? AppNotice(message: toast?.message ?? '', maxLines: 2)
                : SvgPicture.asset(_assetFor(_picture), width: 56, height: 56),
          ),
        ),
      ),
    );
  }
}
