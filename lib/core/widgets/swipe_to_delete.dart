import 'package:flutter/material.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/core/theme/app_typography.dart';

/// Swipe [child] left to delete it, after asking with [title] and
/// [message]. Cancelling slides it back.
///
/// [onDeleted] must take the item out of the list at once, in the same
/// frame.
class SwipeToDelete extends StatelessWidget {
  const SwipeToDelete({
    required this.id,
    required this.title,
    required this.message,
    required this.onDeleted,
    required this.child,
    this.borderRadius = 14,
    super.key,
  });

  /// Tells the items of a list apart.
  final String id;
  final String title;
  final String message;
  final VoidCallback onDeleted;
  final Widget child;

  /// Matches the corners of [child].
  final double borderRadius;

  @override
  Widget build(BuildContext context) => Dismissible(
    key: ValueKey('dismiss-$id'),
    direction: DismissDirection.endToStart,
    confirmDismiss: (_) =>
        ConfirmDeleteDialog.show(context, title: title, message: message),
    onDismissed: (_) => onDeleted(),
    background: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          AppColors.danger.withAlpha(0x26),
          AppColors.shell,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.danger.withAlpha(0x55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Delete',
            style: AppTypography.body(
              14,
              color: AppColors.danger,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.delete_outline_rounded,
            color: AppColors.danger,
            size: 22,
          ),
        ],
      ),
    ),
    child: child,
  );
}

/// Asks before something is deleted for good.
class ConfirmDeleteDialog extends StatelessWidget {
  const ConfirmDeleteDialog({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  /// Completes with `true` only when the learner chose to delete.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
  }) async =>
      await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withAlpha(0xA0),
        builder: (_) => ConfirmDeleteDialog(title: title, message: message),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.surfaceRaised,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 26),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: AppColors.hairlineStrong),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.display(26)),
          const SizedBox(height: 12),
          Text(
            message,
            style: AppTypography.body(14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const Key('confirm-delete-cancel'),
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                child: Text(
                  'Cancel',
                  style: AppTypography.body(14, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                key: const Key('confirm-delete'),
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  backgroundColor: AppColors.danger.withAlpha(0x1F),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: Text(
                  'Delete',
                  style: AppTypography.body(
                    14,
                    color: AppColors.danger,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
