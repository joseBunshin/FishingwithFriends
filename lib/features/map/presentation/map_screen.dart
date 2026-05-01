import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  bool _showFriends = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catch Map'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Row(
              children: [
                Switch(
                  value: _showFriends,
                  onChanged: (v) => setState(() => _showFriends = v),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Text('Show Friends'),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Legend(),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.mist.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
                alignment: Alignment.center,
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 64),
                      SizedBox(height: AppSpacing.md),
                      Text(
                        'Catch map arrives in M4',
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        'flutter_map + heatmap mode + Marine Protected Area awareness',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _Dot(color: AppColors.navy, label: 'Yours'),
        SizedBox(width: AppSpacing.lg),
        _Dot(color: AppColors.success, label: 'Friends'),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
