import 'package:flutter/material.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/core/theme/app_typography.dart';

/// "12 day streak" with the slow breathing dot from the design.
class StreakPill extends StatefulWidget {
  const StreakPill({required this.days, super.key});

  final int days;

  @override
  State<StreakPill> createState() => _StreakPillState();
}

class _StreakPillState extends State<StreakPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0x1F0CA678),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0x400CA678)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_pulse.value);
            return Opacity(
              opacity: 0.55 + 0.45 * t,
              child: Transform.scale(scale: 1 + 0.06 * t, child: const _Dot()),
            );
          },
        ),
        const SizedBox(width: 7),
        Text(
          '${widget.days} day streak',
          style: AppTypography.body(
            12.5,
            color: AppColors.accentBright,
            weight: FontWeight.w600,
            letterSpacing: 0.25,
          ),
        ),
      ],
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: const BoxDecoration(
      color: AppColors.accent,
      shape: BoxShape.circle,
    ),
  );
}
