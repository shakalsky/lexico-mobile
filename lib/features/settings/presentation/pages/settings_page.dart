import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexico/app/injection.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/core/theme/app_typography.dart';
import 'package:lexico/core/widgets/app_notice.dart';
import 'package:lexico/features/decks/presentation/widgets/form_sheet.dart';
import 'package:lexico/features/settings/domain/entities/study_preferences.dart';
import 'package:lexico/features/settings/presentation/cubit/settings_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const SettingsPage());

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = sl<SettingsCubit>();
      unawaited(cubit.load());
      return cubit;
    },
    child: Scaffold(
      backgroundColor: AppColors.shell,
      appBar: AppBar(
        backgroundColor: AppColors.shell,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        title: Text('Settings', style: AppTypography.display(24)),
      ),
      body: BlocConsumer<SettingsCubit, SettingsState>(
        listenWhen: (previous, current) =>
            current.message != null && previous.message != current.message,
        listener: (context, state) =>
            AppNotices.show(context, state.message!, tone: AppNoticeTone.error),
        builder: (context, state) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text('STUDY', style: AppTypography.eyebrow()),
            ),
            _SwitchTile(
              key: const Key('repeat-missed-words'),
              title: 'Repeat missed words',
              subtitle:
                  'A word marked "review" goes back to the end of the '
                  'session until you get it right.',
              value: state.preferences.repeatMissedWords,
              onChanged: state.status == SettingsStatus.ready
                  ? (enabled) => context
                        .read<SettingsCubit>()
                        .repeatMissedWordsChanged(enabled: enabled)
                  : null,
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text('WORDS PER SESSION', style: AppTypography.eyebrow()),
            ),
            _WordsPerSession(
              value: state.preferences.wordsPerSession,
              onChanged: state.status == SettingsStatus.ready
                  ? context.read<SettingsCubit>().wordsPerSessionChanged
                  : null,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Preset tiles plus a field for any other amount.
class _WordsPerSession extends StatefulWidget {
  const _WordsPerSession({required this.value, required this.onChanged});

  final int value;

  /// `null` while the stored value is still loading.
  final ValueChanged<int>? onChanged;

  @override
  State<_WordsPerSession> createState() => _WordsPerSessionState();
}

class _WordsPerSessionState extends State<_WordsPerSession> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.value}',
  );
  final FocusNode _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_WordsPerSession oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the field in step when a tile is picked or a save is rolled back.
    if (oldWidget.value != widget.value) _showValue();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _showValue() {
    _controller.text = '${widget.value}';
    _error = null;
  }

  void _pick(int count) {
    _focus.unfocus();
    setState(_showValue);
    widget.onChanged?.call(count);
  }

  /// Saves what was typed, or puts the saved value back if it is not valid.
  void _commit() {
    final count = int.tryParse(_controller.text.trim());
    if (count == null || !StudyPreferences.isValidWordsPerSession(count)) {
      setState(_showValue);
      return;
    }
    widget.onChanged?.call(count);
  }

  void _validate(String text) {
    final count = int.tryParse(text.trim());
    setState(() {
      _error = count == null || !StudyPreferences.isValidWordsPerSession(count)
          ? 'Enter ${StudyPreferences.minWordsPerSession}–'
                '${StudyPreferences.maxWordsPerSession}'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final (index, count)
                in StudyPreferences.wordsPerSessionPresets.indexed) ...[
              if (index > 0) const SizedBox(width: 10),
              Expanded(
                child: _CountTile(
                  key: Key('words-per-session-$count'),
                  count: count,
                  selected: count == widget.value,
                  onTap: enabled ? () => _pick(count) : null,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custom amount',
                      style: AppTypography.body(
                        15.5,
                        color: AppColors.textPrimary,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _error ??
                          'Any number from '
                              '${StudyPreferences.minWordsPerSession} to '
                              '${StudyPreferences.maxWordsPerSession}.',
                      style: AppTypography.body(
                        13,
                        color: _error == null
                            ? AppColors.textMuted
                            : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 84,
                child: TextField(
                  key: const Key('words-per-session-input'),
                  controller: _controller,
                  focusNode: _focus,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  onChanged: _validate,
                  onSubmitted: (_) => _focus.unfocus(),
                  onTapOutside: (_) => _focus.unfocus(),
                  cursorColor: AppColors.accent,
                  style: formFieldTextStyle,
                  decoration: formFieldDecoration().copyWith(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.count,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final int count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '$count words',
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0x1F0CA678) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0x880CA678) : AppColors.hairline,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: AppTypography.display(
                28,
                color: selected ? AppColors.accentBright : AppColors.textBright,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'words',
              style: AppTypography.body(
                12,
                color: selected ? AppColors.accentDim : AppColors.textFaint,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool value;

  /// `null` while the stored value is still loading.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value ? const Color(0x550CA678) : AppColors.hairline,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body(
                      15.5,
                      color: AppColors.textPrimary,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: AppTypography.body(
                      13,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.onAccent,
              activeTrackColor: AppColors.accent,
              inactiveThumbColor: AppColors.textMuted,
              inactiveTrackColor: AppColors.track,
              trackOutlineColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.transparent
                    : AppColors.hairlineStrong,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
