import 'package:fishing_with_friends/core/router/app_router.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Bottom-nav shell with 8 tabs (Lovable parity).
/// Order: Home / Catches / Log / Stats / Tourneys / Map / Friends / Me.
/// `Log` pushes the catch-creation screen rather than rendering inside the shell.
class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  static const List<_NavTab> _tabs = [
    _NavTab(AppRoutes.home, Icons.home_outlined, Icons.home, 'Home'),
    _NavTab(
      AppRoutes.catches,
      Icons.set_meal_outlined,
      Icons.set_meal,
      'Catches',
    ),
    _NavTab(
      AppRoutes.logCatch,
      Icons.add_circle_outline,
      Icons.add_circle,
      'Log',
      isLog: true,
    ),
    _NavTab(
      AppRoutes.stats,
      Icons.bar_chart_outlined,
      Icons.bar_chart,
      'Stats',
    ),
    _NavTab(
      AppRoutes.tourneys,
      Icons.emoji_events_outlined,
      Icons.emoji_events,
      'Tourneys',
    ),
    _NavTab(
      AppRoutes.map,
      Icons.location_on_outlined,
      Icons.location_on,
      'Map',
    ),
    _NavTab(
      AppRoutes.friends,
      Icons.people_outline,
      Icons.people,
      'Friends',
    ),
    _NavTab(AppRoutes.me, Icons.person_outline, Icons.person, 'Me'),
  ];

  int _indexFor(String location) {
    final idx = _tabs.indexWhere(
      (t) => !t.isLog && location.startsWith(t.path),
    );
    return idx < 0 ? 0 : idx;
  }

  void _onSelected(BuildContext context, int i) {
    final tab = _tabs[i];
    if (tab.isLog) {
      HapticFeedback.mediumImpact();
      context.push(tab.path);
      return;
    }
    HapticFeedback.selectionClick();
    context.go(tab.path);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selected = _indexFor(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.mist, width: 1),
            ),
          ),
          child: NavigationBar(
            selectedIndex: selected,
            onDestinationSelected: (i) => _onSelected(context, i),
            destinations: [
              for (final tab in _tabs)
                NavigationDestination(
                  icon: Icon(tab.icon),
                  selectedIcon: Icon(
                    tab.activeIcon,
                    color: tab.isLog ? AppColors.orange : null,
                  ),
                  label: tab.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  const _NavTab(
    this.path,
    this.icon,
    this.activeIcon,
    this.label, {
    this.isLog = false,
  });

  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isLog;
}
