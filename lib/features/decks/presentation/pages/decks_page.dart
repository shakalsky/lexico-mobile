import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lexico/app/injection.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/core/theme/app_typography.dart';
import 'package:lexico/core/widgets/app_notice.dart';
import 'package:lexico/core/widgets/swipe_to_delete.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/domain/usecases/create_deck.dart';
import 'package:lexico/features/decks/domain/usecases/edit_deck.dart';
import 'package:lexico/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:lexico/features/decks/presentation/pages/deck_words_page.dart';
import 'package:lexico/features/decks/presentation/widgets/edit_deck_sheet.dart';
import 'package:lexico/features/decks/presentation/widgets/new_deck_sheet.dart';
import 'package:lexico/features/vocabulary/domain/usecases/add_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/delete_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/edit_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/get_deck_words.dart';
import 'package:lexico/features/vocabulary/domain/usecases/refresh_deck_words.dart';
import 'package:lexico/features/vocabulary/domain/usecases/watch_sync_conflicts.dart';
import 'package:lexico/features/vocabulary/presentation/widgets/primary_button.dart';

/// The Decks tab: every deck on the word service.
class DecksPage extends StatelessWidget {
  const DecksPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => sl<DecksBloc>()..add(const DecksRequested()),
    child: DecksView(
      createDeck: sl<CreateDeck>(),
      editDeck: sl<EditDeck>(),
      getDeckWords: sl<GetDeckWords>(),
      refreshDeckWords: sl<RefreshDeckWords>(),
      watchSyncConflicts: sl<WatchSyncConflicts>(),
      addWord: sl<AddWord>(),
      editWord: sl<EditWord>(),
      deleteWord: sl<DeleteWord>(),
    ),
  );
}

class DecksView extends StatelessWidget {
  const DecksView({
    required this.createDeck,
    required this.editDeck,
    required this.getDeckWords,
    required this.refreshDeckWords,
    required this.watchSyncConflicts,
    required this.addWord,
    required this.editWord,
    required this.deleteWord,
    super.key,
  });

  /// Used by the "New deck" sheet.
  final CreateDeck createDeck;

  /// Used by the sheet a long press on a deck opens.
  final EditDeck editDeck;

  /// Used by the page a deck tile opens.
  final GetDeckWords getDeckWords;
  final RefreshDeckWords refreshDeckWords;
  final WatchSyncConflicts watchSyncConflicts;
  final AddWord addWord;
  final EditWord editWord;
  final DeleteWord deleteWord;

  Future<void> _addDeck(BuildContext context) async {
    final bloc = context.read<DecksBloc>();
    final notices = AppNotices.of(context);

    final deck = await NewDeckSheet.show(context, createDeck: createDeck);
    if (deck == null) return;

    bloc.add(DeckAdded(deck));
    notices.show('Created “${deck.name}”');
  }

  Future<void> _editDeck(BuildContext context, Deck deck) async {
    final bloc = context.read<DecksBloc>();
    final notices = AppNotices.of(context);

    final edited = await EditDeckSheet.show(
      context,
      deck: deck,
      editDeck: editDeck,
    );
    if (edited == null) return;

    bloc.add(DeckUpdated(edited));
    notices.show('Saved “${edited.name}”');
  }

  /// Called once the learner confirmed; a failure is reported by the bloc.
  Future<void> _deleteDeck(BuildContext context, Deck deck) async {
    final notices = AppNotices.of(context);
    final done = Completer<bool>();
    context.read<DecksBloc>().add(DeckDeleteConfirmed(deck, done));
    if (await done.future) notices.show('Deleted “${deck.name}”');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.shell,
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('new-deck'),
      onPressed: () => _addDeck(context),
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.onAccent,
      icon: const Icon(Icons.add),
      label: Text(
        'New deck',
        style: AppTypography.body(
          14,
          color: AppColors.onAccent,
          weight: FontWeight.w700,
        ),
      ),
    ),
    body: SafeArea(
      child: BlocConsumer<DecksBloc, DecksState>(
        listenWhen: (previous, current) =>
            current.notice != null && current.notice != previous.notice,
        listener: (context, state) =>
            AppNotices.show(context, state.notice!, tone: AppNoticeTone.error),
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            Expanded(
              child: switch (state.status) {
                DecksStatus.initial ||
                DecksStatus.loading => const _DecksLoading(),
                DecksStatus.failure => _DecksError(message: state.message),
                DecksStatus.ready => _DeckList(
                  state: state,
                  onDeckDeleted: (deck) => _deleteDeck(context, deck),
                  onDeckLongPressed: (deck) => _editDeck(context, deck),
                  onDeckTapped: (deck) => Navigator.of(context).push(
                    DeckWordsPage.route(
                      deck,
                      getDeckWords: getDeckWords,
                      refreshDeckWords: refreshDeckWords,
                      watchSyncConflicts: watchSyncConflicts,
                      addWord: addWord,
                      editWord: editWord,
                      deleteWord: deleteWord,
                    ),
                  ),
                ),
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(26, 20, 26, 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Decks', style: AppTypography.display(32)),
        const SizedBox(height: 10),
        Text(
          'Every deck on the word service.',
          style: AppTypography.body(14, color: AppColors.textMuted),
        ),
      ],
    ),
  );
}

class _DecksLoading extends StatelessWidget {
  const _DecksLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      width: 26,
      height: 26,
      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
    ),
  );
}

class _DecksError extends StatelessWidget {
  const _DecksError({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 26),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Couldn't load decks",
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
          onPressed: () =>
              context.read<DecksBloc>().add(const DecksRequested()),
        ),
      ],
    ),
  );
}

class _DeckList extends StatelessWidget {
  const _DeckList({
    required this.state,
    required this.onDeckTapped,
    required this.onDeckLongPressed,
    required this.onDeckDeleted,
  });

  final DecksState state;
  final ValueChanged<Deck> onDeckTapped;

  /// Opens the edit sheet.
  final ValueChanged<Deck> onDeckLongPressed;

  /// The learner swiped a deck away and confirmed.
  final ValueChanged<Deck> onDeckDeleted;

  List<Deck> get decks => state.decks;

  Future<void> _refresh(BuildContext context) {
    final done = Completer<void>();
    context.read<DecksBloc>().add(DecksRefreshed(done));
    return done.future;
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: AppColors.accent,
    backgroundColor: AppColors.surfaceRaised,
    onRefresh: () => _refresh(context),
    child: decks.isEmpty
        // Still scrollable, so pull to refresh works on an empty list.
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 80),
            children: [
              Text(
                'No decks yet',
                textAlign: TextAlign.center,
                style: AppTypography.displayItalic(26),
              ),
            ],
          )
        : ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(26, 0, 26, 96),
            itemCount: decks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final deck = decks[index];
              return SwipeToDelete(
                id: deck.id,
                borderRadius: 16,
                title: 'Delete deck?',
                message:
                    '“${deck.name}”, all its words and their progress will '
                    "be deleted. This can't be undone.",
                onDeleted: () => onDeckDeleted(deck),
                child: _DeckTile(
                  deck: deck,
                  isStudied: state.isStudied(deck),
                  onTap: () => onDeckTapped(deck),
                  onLongPress: () => onDeckLongPressed(deck),
                  onStudyToggled: () =>
                      context.read<DecksBloc>().add(DeckStudyToggled(deck.id)),
                ),
              );
            },
          ),
  );
}

class _DeckTile extends StatefulWidget {
  const _DeckTile({
    required this.deck,
    required this.isStudied,
    required this.onTap,
    required this.onLongPress,
    required this.onStudyToggled,
  });

  final Deck deck;
  final bool isStudied;

  /// Opens the deck. The Study button handles its own taps.
  final VoidCallback onTap;

  /// Called with a haptic tap once the press has been held long enough.
  final VoidCallback onLongPress;
  final VoidCallback onStudyToggled;

  @override
  State<_DeckTile> createState() => _DeckTileState();
}

/// While a finger rests on the tile it shrinks, reaching its smallest just
/// as the press counts as long. Letting go early, scrolling or swiping
/// springs it back.
class _DeckTileState extends State<_DeckTile>
    with SingleTickerProviderStateMixin {
  static const _pressedScale = 0.95;

  late final _press = AnimationController(
    vsync: this,
    duration: kLongPressTimeout,
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: _pressedScale,
  ).animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _release() => _press.reverse();

  void _longPressed() {
    _release();
    unawaited(switch (Theme.of(context).platform) {
      // Android's own long-press haptic.
      TargetPlatform.android => HapticFeedback.vibrate(),
      _ => HapticFeedback.mediumImpact(),
    });
    widget.onLongPress();
  }

  @override
  Widget build(BuildContext context) {
    final deck = widget.deck;
    final isStudied = widget.isStudied;
    final added = DateFormat.yMMMd().format(deck.createdAt.toLocal());

    return GestureDetector(
      key: Key('deck-${deck.id}'),
      onTap: widget.onTap,
      onLongPressDown: (_) => _press.forward(),
      onLongPressCancel: _release,
      onLongPress: _longPressed,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scale,
        child: _tile(deck, isStudied, added),
      ),
    );
  }

  Widget _tile(Deck deck, bool isStudied, String added) => Container(
    padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isStudied ? const Color(0x550CA678) : AppColors.hairline,
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deck.name,
                style: AppTypography.word(18),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                '${deck.language} · added $added',
                style: AppTypography.body(13, color: AppColors.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _StudyButton(
          key: Key('study-${deck.id}'),
          isStudied: isStudied,
          onPressed: widget.onStudyToggled,
        ),
      ],
    ),
  );
}

/// "Study" adds the deck to the rotation; "Studying" takes it out again.
class _StudyButton extends StatelessWidget {
  const _StudyButton({
    required this.isStudied,
    required this.onPressed,
    super.key,
  });

  final bool isStudied;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = isStudied ? AppColors.accentBright : AppColors.textSecondary;

    return Semantics(
      button: true,
      toggled: isStudied,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isStudied ? const Color(0x1F0CA678) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isStudied
                  ? const Color(0x550CA678)
                  : AppColors.hairlineStrong,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isStudied ? Icons.check_rounded : Icons.add_rounded,
                size: 15,
                color: color,
              ),
              const SizedBox(width: 5),
              Text(
                isStudied ? 'Studying' : 'Study',
                style: AppTypography.body(
                  12.5,
                  color: color,
                  weight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
