import 'package:flutter/material.dart';
import 'package:lexico/app/shell/placeholder_tab.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/features/settings/presentation/pages/settings_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderTab(
    title: 'Profile',
    subtitle: 'Your daily goal, streak history and achievements.',
    action: IconButton(
      tooltip: 'Settings',
      icon: const Icon(Icons.settings_outlined),
      iconSize: 20,
      color: AppColors.textSecondary,
      // Let the header's fixed square decide the size instead of the
      // default 48px tap target.
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.hairline),
      ),
      onPressed: () => Navigator.of(context).push(SettingsPage.route()),
    ),
  );
}
