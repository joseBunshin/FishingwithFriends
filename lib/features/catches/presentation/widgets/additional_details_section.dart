import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Collapsible "Additional Details" section that lives below the main fields.
/// Holds notes, rig/lure, and a stub for the Conditions block (M6).
class AdditionalDetailsSection extends StatelessWidget {
  const AdditionalDetailsSection({
    required this.notesController,
    required this.rigController,
    super.key,
  });

  final TextEditingController notesController;
  final TextEditingController rigController;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          title: Text(
            'Additional Details',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          children: [
            TextFormField(
              controller: rigController,
              decoration: const InputDecoration(
                labelText: 'Rig / lure / bait',
                prefixIcon: Icon(Icons.settings_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _ConditionsStub(),
          ],
        ),
      ),
    );
  }
}

class _ConditionsStub extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_outlined, color: scheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Conditions',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  'Weather, water temp, tide, moon — auto-filled in M6.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
