import 'package:fishing_with_friends/core/router/app_router.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Bottom-nav shell: Feed | Catches | (FAB Log) | Tournaments | Profile.
class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  static const _tabs = <_NavTab>[
    _NavTab(AppRoutes.feed, Icons.dynamic_feed_outlined,
        Icons.dynamic_feed, 'Feed'),
    _NavTab(AppRoutes.catches, Icons.set_meal_outlined,
        Icons.set_meal, 'Catches'),
    _NavTab(AppRoutes.tournaments, Icons.emoji_events_outlined,
        Icons.emoji_events, 'Tournaments'),
    _NavTab(AppRoutes.profile, Icons.person_outline,
        Icons.person, 'Profile'),
  ];

  int _indexFor(String location) {
    final idx = _tabs.indexWhere((t) => location.startsWith(t.path));
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selected = _indexFor(location);

    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.push(AppRoutes.logCatch);
        },
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Log catch'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (i) {
            HapticFeedback.selectionClick();
            context.go(_tabs[i].path);
          },
          destinations: [
            for (final tab in _tabs)
              NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.activeIcon),
                label: tab.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _NavTab {
  const _NavTab(this.path, this.icon, this.activeIcon, this.label);
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
