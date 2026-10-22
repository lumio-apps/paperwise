import 'package:flutter/material.dart';

import 'pages/files_page.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'theme.dart';
import 'strings.dart';

/// Holds the three main sections and the bottom bar to switch between them.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      // On Files or Settings, the back button returns to Home first.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _index,
            children: [
              HomePage(onSeeAllFiles: () => _select(1)),
              const FilesPage(),
              const SettingsPage(),
            ],
          ),
        ),
        bottomNavigationBar: _NavBar(index: _index, onSelect: _select),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _NavDestination('Home', Icons.home_outlined, Icons.home_rounded),
  _NavDestination('Files', Icons.folder_outlined, Icons.folder_rounded),
  _NavDestination('Settings', Icons.settings_outlined, Icons.settings_rounded),
];

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (var i = 0; i < _destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: _destinations[i],
                    selected: i == index,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.destination, required this.selected, required this.onTap});

  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.muted;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label.tr,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? AppColors.track : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(selected ? destination.selectedIcon : destination.icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              destination.label.tr,
              style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
