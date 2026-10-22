import 'package:flutter/material.dart';
import 'package:lexico/core/theme/app_colors.dart';

/// The glowing level-progress track.
class XpBar extends StatelessWidget {
  const XpBar({required this.progress, this.height = 6, super.key});

  /// `0…1` share of the current level completed.
  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: Container(
      height: height,
      color: AppColors.track,
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (context, width, child) =>
            FractionallySizedBox(widthFactor: width, child: child),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.xpGradient,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(color: Color(0x8C0CA678), blurRadius: 18),
            ],
          ),
        ),
      ),
    ),
  );
}
