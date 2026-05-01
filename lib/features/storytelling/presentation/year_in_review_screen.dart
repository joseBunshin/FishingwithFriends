import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/storytelling/application/year_in_review_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class YearInReviewScreen extends ConsumerStatefulWidget {
  const YearInReviewScreen({super.key});

  @override
  ConsumerState<YearInReviewScreen> createState() =>
      _YearInReviewScreenState();
}

class _YearInReviewScreenState extends ConsumerState<YearInReviewScreen> {
  final PageController _pageCtl = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncSummary = ref.watch(yearInReviewProvider);
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      body: SafeArea(
        child: asyncSummary.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.orange),
          ),
          error: (_, __) => _ErrorView(),
          data: (s) {
            final pages = _pagesFor(s);
            return Stack(
              children: [
                PageView.builder(
                  controller: _pageCtl,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => pages[i],
                ),
                Positioned(
                  top: AppSpacing.lg,
                  left: 0,
                  right: 0,
                  child: _Dots(count: pages.length, index: _index),
                ),
                Positioned(
                  top: AppSpacing.xs,
                  right: AppSpacing.xs,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: AppColors.white),
                    onPressed: () => context.pop(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _pagesFor(YearInReviewSummary s) {
    if (s.isEmpty) {
      return const [_EmptyCard()];
    }
    return [
      _IntroCard(s: s),
      _BiggestCard(s: s),
      _SpeciesCard(s: s),
      _DaysCard(s: s),
      _TripCard(s: s),
      _FriendCard(s: s),
    ];
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == index
                  ? AppColors.white
                  : AppColors.white.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

class _PageScaffold extends StatefulWidget {
  const _PageScaffold({
    required this.kicker,
    required this.headline,
    required this.body,
  });

  final String kicker;
  final String headline;
  final Widget body;

  @override
  State<_PageScaffold> createState() => _PageScaffoldState();
}

class _PageScaffoldState extends State<_PageScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xxxl,
        AppSpacing.xl,
        AppSpacing.xxxl,
      ),
      child: FadeTransition(
        opacity: _ctl,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: _ctl, curve: Curves.easeOut),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Text(
                widget.kicker,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.orange,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.headline,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              widget.body,
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.s});
  final YearInReviewSummary s;

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      kicker: 'YEAR IN REVIEW',
      headline: 'Your last 365 days',
      body: Text(
        '${DateFormat.yMMMd().format(s.windowStart.toLocal())} → '
        '${DateFormat.yMMMd().format(s.windowEnd.toLocal())}',
        style: const TextStyle(color: AppColors.mist, fontSize: 18),
      ),
    );
  }
}

class _BiggestCard extends StatelessWidget {
  const _BiggestCard({required this.s});
  final YearInReviewSummary s;

  @override
  Widget build(BuildContext context) {
    final c = s.biggest;
    if (c == null || c.weightKg == null) {
      return const _PageScaffold(
        kicker: 'BIGGEST',
        headline: 'No measured catches yet',
        body: SizedBox.shrink(),
      );
    }
    final lbs = (c.weightKg! * 2.20462).toStringAsFixed(1);
    return _PageScaffold(
      kicker: 'BIGGEST',
      headline: '$lbs lbs',
      body: Text(
        c.speciesLabel ?? 'Catch',
        style: const TextStyle(color: AppColors.mist, fontSize: 24),
      ),
    );
  }
}

class _SpeciesCard extends StatelessWidget {
  const _SpeciesCard({required this.s});
  final YearInReviewSummary s;

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      kicker: 'SPECIES',
      headline: s.distinctSpecies == 0
          ? 'No species logged'
          : '${s.distinctSpecies} different ${s.distinctSpecies == 1 ? "species" : "species"}',
      body: s.mostCaughtSpeciesLabel == null
          ? const SizedBox.shrink()
          : Text(
              'Most caught: ${s.mostCaughtSpeciesLabel}',
              style: const TextStyle(color: AppColors.mist, fontSize: 22),
            ),
    );
  }
}

class _DaysCard extends StatelessWidget {
  const _DaysCard({required this.s});
  final YearInReviewSummary s;

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      kicker: 'DAYS ON THE WATER',
      headline: '${s.daysFished} days fished',
      body: const SizedBox.shrink(),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.s});
  final YearInReviewSummary s;

  @override
  Widget build(BuildContext context) {
    final t = s.biggestTrip;
    if (t == null || s.biggestTripWeightKg == 0) {
      return const _PageScaffold(
        kicker: 'BIGGEST TRIP',
        headline: 'Log a trip to see this',
        body: SizedBox.shrink(),
      );
    }
    final lbs = (s.biggestTripWeightKg * 2.20462).toStringAsFixed(1);
    return _PageScaffold(
      kicker: 'BIGGEST TRIP',
      headline: t.title,
      body: Text(
        '$lbs lbs total',
        style: const TextStyle(color: AppColors.mist, fontSize: 24),
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({required this.s});
  final YearInReviewSummary s;

  @override
  Widget build(BuildContext context) {
    final lb = s.friendLeaderboard;
    if (lb.isEmpty) {
      return const _PageScaffold(
        kicker: 'FRIEND LEADERBOARD',
        headline: 'Add friends to see how you stack up',
        body: SizedBox.shrink(),
      );
    }
    return _PageScaffold(
      kicker: 'FRIEND LEADERBOARD',
      headline: 'Top of your circle',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lb.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${i + 1}. @${lb[i].friendId.substring(0, lb[i].friendId.length.clamp(0, 6))} — ${lb[i].count} catches',
                style: const TextStyle(color: AppColors.mist, fontSize: 18),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return const _PageScaffold(
      kicker: 'YEAR IN REVIEW',
      headline: 'Log a catch this year to unlock your review.',
      body: SizedBox.shrink(),
    );
  }
}

class _ErrorView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          "Couldn't compose your year in review.",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.white,
              ),
        ),
      ),
    );
  }
}
