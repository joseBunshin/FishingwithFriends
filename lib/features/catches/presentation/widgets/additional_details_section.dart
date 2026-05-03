import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Collapsible "Additional Details" section that lives below the main fields.
/// Holds notes and rig/lure. Conditions used to live here as a stub
/// promising "auto-filled in M6" — that shipped, conditions populate
/// post-save and surface on the catch detail screen, so the stub is gone.
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
            // hintText (not labelText) so the placeholder simply
            // disappears on focus instead of floating up to the top-left
            // of the field — that floating animation read as "weird"
            // to users.
            TextFormField(
              controller: rigController,
              decoration: const InputDecoration(
                hintText: 'Rig / lure / bait',
                prefixIcon: Icon(Icons.settings_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Notes',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
