import 'package:flutter/material.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/core/theme/app_typography.dart';

/// Stand-in screen for tabs that aren't built yet.
class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({
    required this.title,
    required this.subtitle,
    this.action,
    super.key,
  });

  final String title;
  final String subtitle;

  /// Optional widget shown to the right of the title, e.g. a settings button.
  /// It is squeezed into a [headerHeight] square so it can't grow the header.
  final Widget? action;

  /// Fixed height of the title row, matching the 32px display title.
  static const double headerHeight = 36;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.shell,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 20, 26, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: headerHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: AppTypography.display(32)),
                  if (action case final action?)
                    SizedBox.square(dimension: headerHeight, child: action),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: AppTypography.body(14, color: AppColors.textMuted),
            ),
            const Spacer(),
            Center(
              child: Text(
                'Coming soon',
                style: AppTypography.displayItalic(26),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    ),
  );
}
