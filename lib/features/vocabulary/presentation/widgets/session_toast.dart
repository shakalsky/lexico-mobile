import 'package:flutter/material.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/core/theme/app_typography.dart';
import 'package:lexico/features/vocabulary/presentation/bloc/study/study_bloc.dart';

/// The confirmation strip that rises after each answer.
class SessionToast extends StatelessWidget {
  const SessionToast({required this.toast, super.key});

  /// `null` hides the strip; the last message stays until it is replaced.
  final StudyToast? toast;

  @override
  Widget build(BuildContext context) {
    final visible = toast != null;
    final positive = toast?.isPositive ?? true;

    return IgnorePointer(
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.35),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: positive
                  ? const Color(0x290CA678)
                  : const Color(0x21FF8A8A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: positive
                    ? const Color(0x550CA678)
                    : const Color(0x59FF8A8A),
              ),
            ),
            child: Text(
              toast?.message ?? '',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(
                13.5,
                color: positive
                    ? AppColors.accentBright
                    : AppColors.dangerBright,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
