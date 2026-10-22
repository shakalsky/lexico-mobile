import 'package:flutter/material.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/core/theme/app_typography.dart';

/// One of the three small numbers under the XP bar.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.value,
    required this.label,
    this.valueColor = AppColors.textPrimary,
    super.key,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.hairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTypography.display(26, color: valueColor)),
        const SizedBox(height: 5),
        Text(
          label,
          style: AppTypography.body(
            11,
            color: AppColors.textFaint,
            letterSpacing: 0.44,
          ),
        ),
      ],
    ),
  );
}
