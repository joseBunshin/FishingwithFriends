import 'package:fishing_with_friends/core/router/app_router.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Bottom-nav shell with a raised, dead-center Log button. 7 destinations
/// flank the center FAB (4 left + 3 right) for a total of 8 surfaces, but
/// Log feels distinct from the rest — bigger, navy, slightly elevated,
/// the obvious "log a fish" CTA wherever you are in the app.
class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  // 3 left + center Log FAB + 3 right = 7 destinations total. Symmetric
  // tab counts mean the middle gap (and the raised Log button overlaid on
  // it) lands at the exact horizontal center. Stats was dropped from
  // bottom nav — still accessible via /stats from Home + Me, but it
  // didn't earn a tab slot once we reduced for symmetry.
  static const List<_NavTab> _leftTabs = [
    _NavTab(AppRoutes.home, Icons.home_outlined, Icons.home, 'Home'),
    _NavTab(AppRoutes.catches, Icons.set_meal_outlined, Icons.set_meal, 'Catches'),
    _NavTab(
      AppRoutes.tourneys,
      Icons.emoji_events_outlined,
      Icons.emoji_events,
      'Tourneys',
    ),
  ];

  static const List<_NavTab> _rightTabs = [
    _NavTab(AppRoutes.map, Icons.location_on_outlined, Icons.location_on, 'Map'),
    _NavTab(AppRoutes.friends, Icons.people_outline, Icons.people, 'Friends'),
    _NavTab(AppRoutes.me, Icons.person_outline, Icons.person, 'Me'),
  ];

  static List<_NavTab> get _allTabs => [..._leftTabs, ..._rightTabs];

  bool _isSelected(String location, _NavTab tab) {
    return location.startsWith(tab.path);
  }

  void _onTab(BuildContext context, _NavTab tab) {
    HapticFeedback.selectionClick();
    context.go(tab.path);
  }

  void _onLog(BuildContext context) {
    HapticFeedback.mediumImpact();
    context.push(AppRoutes.logCatch);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Log button color — navy in light, orange in dark for contrast against
    // dark surfaces. Foreground always white.
    final logBg = isDark ? AppColors.orange : AppColors.navy;

    return Scaffold(
      body: child,
      extendBody: true,
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Underlying nav bar — surface fill + hairline top border.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border(
                      top: BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                  child: Row(
                    children: [
                      for (final tab in _leftTabs)
                        Expanded(
                          child: _NavItem(
                            tab: tab,
                            selected: _isSelected(location, tab),
                            onTap: () => _onTab(context, tab),
                          ),
                        ),
                      // Center spacer reserved for the raised Log button.
                      const SizedBox(width: 72),
                      for (final tab in _rightTabs)
                        Expanded(
                          child: _NavItem(
                            tab: tab,
                            selected: _isSelected(location, tab),
                            onTap: () => _onTab(context, tab),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Raised Log button — overlaps the top of the bar.
              Positioned(
                top: -22,
                left: 0,
                right: 0,
                child: Center(
                  child: _RaisedLogButton(
                    background: logBg,
                    onTap: () => _onLog(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// For tests / external introspection.
  @visibleForTesting
  static List<String> get tabPaths =>
      _allTabs.map((t) => t.path).toList(growable: false);
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _NavTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: 0.6);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? tab.activeIcon : tab.icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(
              tab.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RaisedLogButton extends StatelessWidget {
  const _RaisedLogButton({required this.background, required this.onTap});

  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        elevation: 6,
        shadowColor: AppColors.navy.withValues(alpha: 0.3),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const Center(
            child: Icon(
              Icons.add,
              size: 32,
              color: AppColors.white,
            ),
          ),
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
