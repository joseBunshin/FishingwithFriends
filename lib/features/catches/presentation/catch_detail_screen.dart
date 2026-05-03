import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/core/units/measurement_format.dart';
import 'package:fishing_with_friends/core/widgets/section_label.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/catches/presentation/widgets/catch_photo_carousel.dart';
import 'package:fishing_with_friends/features/catches/presentation/widgets/delete_catch_sheet.dart';
import 'package:fishing_with_friends/features/catches/presentation/widgets/location_map_card.dart';
import 'package:fishing_with_friends/features/feed/presentation/widgets/comment_list.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository_provider.dart';
import 'package:fishing_with_friends/features/profile/presentation/widgets/avatar_view.dart';
import 'package:fishing_with_friends/features/settings/data/app_preferences.dart';
import 'package:fishing_with_friends/features/storytelling/application/share_card_export.dart';
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

class _Body extends ConsumerWidget {
  const _Body({required this.catch_});

  final Catch catch_;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final isMine = me != null && me.id == catch_.anglerId;
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
            _ShareAction(catch_: catch_),
            IconButton(
              tooltip: 'Submit to tournament',
              icon: const Icon(Icons.emoji_events_outlined),
              onPressed: () => SubmitEntrySheet.pickTournament(
                context,
                source: catch_,
              ),
            ),
            if (isMine)
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: const Icon(Icons.more_vert),
                onSelected: (key) async {
                  if (key == 'delete') {
                    final deleted = await DeleteCatchSheet.show(
                      context,
                      catch_: catch_,
                    );
                    if (deleted && context.mounted) context.pop();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete catch'),
                    ),
                  ),
                ],
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
                _AnglerLine(anglerId: catch_.anglerId, isMine: isMine),
                const SizedBox(height: AppSpacing.lg),
                _Headline(catch_: catch_),
                const SizedBox(height: AppSpacing.sm),
                CatchComparisonLine(catchId: catch_.id),
                const SizedBox(height: AppSpacing.lg),
                _MeasurementRow(catch_: catch_),
                const SizedBox(height: AppSpacing.lg),
                _LocationBlock(catch_: catch_),
                const SizedBox(height: AppSpacing.md),
                _CaughtAtRow(caughtAt: catch_.caughtAt),
                if (_hasAnyDetail(catch_)) ...[
                  const SizedBox(height: AppSpacing.xl),
                  const SectionLabel('Details'),
                  const SizedBox(height: AppSpacing.md),
                  _DetailsCard(catch_: catch_),
                ],
                const SizedBox(height: AppSpacing.xl),
                const SectionLabel('Comments'),
                const SizedBox(height: AppSpacing.sm),
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

class _ShareAction extends ConsumerStatefulWidget {
  const _ShareAction({required this.catch_});

  final Catch catch_;

  @override
  ConsumerState<_ShareAction> createState() => _ShareActionState();
}

class _ShareActionState extends ConsumerState<_ShareAction> {
  bool _busy = false;

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(shareCardExporterProvider).exportAndShare(
            context: context,
            catch_: widget.catch_,
          );
    } on Object catch (e, st) {
      debugPrint('Share card failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't build share card: $e")),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Share',
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.white,
              ),
            )
          : const Icon(Icons.ios_share),
      onPressed: _busy ? null : _share,
    );
  }
}

class _AnglerLine extends ConsumerWidget {
  const _AnglerLine({required this.anglerId, required this.isMine});

  final String anglerId;
  final bool isMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(friendsBundleProvider).valueOrNull;
    final profile = bundle?.profilesById[anglerId];
    final handle = profile?.handle ?? (isMine ? '@you' : '@angler');
    final displayName = profile?.displayName?.isNotEmpty ?? false
        ? profile!.displayName!
        : null;

    return InkWell(
      onTap: () => context.push('/profile/$anglerId'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Row(
          children: [
            AvatarView(avatarPath: profile?.avatarPath, radius: 16),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName ?? handle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (displayName != null)
                    Text(
                      handle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.catch_});

  final Catch catch_;

  @override
  Widget build(BuildContext context) {
    return Text(
      catch_.speciesLabel ?? 'Unknown species',
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            height: 1.05,
          ),
    );
  }
}

class _MeasurementRow extends ConsumerWidget {
  const _MeasurementRow({required this.catch_});

  final Catch catch_;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(displayUnitsProvider);
    final pills = <Widget>[];
    final weight = formatWeight(catch_.weightKg, units);
    if (weight != null) {
      pills.add(_MeasurementPill(
        icon: Icons.scale_outlined,
        text: weight,
        emphasized: true,
      ));
    }
    final length = formatLength(catch_.lengthCm, units);
    if (length != null) {
      pills.add(_MeasurementPill(icon: Icons.straighten, text: length));
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
  const _MeasurementPill({
    required this.icon,
    required this.text,
    this.emphasized = false,
  });

  final IconData icon;
  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Emphasized = the headline metric (weight). Renders as a filled
    // navy chip to match the global navy-CTA language.
    final bg = emphasized ? AppColors.navy : scheme.surfaceContainerHighest;
    final fg = emphasized ? AppColors.white : scheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: emphasized
            ? null
            : Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: AppSpacing.xs),
          Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: fg,
                  letterSpacing: 0.2,
                ),
          ),
        ],
      ),
    );
  }
}

class _LocationBlock extends StatelessWidget {
  const _LocationBlock({required this.catch_});

  final Catch catch_;

  @override
  Widget build(BuildContext context) {
    if (catch_.hasLocation && !catch_.secretSpot) {
      return LocationMapCard(
        latitude: catch_.latitude!,
        longitude: catch_.longitude!,
        title: catch_.speciesLabel ?? 'Catch location',
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final secret = catch_.secretSpot;
    final icon = secret ? Icons.lock_outline : Icons.location_off_outlined;
    final label = secret ? 'Secret spot' : 'No location captured';
    final caption = secret
        ? 'GPS hidden — only the angler knows.'
        : 'This catch was logged without GPS.';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  caption,
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

class _CaughtAtRow extends StatelessWidget {
  const _CaughtAtRow({required this.caughtAt});

  final DateTime caughtAt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.access_time, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Text(
          DateFormat.yMMMd().add_jm().format(caughtAt.toLocal()),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

/// True when at least one of rig / notes / conditions has content. Used
/// to decide whether to render the consolidated _DetailsCard at all.
bool _hasAnyDetail(Catch c) {
  final hasRig = c.rig != null && c.rig!.isNotEmpty;
  final hasNotes = c.notes != null && c.notes!.isNotEmpty;
  final hasConditions = c.conditions.isNotEmpty;
  return hasRig || hasNotes || hasConditions;
}

/// Single card that consolidates the catch's optional metadata —
/// rig, notes, conditions — under one tile with small-caps sub-sections
/// separated by hairlines. Replaces the three separate cards that read
/// disjointed before.
class _DetailsCard extends ConsumerWidget {
  const _DetailsCard({required this.catch_});

  final Catch catch_;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final units = ref.watch(displayUnitsProvider);
    final children = <Widget>[];

    final rig = catch_.rig;
    if (rig != null && rig.isNotEmpty) {
      children.add(_DetailRow(label: 'Rig', value: rig));
    }
    final notes = catch_.notes;
    if (notes != null && notes.isNotEmpty) {
      if (children.isNotEmpty) children.add(const _DetailDivider());
      children.add(_DetailRow(label: 'Notes', value: notes));
    }
    if (catch_.conditions.isNotEmpty) {
      final pills = _conditionPills(catch_.conditions, units);
      if (pills.isNotEmpty) {
        if (children.isNotEmpty) children.add(const _DetailDivider());
        children.add(_ConditionsRow(pills: pills));
      }
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.slate,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

class _ConditionsRow extends StatelessWidget {
  const _ConditionsRow({required this.pills});

  final List<_ConditionPill> pills;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONDITIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.slate,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final p in pills) _ConditionChip(pill: p),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailDivider extends StatelessWidget {
  const _DetailDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

@immutable
class _ConditionPill {
  const _ConditionPill({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _ConditionChip extends StatelessWidget {
  const _ConditionChip({required this.pill});

  final _ConditionPill pill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(pill.icon, size: 14, color: AppColors.navy),
          const SizedBox(width: AppSpacing.xs),
          Text(
            pill.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

List<_ConditionPill> _conditionPills(
  Map<String, dynamic> conditions,
  DisplayUnits units,
) {
  final out = <_ConditionPill>[];
  final tempC = conditions['temp_c'];
  if (tempC is num) {
    out.add(_ConditionPill(
      icon: Icons.thermostat_outlined,
      label: formatTemperature(tempC, units),
    ));
  }
  final wind = conditions['wind_kph'];
  if (wind is num) {
    out.add(_ConditionPill(
      icon: Icons.air,
      label: '${wind.toStringAsFixed(0)} kph',
    ));
  }
  final waterTemp = conditions['water_temp_c'];
  if (waterTemp is num) {
    out.add(_ConditionPill(
      icon: Icons.waves,
      label: 'water ${formatTemperature(waterTemp, units)}',
    ));
  }
  final tide = conditions['tide_state'];
  if (tide is String) {
    out.add(_ConditionPill(
      icon: Icons.water_drop_outlined,
      label: '$tide tide',
    ));
  }
  final tideObj = conditions['tide'];
  if (tideObj is Map<String, dynamic>) {
    final phase = tideObj['phase'];
    if (phase is String) {
      out.add(_ConditionPill(
        icon: Icons.water_drop_outlined,
        label: '$phase tide',
      ));
    }
  }
  final sky = conditions['weather'];
  if (sky is Map<String, dynamic>) {
    final s = sky['sky'];
    if (s is String) {
      out.add(_ConditionPill(
        icon: _skyIcon(s),
        label: s.replaceAll('_', ' '),
      ));
    }
    final t = sky['temp_c'];
    if (t is num) {
      out.add(_ConditionPill(
        icon: Icons.thermostat_outlined,
        label: formatTemperature(t, units),
      ));
    }
  }
  final moon = conditions['moon_phase'];
  if (moon is num) {
    out.add(_ConditionPill(
      icon: Icons.brightness_3,
      label: _moonLabel(moon.toDouble()),
    ));
  }
  final moonStr = conditions['moon'];
  if (moonStr is String) {
    out.add(_ConditionPill(
      icon: Icons.brightness_3,
      label: moonStr.replaceAll('_', ' '),
    ));
  }
  return out;
}

IconData _skyIcon(String sky) {
  return switch (sky) {
    'clear' => Icons.wb_sunny_outlined,
    'partly_cloudy' => Icons.wb_cloudy_outlined,
    'overcast' => Icons.cloud_outlined,
    'rain' => Icons.water_drop_outlined,
    _ => Icons.cloud_outlined,
  };
}

String _moonLabel(double phase) {
  if (phase < 0.05 || phase > 0.95) return 'New moon';
  if (phase < 0.20) return 'Waxing crescent';
  if (phase < 0.30) return 'First quarter';
  if (phase < 0.45) return 'Waxing gibbous';
  if (phase < 0.55) return 'Full moon';
  if (phase < 0.70) return 'Waning gibbous';
  if (phase < 0.80) return 'Last quarter';
  return 'Waning crescent';
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
