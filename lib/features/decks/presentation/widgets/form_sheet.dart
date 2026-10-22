import 'package:flutter/material.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/core/theme/app_typography.dart';
import 'package:lexico/features/vocabulary/presentation/widgets/primary_button.dart';

/// Opens [sheet] as a bottom sheet in the app's style. Completes with what
/// the sheet pops, or `null` if it is dismissed.
Future<T?> showFormSheet<T>(BuildContext context, {required Widget sheet}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => sheet,
    );

/// The layout every form sheet shares: a title, the fields, an error line
/// and the submit button, lifted above the keyboard and scrollable when the
/// screen is short.
class FormSheet extends StatelessWidget {
  const FormSheet({
    required this.title,
    required this.fields,
    required this.submitLabel,
    required this.savingLabel,
    required this.saving,
    required this.onSubmit,
    this.message,
    super.key,
  });

  final String title;
  final List<Widget> fields;
  final String submitLabel;
  final String savingLabel;
  final bool saving;
  final VoidCallback onSubmit;

  /// Why the last attempt was refused.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppTypography.display(28)),
              const SizedBox(height: 22),
              for (final (index, field) in fields.indexed) ...[
                if (index > 0) const SizedBox(height: 16),
                field,
              ],
              if (message != null) ...[
                const SizedBox(height: 14),
                Text(
                  message,
                  style: AppTypography.body(13.5, color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: saving ? savingLabel : submitLabel,
                onPressed: saving ? null : onSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small uppercase caption above a form control, with an optional note.
class FormLabeled extends StatelessWidget {
  const FormLabeled({
    required this.label,
    required this.child,
    this.note,
    super.key,
  });

  final String label;
  final Widget child;

  /// Shown after the label in a fainter style, e.g. "optional".
  final String? note;

  @override
  Widget build(BuildContext context) {
    final note = this.note;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label.toUpperCase(),
            children: [
              if (note != null)
                TextSpan(
                  text: '  ·  $note',
                  style: AppTypography.eyebrow(
                    size: 11,
                    color: AppColors.textGhost,
                    tracking: 0.4,
                    weight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          style: AppTypography.eyebrow(size: 11),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// A text field in the form sheets' style, with its caption.
class FormTextField extends StatelessWidget {
  const FormTextField({
    required this.label,
    required this.controller,
    required this.enabled,
    this.hint,
    this.note,
    this.autofocus = false,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.maxLines = 1,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final String? hint;
  final String? note;
  final bool autofocus;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// More than 1 lets a long sentence wrap; the field grows up to this many
  /// lines.
  final int maxLines;

  @override
  Widget build(BuildContext context) => FormLabeled(
    label: label,
    note: note,
    child: TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      textInputAction: textInputAction,
      textCapitalization: TextCapitalization.sentences,
      onSubmitted: onSubmitted,
      minLines: 1,
      maxLines: maxLines,
      cursorColor: AppColors.accent,
      style: formFieldTextStyle,
      decoration: formFieldDecoration(hint: hint),
    ),
  );
}

final TextStyle formFieldTextStyle = AppTypography.body(
  16,
  color: AppColors.textPrimary,
);

OutlineInputBorder _border(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(14),
  borderSide: BorderSide(color: color),
);

InputDecoration formFieldDecoration({String? hint}) => InputDecoration(
  hintText: hint,
  hintStyle: AppTypography.body(16, color: AppColors.textGhost),
  filled: true,
  fillColor: AppColors.surfaceRaised,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
  border: _border(AppColors.hairline),
  enabledBorder: _border(AppColors.hairline),
  disabledBorder: _border(AppColors.hairline),
  focusedBorder: _border(AppColors.accent),
);
