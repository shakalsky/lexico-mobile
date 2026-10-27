import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/domain/usecases/edit_deck.dart';
import 'package:lexico/features/decks/presentation/cubit/edit_deck_cubit.dart';
import 'package:lexico/features/decks/presentation/widgets/deck_language_field.dart';
import 'package:lexico/features/decks/presentation/widgets/form_sheet.dart';

/// Bottom sheet that changes a deck's name and language.
class EditDeckSheet extends StatefulWidget {
  const EditDeckSheet({required this.deck, super.key});

  final Deck deck;

  /// Opens the sheet; completes with the edited deck, or `null` if the
  /// learner closed it or changed nothing.
  static Future<Deck?> show(
    BuildContext context, {
    required Deck deck,
    required EditDeck editDeck,
  }) => showFormSheet<Deck>(
    context,
    sheet: BlocProvider(
      create: (_) => EditDeckCubit(deck: deck, editDeck: editDeck),
      child: EditDeckSheet(deck: deck),
    ),
  );

  @override
  State<EditDeckSheet> createState() => _EditDeckSheetState();
}

class _EditDeckSheetState extends State<EditDeckSheet> {
  // The current name comes selected, so typing replaces it.
  late final _name = TextEditingController(text: widget.deck.name)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.deck.name.length,
    );
  late String _language = widget.deck.language;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() => context.read<EditDeckCubit>().submit(
    name: _name.text,
    language: _language,
  );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<EditDeckCubit, EditDeckState>(
        listenWhen: (_, current) => current.status == EditDeckStatus.done,
        listener: (context, state) => Navigator.of(context).pop(state.deck),
        builder: (context, state) {
          final saving = state.status == EditDeckStatus.saving;

          return FormSheet(
            title: 'Edit deck',
            submitLabel: 'Save',
            savingLabel: 'Saving…',
            saving: saving,
            message: state.message,
            onSubmit: _submit,
            fields: [
              FormTextField(
                key: const Key('edit-deck-name'),
                label: 'Name',
                controller: _name,
                enabled: !saving,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              DeckLanguageField(
                key: const Key('edit-deck-language'),
                value: _language,
                enabled: !saving,
                onChanged: (label) => setState(() => _language = label),
              ),
            ],
          );
        },
      );
}
