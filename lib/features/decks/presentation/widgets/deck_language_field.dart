import 'package:flutter/material.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/features/decks/domain/entities/deck_language.dart';
import 'package:lexico/features/decks/presentation/widgets/form_sheet.dart';

/// The Language menu of the deck sheets. Works with display labels, since
/// that is what a deck stores.
class DeckLanguageField extends StatelessWidget {
  const DeckLanguageField({
    required this.value,
    required this.onChanged,
    required this.enabled,
    super.key,
  });

  /// The label picked, e.g. `Polski`. A label that isn't one of
  /// [DeckLanguage] (a deck created elsewhere) is offered too.
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final labels = [for (final language in DeckLanguage.values) language.label];
    if (!labels.contains(value)) labels.add(value);

    return FormLabeled(
      label: 'Language',
      child: DropdownButtonFormField<String>(
        initialValue: value,
        onChanged: enabled
            ? (label) {
                if (label != null) onChanged(label);
              }
            : null,
        items: [
          for (final label in labels)
            DropdownMenuItem(value: label, child: Text(label)),
        ],
        style: formFieldTextStyle,
        dropdownColor: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        iconEnabledColor: AppColors.textMuted,
        decoration: formFieldDecoration(),
      ),
    );
  }
}
