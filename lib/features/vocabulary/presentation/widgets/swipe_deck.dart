import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/core/theme/app_typography.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_grade.dart';
import 'package:lexico/features/vocabulary/domain/entities/study_card.dart';
import 'package:lexico/features/vocabulary/presentation/widgets/word_card.dart';

/// Lets the answer buttons drive the same fly-out animation a swipe uses.
class SwipeDeckController {
  void Function(ReviewGrade grade)? _handler;

  bool get isAttached => _handler != null;

  void swipe(ReviewGrade grade) => _handler?.call(grade);
}

/// The card stack: the top card is draggable, two more sit directly behind it
/// at the same size.
///
/// The deck owns the gesture and the animation; it reports an answer only
/// once the card has left the screen, so the bloc never advances mid-flight.
class SwipeDeck extends StatefulWidget {
  const SwipeDeck({
    required this.cards,
    required this.topIndex,
    required this.isRevealed,
    required this.onFlip,
    required this.onAnswered,
    this.controller,
    super.key,
  });

  /// Top card first; only the first three are painted.
  final List<StudyCard> cards;

  /// Where the top card sits in the session. A new value means the stack
  /// moved on after an answer, so the deck brings the next card in. Needed
  /// because a missed word dealt again can be the same card twice running.
  final int topIndex;
  final bool isRevealed;
  final VoidCallback onFlip;
  final ValueChanged<ReviewGrade> onAnswered;
  final SwipeDeckController? controller;

  /// How far a card must travel before the release counts as an answer.
  static const double commitDistance = 88;

  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<SwipeDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  /// Horizontal offset of the top card, in logical pixels.
  double _dx = 0;
  double _animationFrom = 0;
  double _animationTo = 0;
  bool _isDragging = false;
  ReviewGrade? _flyingGrade;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..addListener(_onAnimationTick);
    widget.controller?._handler = _flingTo;
  }

  @override
  void didUpdateWidget(SwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._handler = null;
      widget.controller?._handler = _flingTo;
    }
    // The answered card stays off screen until the stack moves on; snapping
    // it back earlier flashes the old card while the answer is being saved.
    if (oldWidget.topIndex != widget.topIndex) {
      _flyingGrade = null;
      _dx = 0;
    }
  }

  @override
  void dispose() {
    widget.controller?._handler = null;
    _animation.dispose();
    super.dispose();
  }

  void _onAnimationTick() {
    final eased = Curves.easeOutCubic.transform(_animation.value);
    setState(() {
      _dx = _animationFrom + (_animationTo - _animationFrom) * eased;
    });
  }

  void _onPanStart(DragStartDetails details) {
    if (_flyingGrade != null) return;
    _animation.stop();
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() => _dx += details.delta.dx);
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    setState(() => _isDragging = false);

    final flungRight = details.velocity.pixelsPerSecond.dx > 600;
    final flungLeft = details.velocity.pixelsPerSecond.dx < -600;
    final committed = _dx.abs() > SwipeDeck.commitDistance;

    if (committed || flungRight || flungLeft) {
      final right = !flungLeft && (flungRight || _dx > 0);
      _flingTo(right ? ReviewGrade.knewIt : ReviewGrade.needsReview);
    } else {
      _runAnimation(to: 0);
    }
  }

  /// Sends the top card off screen and reports the answer when it is gone.
  void _flingTo(ReviewGrade grade) {
    if (_flyingGrade != null || widget.cards.isEmpty) return;
    final width = MediaQuery.sizeOf(context).width;
    _flyingGrade = grade;
    _runAnimation(to: grade.isCorrect ? width * 1.2 : -width * 1.2);
  }

  void _runAnimation({required double to}) {
    _animationFrom = _dx;
    _animationTo = to;
    _animation.reset();
    unawaited(
      _animation.forward().then((_) {
        final grade = _flyingGrade;
        if (grade == null || !mounted) return;
        // Stays locked (and off screen) until [didUpdateWidget] sees the
        // stack advance, so a quick second tap can't answer twice.
        widget.onAnswered(grade);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.cards.take(3).toList(growable: false);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Painted back to front so the top card sits above the others.
        for (var depth = visible.length - 1; depth >= 0; depth--)
          if (depth == 0)
            _TopCard(
              key: ValueKey(visible[depth].id),
              card: visible[depth],
              dx: _dx,
              isRevealed: widget.isRevealed && _flyingGrade == null,
              onTap: widget.onFlip,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
            )
          else
            _StackedCard(
              key: ValueKey(visible[depth].id),
              card: visible[depth],
              depth: depth,
            ),
      ],
    );
  }
}

class _TopCard extends StatelessWidget {
  const _TopCard({
    required this.card,
    required this.dx,
    required this.isRevealed,
    required this.onTap,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    super.key,
  });

  final StudyCard card;
  final double dx;
  final bool isRevealed;
  final VoidCallback onTap;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  @override
  Widget build(BuildContext context) {
    final stampOpacity = (dx.abs() / (SwipeDeck.commitDistance * 1.02)).clamp(
      0.0,
      1.0,
    );

    return Positioned.fill(
      child: Transform.translate(
        offset: Offset(dx, dx.abs() * 0.06),
        child: Transform.rotate(
          angle: dx / 22 * math.pi / 180,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onPanStart: onPanStart,
            onPanUpdate: onPanUpdate,
            onPanEnd: onPanEnd,
            child: Stack(
              children: [
                Positioned.fill(
                  child: WordCard(
                    word: card.word,
                    level: card.review.level,
                    isRevealed: isRevealed,
                  ),
                ),
                Positioned(
                  top: 22,
                  right: 20,
                  child: _Stamp(
                    label: 'knew it',
                    color: AppColors.accent,
                    angle: -8,
                    opacity: dx > 0 ? stampOpacity : 0,
                  ),
                ),
                Positioned(
                  top: 22,
                  left: 20,
                  child: _Stamp(
                    label: 'review',
                    color: AppColors.danger,
                    angle: 8,
                    opacity: dx < 0 ? stampOpacity : 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StackedCard extends StatelessWidget {
  const _StackedCard({required this.card, required this.depth, super.key});

  final StudyCard card;
  final int depth;

  @override
  // Same size and position as the top card, so it is hidden until the top
  // card is swiped away.
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: Opacity(
        opacity: depth == 2 ? 0.45 : 1,
        child: WordCard(
          word: card.word,
          level: card.review.level,
          isRevealed: false,
        ),
      ),
    ),
  );
}

/// The rotated "knew it" / "review" label that fades in while dragging.
class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.label,
    required this.color,
    required this.angle,
    required this.opacity,
  });

  final String label;
  final Color color;
  final double angle;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: angle * math.pi / 180,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label.toUpperCase(),
            style: AppTypography.body(
              12.5,
              color: color,
              weight: FontWeight.w700,
              letterSpacing: 1.75,
            ),
          ),
        ),
      ),
    ),
  );
}
