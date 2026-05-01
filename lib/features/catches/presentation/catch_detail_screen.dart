import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/catches/presentation/widgets/catch_photo_carousel.dart';
import 'package:fishing_with_friends/features/feed/presentation/widgets/comment_list.dart';
import 'package:fishing_with_friends/features/storytelling/presentation/widgets/catch_comparison_line.dart';
import 'package:fishing_with_friends/features/tournaments/presentation/submit_entry_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CatchDetailScreen extends ConsumerWidget {
  const CatchDetailScreen({required this.catchId, super.key});

  final String catchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCatch = ref.watch(catchByIdProvider(catchId));

    return Scaffold(
      body: asyncCatch.when(
        data: (c) => c == null
            ? const _NotAvailable()
            : _Body(catch_: c),
        loading: () => const _Loading(),
        error: (_, __) => const _NotAvailable(),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.catch_});

  final Catch catch_;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.navy,
          foregroundColor: AppColors.white,
          expandedHeight: 320,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              tooltip: 'Submit to tournament',
              icon: const Icon(Icons.emoji_events_outlined),
              onPressed: () => SubmitEntrySheet.pickTournament(
                context,
                source: catch_,
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: CatchPhotoCarousel(
              catchId: catch_.id,
              photoPaths: catch_.photoPaths,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Headline(catch_: catch_),
                const SizedBox(height: AppSpacing.sm),
                CatchComparisonLine(catchId: catch_.id),
                const SizedBox(height: AppSpacing.md),
                _MeasurementRow(catch_: catch_),
                const SizedBox(height: AppSpacing.lg),
                _MetadataCard(catch_: catch_),
                if (catch_.rig != null && catch_.rig!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _LabeledLine(label: 'Rig', value: catch_.rig!),
                ],
                if (catch_.notes != null && catch_.notes!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _NotesBlock(notes: catch_.notes!),
                ],
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Comments',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                CommentList(catchId: catch_.id),
                const Divider(),
                CommentComposer(catchId: catch_.id),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.catch_});

  final Catch catch_;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          catch_.speciesLabel ?? 'Unknown species',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          DateFormat.yMMMd().add_jm().format(catch_.caughtAt.toLocal()),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _MeasurementRow extends StatelessWidget {
  const _MeasurementRow({required this.catch_});

  final Catch catch_;

  @override
  Widget build(BuildContext context) {
    final pills = <Widget>[];
    if (catch_.weightKg != null) {
      final lbs = (catch_.weightKg! * 2.20462).toStringAsFixed(1);
      pills.add(_MeasurementPill(icon: Icons.scale_outlined, text: '$lbs lbs'));
    }
    if (catch_.lengthCm != null) {
      final inches = (catch_.lengthCm! / 2.54).toStringAsFixed(1);
      pills.add(_MeasurementPill(icon: Icons.straighten, text: '$inches in'));
    }
    if (catch_.catchAndRelease) {
      pills.add(const _MeasurementPill(
        icon: Icons.water_drop_outlined,
        text: 'Catch & release',
      ));
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: pills,
    );
  }
}

class _MeasurementPill extends StatelessWidget {
  const _MeasurementPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
        ],
      ),
    );
  }
}

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({required this.catch_});

  final Catch catch_;

  String _locationText() {
    if (catch_.secretSpot && !catch_.hasLocation) return 'Location hidden';
    if (catch_.secretSpot) return 'Location hidden';
    if (!catch_.hasLocation) return 'Not captured';
    return '${catch_.latitude!.toStringAsFixed(4)}, '
        '${catch_.longitude!.toStringAsFixed(4)}';
  }

  IconData _locationIcon() {
    if (catch_.secretSpot) return Icons.lock_outline;
    if (!catch_.hasLocation) return Icons.location_off_outlined;
    return Icons.location_on_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _IconLine(
              icon: _locationIcon(),
              label: 'Location',
              value: _locationText(),
            ),
            const Divider(height: AppSpacing.lg),
            _IconLine(
              icon: Icons.access_time,
              label: 'Caught',
              value: DateFormat.yMMMd()
                  .add_jm()
                  .format(catch_.caughtAt.toLocal()),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: scheme.primary, size: 20),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LabeledLine extends StatelessWidget {
  const _LabeledLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xxs),
            Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _NotesBlock extends StatelessWidget {
  const _NotesBlock({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(notes, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _NotAvailable extends StatelessWidget {
  const _NotAvailable();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.visibility_off_outlined, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text(
                "This catch isn't available.",
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'It may be private, deleted, or only visible to friends.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
