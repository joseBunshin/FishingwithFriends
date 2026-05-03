import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Optional inline conditions block on the catch detail screen. Renders
/// only when `catch.conditions` has any of the recognized fields.
class ConditionsBlock extends StatelessWidget {
  const ConditionsBlock({required this.conditions, super.key});

  final Map<String, dynamic> conditions;

  @override
  Widget build(BuildContext context) {
    final pills = <Widget>[];
    final tempC = conditions['temp_c'];
    if (tempC is num) {
      pills.add(_pill(Icons.thermostat_outlined,
          '${tempC.toStringAsFixed(0)}°C'));
    }
    final wind = conditions['wind_kph'];
    if (wind is num) {
      pills.add(_pill(Icons.air, '${wind.toStringAsFixed(0)} kph'));
    }
    final waterTemp = conditions['water_temp_c'];
    if (waterTemp is num) {
      pills.add(_pill(Icons.waves,
          'water ${waterTemp.toStringAsFixed(0)}°C'));
    }
    final tide = conditions['tide_state'];
    if (tide is String) {
      pills.add(_pill(Icons.water_drop_outlined, '$tide tide'));
    }
    final moon = conditions['moon_phase'];
    if (moon is num) {
      pills.add(_pill(Icons.brightness_3, _moonLabel(moon.toDouble())));
    }
    if (pills.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Conditions',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: pills,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _pill(IconData icon, String label) {
    return _Pill(icon: icon, label: label);
  }

  static String _moonLabel(double phase) {
    if (phase < 0.05 || phase > 0.95) return 'New moon';
    if (phase < 0.20) return 'Waxing crescent';
    if (phase < 0.30) return 'First quarter';
    if (phase < 0.45) return 'Waxing gibbous';
    if (phase < 0.55) return 'Full moon';
    if (phase < 0.70) return 'Waning gibbous';
    if (phase < 0.80) return 'Last quarter';
    return 'Waning crescent';
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.navy),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
