import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/core/theme/app_typography.dart';
import 'package:lexico/features/decks/presentation/cubit/word_form_cubit.dart';
import 'package:lexico/features/decks/presentation/widgets/form_sheet.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';
import 'package:lexico/features/vocabulary/domain/entities/word_draft.dart';
import 'package:lexico/features/vocabulary/domain/usecases/add_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/edit_word.dart';

/// Bottom sheet for writing a word: a new one, or an edit of an existing one.
class WordSheet extends StatefulWidget {
  const WordSheet({super.key});

  /// Opens an empty sheet; completes with the added word, or `null` if the
  /// learner closed it.
  static Future<VocabWord?> showAdd(
    BuildContext context, {
    required String deckId,
    required AddWord addWord,
  }) => showFormSheet<VocabWord>(
    context,
    sheet: BlocProvider(
      create: (_) => WordFormCubit.add(deckId: deckId, addWord: addWord),
      child: const WordSheet(),
    ),
  );

  /// Opens the sheet filled in with [word]; completes with the word as
  /// saved, or `null` if the learner closed it.
  static Future<VocabWord?> showEdit(
    BuildContext context, {
    required VocabWord word,
    required EditWord editWord,
  }) => showFormSheet<VocabWord>(
    context,
    sheet: BlocProvider(
      create: (_) => WordFormCubit.edit(word: word, editWord: editWord),
      child: const WordSheet(),
    ),
  );

  @override
  State<WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends State<WordSheet> {
  late final VocabWord? _original = context.read<WordFormCubit>().original;
  late final _word = TextEditingController(text: _original?.questionShort);
  late final _meaning = TextEditingController(text: _original?.answerShort);
  late final _example = TextEditingController(text: _original?.questionExample);
  late final _translation = TextEditingController(
    text: _original?.answerExample,
  );

  @override
  void dispose() {
    _word.dispose();
    _meaning.dispose();
    _example.dispose();
    _translation.dispose();
    super.dispose();
  }

  void _submit() => context.read<WordFormCubit>().submit(
    WordDraft(
      questionShort: _word.text,
      answerShort: _meaning.text,
      questionExample: _example.text,
      answerExample: _translation.text,
    ),
  );

  /// The optional word and meaning start hidden under a chevron.
  bool _showShortFields = false;

  /// What the hidden fields hold, so a collapsed row still shows it.
  String? get _shortSummary {
    final parts = [
      _word.text.trim(),
      _meaning.text.trim(),
    ].where((part) => part.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<WordFormCubit, WordFormState>(
        listenWhen: (_, current) => current.status == WordFormStatus.saved,
        listener: (context, state) => Navigator.of(context).pop(state.word),
        builder: (context, state) {
          final saving = state.status == WordFormStatus.saving;
          final isEdit = _original != null;

          return FormSheet(
            title: isEdit ? 'Edit word' : 'New word',
            submitLabel: isEdit ? 'Save' : 'Add word',
            savingLabel: isEdit ? 'Saving…' : 'Adding…',
            saving: saving,
            message: state.message,
            onSubmit: _submit,
            fields: [
              FormTextField(
                key: const Key('word-form-example'),
                label: 'Example sentence',
                hint: 'e.g. Compro pan cada mañana.',
                controller: _example,
                enabled: !saving,
                maxLines: 3,
                // A new word starts typing at once; an edit shows the word
                // first, keyboard down.
                autofocus: !isEdit,
              ),
              FormTextField(
                key: const Key('word-form-translation'),
                label: 'Translation',
                hint: 'e.g. I buy bread every morning.',
                controller: _translation,
                enabled: !saving,
                maxLines: 3,
                textInputAction: _showShortFields
                    ? TextInputAction.next
                    : TextInputAction.done,
                onSubmitted: _showShortFields ? null : (_) => _submit(),
              ),
              _ShortFieldsToggle(
                expanded: _showShortFields,
                summary: _shortSummary,
                onPressed: () =>
                    setState(() => _showShortFields = !_showShortFields),
              ),
              if (_showShortFields) ...[
                FormTextField(
                  key: const Key('word-form-word'),
                  label: 'Word',
                  note: 'leave empty for a sentence card',
                  hint: 'e.g. el pan',
                  controller: _word,
                  enabled: !saving,
                ),
                FormTextField(
                  key: const Key('word-form-meaning'),
                  label: 'Meaning',
                  hint: 'e.g. bread',
                  controller: _meaning,
                  enabled: !saving,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ],
          );
        },
      );
}

/// The chevron row that shows or hides the optional word and meaning.
class _ShortFieldsToggle extends StatelessWidget {
  const _ShortFieldsToggle({
    required this.expanded,
    required this.summary,
    required this.onPressed,
  });

  final bool expanded;

  /// The current word and meaning, shown while they are hidden.
  final String? summary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;

    return Semantics(
      button: true,
      expanded: expanded,
      child: GestureDetector(
        key: const Key('word-form-more'),
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: 'WORD AND MEANING',
                        children: [
                          TextSpan(
                            text: '  ·  optional',
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
                    if (!expanded && summary != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        summary,
                        style: AppTypography.body(
                          14,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(
                  Icons.expand_more_rounded,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
