import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Two stacked toggles below the map app bar: Show Friends, Heatmap mode.
class MapControls extends StatelessWidget {
  const MapControls({
    required this.showFriends,
    required this.heatmap,
    required this.onShowFriendsChanged,
    required this.onHeatmapChanged,
    super.key,
  });

  final bool showFriends;
  final bool heatmap;
  final ValueChanged<bool> onShowFriendsChanged;
  final ValueChanged<bool> onHeatmapChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.paper,
      child: Row(
        children: [
          Expanded(
            child: _ToggleTile(
              icon: Icons.people_outline,
              label: 'Show friends',
              value: showFriends,
              onChanged: onShowFriendsChanged,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _ToggleTile(
              icon: Icons.blur_on,
              label: 'Heatmap',
              value: heatmap,
              onChanged: onHeatmapChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.navy),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
