import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/core/theme/app_typography.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/presentation/cubit/deck_words_cubit.dart';
import 'package:lexico/features/decks/presentation/widgets/word_sheet.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/add_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/edit_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/get_deck_words.dart';
import 'package:lexico/features/vocabulary/presentation/widgets/primary_button.dart';

/// One deck and all of its words, in deck order.
class DeckWordsPage extends StatelessWidget {
  const DeckWordsPage({
    required this.deck,
    required this.addWord,
    required this.editWord,
    super.key,
  });

  final Deck deck;

  /// Used by the word sheet, to add and to edit.
  final AddWord addWord;
  final EditWord editWord;

  static Route<void> route(
    Deck deck, {
    required GetDeckWords getDeckWords,
    required AddWord addWord,
    required EditWord editWord,
  }) => MaterialPageRoute(
    builder: (_) => BlocProvider(
      create: (_) =>
          DeckWordsCubit(deckId: deck.id, getDeckWords: getDeckWords)..load(),
      child: DeckWordsPage(deck: deck, addWord: addWord, editWord: editWord),
    ),
  );

  Future<void> _addWord(BuildContext context) async {
    final cubit = context.read<DeckWordsCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final word = await WordSheet.showAdd(
      context,
      deckId: deck.id,
      addWord: addWord,
    );
    if (word == null) return;

    await cubit.wordAdded(word);
    _confirm(messenger, 'Added “${word.question}”');
  }

  Future<void> _editWord(BuildContext context, VocabWord word) async {
    final cubit = context.read<DeckWordsCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final saved = await WordSheet.showEdit(
      context,
      word: word,
      editWord: editWord,
    );
    // Closed, or saved without changes.
    if (saved == null || saved == word) return;

    cubit.wordEdited(saved);
    _confirm(messenger, 'Saved “${saved.question}”');
  }

  void _confirm(ScaffoldMessengerState messenger, String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.shell,
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('new-word'),
      onPressed: () => _addWord(context),
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.onAccent,
      icon: const Icon(Icons.add),
      label: Text(
        'New word',
        style: AppTypography.body(
          14,
          color: AppColors.onAccent,
          weight: FontWeight.w700,
        ),
      ),
    ),
    appBar: AppBar(
      backgroundColor: AppColors.shell,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
    ),
    body: BlocConsumer<DeckWordsCubit, DeckWordsState>(
      listenWhen: (previous, current) =>
          current.notice != null && current.notice != previous.notice,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(state.notice!))),
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(deck: deck, state: state),
          Expanded(
            child: switch (state.status) {
              DeckWordsStatus.loading => const _Loading(),
              DeckWordsStatus.failure => _Error(message: state.message),
              DeckWordsStatus.ready => _WordList(
                words: state.words,
                onWordTapped: (word) => _editWord(context, word),
              ),
            },
          ),
        ],
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.deck, required this.state});

  final Deck deck;
  final DeckWordsState state;

  @override
  Widget build(BuildContext context) {
    final count = state.words.length;
    final details = state.status == DeckWordsStatus.ready
        ? '${deck.language} · ${count == 1 ? '1 word' : '$count words'}'
        : deck.language;

    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 4, 26, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(deck.name, style: AppTypography.display(32)),
          const SizedBox(height: 10),
          Text(
            details,
            style: AppTypography.body(14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      width: 26,
      height: 26,
      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
    ),
  );
}

class _Error extends StatelessWidget {
  const _Error({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 26),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Couldn't load words",
          style: AppTypography.display(28),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          message ?? 'Please try again.',
          textAlign: TextAlign.center,
          style: AppTypography.body(14, color: AppColors.textMuted),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: 'Try again',
          onPressed: () => context.read<DeckWordsCubit>().load(),
        ),
      ],
    ),
  );
}

class _WordList extends StatelessWidget {
  const _WordList({required this.words, required this.onWordTapped});

  final List<VocabWord> words;
  final ValueChanged<VocabWord> onWordTapped;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: AppColors.accent,
    backgroundColor: AppColors.surfaceRaised,
    onRefresh: () => context.read<DeckWordsCubit>().refresh(),
    child: words.isEmpty
        // Still scrollable, so pull to refresh works on an empty list.
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 80),
            children: [
              Text(
                'No words in this deck yet',
                textAlign: TextAlign.center,
                style: AppTypography.displayItalic(26),
              ),
            ],
          )
        : ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(26, 0, 26, 96),
            itemCount: words.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final word = words[index];
              return _WordTile(word: word, onTap: () => onWordTapped(word));
            },
          ),
  );
}

class _WordTile extends StatelessWidget {
  const _WordTile({required this.word, required this.onTap});

  final VocabWord word;

  /// Opens the word for editing.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: Key('word-${word.id}'),
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: _tile(),
  );

  Widget _tile() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.hairline),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                word.question,
                style: AppTypography.display(
                  word.isSentence ? 18 : 21,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                word.answer,
                style: AppTypography.body(13.5, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _WordScore(word: word),
      ],
    ),
  );
}

/// How the learner has done on this word so far, as counted by the service.
class _WordScore extends StatelessWidget {
  const _WordScore({required this.word});

  final VocabWord word;

  @override
  Widget build(BuildContext context) {
    final shows = word.showsCount;
    if (shows == 0) {
      return Text(
        'new',
        style: AppTypography.body(12, color: AppColors.textFaint),
      );
    }

    final percent = (word.successesCount / shows * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          percent == 0 ? '-' : '$percent%',
          style: AppTypography.body(
            13.5,
            color: percent >= 70 ? AppColors.accentBright : AppColors.danger,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Semantics(
          label: 'Seen $shows times',
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A tight line box, so the digits center on the icon instead
              // of sitting low under the theme's inherited 1.43 line height.
              Text(
                '$shows',
                style: AppTypography.body(
                  11.5,
                  color: AppColors.textFaint,
                  height: 1,
                ).copyWith(leadingDistribution: TextLeadingDistribution.even),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.visibility_outlined,
                size: 13,
                color: AppColors.textFaint,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
