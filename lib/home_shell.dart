import 'package:flutter/material.dart';

import 'pages/files_page.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'theme.dart';
import 'strings.dart';

/// Holds the three main sections and the floating pill bar to switch between them.
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
        bottomNavigationBar: _PillNavBar(index: _index, onSelect: _select),
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

class _PillNavBar extends StatelessWidget {
  const _PillNavBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < _destinations.length; i++)
                _NavItem(
                  destination: _destinations[i],
                  selected: i == index,
                  onTap: () => onSelect(i),
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
    final color = selected ? AppColors.primary : AppColors.navInactive;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label.tr,
      excludeSemantics: true,
      child: Tooltip(
        message: destination.label.tr,
        child: Material(
          color: selected ? Colors.white : Colors.transparent,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: selected ? 18 : 13, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(selected ? destination.selectedIcon : destination.icon, color: color, size: 22),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      Text(
                        destination.label.tr,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
