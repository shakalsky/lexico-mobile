import 'package:flutter/material.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/core/theme/app_typography.dart';

/// The accent call-to-action: "Start session", "Another round".
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.height = 58,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: height,
          decoration: BoxDecoration(
            color: enabled ? AppColors.accent : AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled
                ? const [
                    BoxShadow(
                      color: Color(0x590CA678),
                      blurRadius: 40,
                      offset: Offset(0, 12),
                    ),
                  ]
                : const [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.body(
              16,
              color: enabled ? AppColors.onAccent : AppColors.textGhost,
              weight: FontWeight.w700,
              letterSpacing: 0.16,
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet text-only action: "Done for today".
class GhostButton extends StatelessWidget {
  const GhostButton({
    required this.label,
    required this.onPressed,
    this.height = 52,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      onTap: onPressed,
      child: SizedBox(
        height: height,
        child: Center(
          child: Text(
            label,
            style: AppTypography.body(
              15,
              color: AppColors.textMuted,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}
