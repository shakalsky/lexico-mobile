import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexico/core/theme/app_colors.dart';
import 'package:lexico/core/theme/app_typography.dart';
import 'package:lexico/features/decks/presentation/pages/decks_page.dart';
import 'package:lexico/features/profile/presentation/pages/profile_page.dart';
import 'package:lexico/features/vocabulary/presentation/bloc/home/home_bloc.dart';
import 'package:lexico/features/vocabulary/presentation/pages/home_page.dart';

/// Root screen: holds the three main tabs and the bottom navigation bar.
/// Tabs live in an [IndexedStack] so each keeps its state when switching.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = [
    _Tab(
      label: 'Today',
      icon: Icons.wb_sunny_outlined,
      selectedIcon: Icons.wb_sunny,
    ),
    _Tab(label: 'Decks', icon: Icons.style_outlined, selectedIcon: Icons.style),
    _Tab(
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

  void _select(int index) {
    // Other tabs can change what Today shows (e.g. which decks are studied),
    // so re-read its numbers whenever it comes back into view.
    if (index == 0 && _index != 0) {
      context.read<HomeBloc>().add(const HomeRefreshed());
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.shell,
    body: IndexedStack(
      index: _index,
      children: const [HomePage(), DecksPage(), ProfilePage()],
    ),
    bottomNavigationBar: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppColors.shell,
          surfaceTintColor: Colors.transparent,
          indicatorColor: const Color(0x1F0CA678),
          height: 68,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => AppTypography.body(
              11.5,
              color: states.contains(WidgetState.selected)
                  ? AppColors.accentBright
                  : AppColors.textFaint,
              weight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              size: 22,
              color: states.contains(WidgetState.selected)
                  ? AppColors.accentBright
                  : AppColors.textFaint,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: [
            for (final tab in _tabs)
              NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.selectedIcon),
                label: tab.label,
              ),
          ],
        ),
      ),
    ),
  );
}

class _Tab {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
