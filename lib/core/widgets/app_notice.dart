import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/core/theme/app_typography.dart';

enum AppNoticeTone {
  /// Confirmations and other news: primary green.
  info,

  /// Something went wrong: orange.
  error,
}

/// The app's notification strip: a tinted, rounded box with centred text.
class AppNotice extends StatelessWidget {
  const AppNotice({
    required this.message,
    this.tone = AppNoticeTone.info,
    this.maxLines,
    super.key,
  });

  final String message;
  final AppNoticeTone tone;

  /// `null` lets long messages wrap freely.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final (base, text) = switch (tone) {
      AppNoticeTone.info => (AppColors.accent, AppColors.accentBright),
      AppNoticeTone.error => (AppColors.warning, AppColors.warningBright),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      // Solid, so whatever it floats over doesn't show through.
      decoration: BoxDecoration(
        color: Color.alphaBlend(base.withAlpha(0x29), AppColors.shell),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: base.withAlpha(0x55)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: AppTypography.body(13.5, color: text, weight: FontWeight.w600),
      ),
    );
  }
}

/// App-wide notices that slide down from the top of the screen.
///
/// They live in the root overlay, so they show above every page and sheet
/// and need no setup. Grab the handle before an `await`, like a
/// `ScaffoldMessenger`, and call [AppNoticeController.show] on it later.
abstract final class AppNotices {
  static final _controllers = Expando<AppNoticeController>();

  /// The notices for the app [context] belongs to.
  static AppNoticeController of(BuildContext context) {
    final overlay = Overlay.of(context, rootOverlay: true);
    return _controllers[overlay] ??= AppNoticeController._(overlay);
  }

  /// Shorthand for `AppNotices.of(context).show(...)`.
  static void show(
    BuildContext context,
    String message, {
    AppNoticeTone tone = AppNoticeTone.info,
    Duration duration = AppNoticeController.defaultDuration,
    bool queue = false,
  }) => of(context).show(message, tone: tone, duration: duration, queue: queue);
}

class AppNoticeController extends ChangeNotifier {
  AppNoticeController._(this._overlay);

  static const Duration defaultDuration = Duration(seconds: 4);

  final OverlayState _overlay;
  final Queue<_PendingNotice> _waiting = Queue();
  OverlayEntry? _entry;
  _PendingNotice? _current;
  var _nextId = 0;

  /// Shows [message] at the top of the screen.
  ///
  /// By default it replaces whatever notice is showing; pass `queue: true`
  /// to wait behind it instead.
  void show(
    String message, {
    AppNoticeTone tone = AppNoticeTone.info,
    Duration duration = defaultDuration,
    bool queue = false,
  }) {
    final notice = _PendingNotice(_nextId++, message, tone, duration);
    if (queue && _current != null) {
      _waiting.add(notice);
      return;
    }
    _current = notice;
    _attach();
    notifyListeners();
  }

  void _dismissCurrent() {
    _current = _waiting.isEmpty ? null : _waiting.removeFirst();
    notifyListeners();
  }

  void _attach() {
    if (_entry != null || !_overlay.mounted) return;
    final entry = _entry = OverlayEntry(
      builder: (_) => _NoticeLayer(controller: this),
    );
    // The overlay can't take a new entry while it is being built.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_overlay.mounted) _overlay.insert(entry);
      });
    } else {
      _overlay.insert(entry);
    }
  }
}

class _PendingNotice {
  const _PendingNotice(this.id, this.message, this.tone, this.duration);

  final int id;
  final String message;
  final AppNoticeTone tone;
  final Duration duration;
}

class _NoticeLayer extends StatefulWidget {
  const _NoticeLayer({required this.controller});

  final AppNoticeController controller;

  @override
  State<_NoticeLayer> createState() => _NoticeLayerState();
}

class _NoticeLayerState extends State<_NoticeLayer> {
  Timer? _timer;
  int? _timedId;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    _onChange();
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final current = widget.controller._current;
    if (current?.id != _timedId) {
      _timer?.cancel();
      _timedId = current?.id;
      if (current != null) {
        _timer = Timer(current.duration, widget.controller._dismissCurrent);
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.controller._current;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, -0.4),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: current == null
                ? const SizedBox.shrink()
                : GestureDetector(
                    key: ValueKey(current.id),
                    // Tap or swipe up to dismiss early.
                    onTap: widget.controller._dismissCurrent,
                    onVerticalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0) < 0) {
                        widget.controller._dismissCurrent();
                      }
                    },
                    child: Material(
                      type: MaterialType.transparency,
                      child: AppNotice(
                        message: current.message,
                        tone: current.tone,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
