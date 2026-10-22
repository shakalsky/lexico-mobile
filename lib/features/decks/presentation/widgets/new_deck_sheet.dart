import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/domain/entities/deck_language.dart';
import 'package:lexico/features/decks/domain/usecases/create_deck.dart';
import 'package:lexico/features/decks/presentation/cubit/new_deck_cubit.dart';
import 'package:lexico/features/decks/presentation/widgets/form_sheet.dart';

/// Bottom sheet that creates a deck on the word service.
class NewDeckSheet extends StatefulWidget {
  const NewDeckSheet({super.key});

  /// Opens the sheet; completes with the created deck, or `null` if the
  /// learner closed it.
  static Future<Deck?> show(
    BuildContext context, {
    required CreateDeck createDeck,
  }) => showFormSheet<Deck>(
    context,
    sheet: BlocProvider(
      create: (_) => NewDeckCubit(createDeck: createDeck),
      child: const NewDeckSheet(),
    ),
  );

  @override
  State<NewDeckSheet> createState() => _NewDeckSheetState();
}

class _NewDeckSheetState extends State<NewDeckSheet> {
  final _name = TextEditingController();
  DeckLanguage _language = DeckLanguage.values.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() => context.read<NewDeckCubit>().submit(
    name: _name.text,
    language: _language,
  );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<NewDeckCubit, NewDeckState>(
        listenWhen: (_, current) => current.status == NewDeckStatus.created,
        listener: (context, state) => Navigator.of(context).pop(state.deck),
        builder: (context, state) {
          final saving = state.status == NewDeckStatus.saving;

          return FormSheet(
            title: 'New deck',
            submitLabel: 'Create deck',
            savingLabel: 'Creating…',
            saving: saving,
            message: state.message,
            onSubmit: _submit,
            fields: [
              FormTextField(
                key: const Key('new-deck-name'),
                label: 'Name',
                hint: 'e.g. Food',
                controller: _name,
                enabled: !saving,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              FormLabeled(
                label: 'Language',
                child: DropdownButtonFormField<DeckLanguage>(
                  key: const Key('new-deck-language'),
                  initialValue: _language,
                  onChanged: saving
                      ? null
                      : (language) {
                          if (language != null) {
                            setState(() => _language = language);
                          }
                        },
                  items: [
                    for (final language in DeckLanguage.values)
                      DropdownMenuItem(
                        value: language,
                        child: Text(language.label),
                      ),
                  ],
                  style: formFieldTextStyle,
                  dropdownColor: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(14),
                  iconEnabledColor: AppColors.textMuted,
                  decoration: formFieldDecoration(),
                ),
              ),
            ],
          );
        },
      );
}
