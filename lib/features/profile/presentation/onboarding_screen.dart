import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/router/app_router.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository_provider.dart';
import 'package:fishing_with_friends/features/friends/domain/profile.dart';
import 'package:fishing_with_friends/features/profile/data/my_profile_repository_provider.dart';
import 'package:fishing_with_friends/features/profile/presentation/widgets/avatar_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 3-step onboarding shown to new users. Step 1 captures display name +
/// handle (required); steps 2 (home water) and 3 (find friends) are
/// skip-able. Marking onboarding complete sets profiles.onboarding_completed_at.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageCtl = PageController();
  int _index = 0;

  final _displayNameCtl = TextEditingController();
  final _usernameCtl = TextEditingController();
  final _homeWaterCtl = TextEditingController();
  String? _step1Error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Seed the username field from the auto-generated value (0008
    // trigger derives it from email).
    Future.microtask(() async {
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      final p = await ref.read(myProfileProvider.future);
      if (!mounted) return;
      _usernameCtl.text = p?.username ?? '';
      _displayNameCtl.text = p?.displayName ?? '';
      _homeWaterCtl.text = p?.homeWater ?? '';
      setState(() {});
    });
  }

  @override
  void dispose() {
    _pageCtl.dispose();
    _displayNameCtl.dispose();
    _usernameCtl.dispose();
    _homeWaterCtl.dispose();
    super.dispose();
  }

  Future<void> _saveStep1() async {
    final name = _displayNameCtl.text.trim();
    final handle = _usernameCtl.text.trim().toLowerCase();
    if (name.length < 2) {
      setState(() => _step1Error = 'Add a display name (2+ characters).');
      return;
    }
    if (handle.length < 3 || handle.length > 30) {
      setState(() => _step1Error = 'Handle must be 3–30 characters.');
      return;
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(handle)) {
      setState(() => _step1Error =
          'Handle can only contain lowercase letters, numbers, and _.');
      return;
    }
    setState(() {
      _step1Error = null;
      _saving = true;
    });
    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _saving = false);
      return;
    }
    try {
      await ref.read(myProfileRepositoryProvider).updateMyProfile(
            userId: user.id,
            displayName: name,
            username: handle,
          );
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      setState(() => _saving = false);
      _next();
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _step1Error = e.message;
        _saving = false;
      });
    }
  }

  Future<void> _saveStep2AndAdvance({required bool skip}) async {
    if (skip) {
      _next();
      return;
    }
    final water = _homeWaterCtl.text.trim();
    if (water.isEmpty) {
      _next();
      return;
    }
    setState(() => _saving = true);
    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _saving = false);
      return;
    }
    try {
      await ref.read(myProfileRepositoryProvider).updateMyProfile(
            userId: user.id,
            homeWater: water,
          );
      ref.invalidate(myProfileProvider);
    } on AppException {
      // Soft fail — let them continue. They can edit later from the Me tab.
    }
    if (!mounted) return;
    setState(() => _saving = false);
    _next();
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _saving = false);
      return;
    }
    try {
      await ref
          .read(myProfileRepositoryProvider)
          .markOnboardingComplete(user.id);
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      context.go(AppRoutes.home);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  void _next() {
    if (_index >= 2) {
      _finish();
      return;
    }
    _pageCtl.animateToPage(
      _index + 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: _StepDots(count: 3, index: _index),
            ),
            Expanded(
              child: PageView(
                controller: _pageCtl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  _Step1Identity(
                    displayNameCtl: _displayNameCtl,
                    usernameCtl: _usernameCtl,
                    error: _step1Error,
                    saving: _saving,
                    onContinue: _saveStep1,
                  ),
                  _Step2HomeWater(
                    homeWaterCtl: _homeWaterCtl,
                    saving: _saving,
                    onContinue: () => _saveStep2AndAdvance(skip: false),
                    onSkip: () => _saveStep2AndAdvance(skip: true),
                  ),
                  _Step3FindFriends(
                    saving: _saving,
                    onFinish: _finish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.count, required this.index});
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
              color: i == index ? AppColors.navy : AppColors.mist,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

class _Step1Identity extends ConsumerWidget {
  const _Step1Identity({
    required this.displayNameCtl,
    required this.usernameCtl,
    required this.error,
    required this.saving,
    required this.onContinue,
  });

  final TextEditingController displayNameCtl;
  final TextEditingController usernameCtl;
  final String? error;
  final bool saving;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Pick a display name, a handle, and an avatar to get started.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: AvatarPicker(
              currentAvatarPath: profile?.avatarPath,
              radius: 56,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            controller: displayNameCtl,
            decoration: const InputDecoration(
              labelText: 'Display name',
              hintText: 'Jose Diaz',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: usernameCtl,
            decoration: const InputDecoration(
              labelText: 'Handle',
              hintText: 'silentfisher409',
              prefixText: '@',
            ),
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const Spacer(),
          FilledButton(
            onPressed: saving ? null : onContinue,
            style: FilledButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
            child: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _Step2HomeWater extends StatelessWidget {
  const _Step2HomeWater({
    required this.homeWaterCtl,
    required this.saving,
    required this.onContinue,
    required this.onSkip,
  });

  final TextEditingController homeWaterCtl;
  final bool saving;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Where do you fish?',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your home body of water — we use this as the default '
            'location for quick logs.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            controller: homeWaterCtl,
            decoration: const InputDecoration(
              labelText: 'Home water',
              hintText: 'Lake Mendota',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const Spacer(),
          FilledButton(
            onPressed: saving ? null : onContinue,
            style: FilledButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
            child: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Continue'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: saving ? null : onSkip,
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }
}

class _Step3FindFriends extends ConsumerStatefulWidget {
  const _Step3FindFriends({
    required this.saving,
    required this.onFinish,
  });

  final bool saving;
  final VoidCallback onFinish;

  @override
  ConsumerState<_Step3FindFriends> createState() => _Step3FindFriendsState();
}

class _Step3FindFriendsState extends ConsumerState<_Step3FindFriends> {
  final _searchCtl = TextEditingController();
  String _query = '';
  final _sentTo = <String>{};

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _send(Profile p) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _sentTo.add(p.id));
    try {
      await ref.read(friendsRepositoryProvider).sendRequest(
            currentUserId: user.id,
            addresseeId: p.id,
          );
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      setState(() => _sentTo.remove(p.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.read(currentUserProvider);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Find your crew.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Search by handle and send a friend request. Your feed and '
            'tournaments come alive once you have a few.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            controller: _searchCtl,
            decoration: const InputDecoration(
              labelText: 'Search handles',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: _query.length < 2 || user == null
                ? const Center(
                    child: Text('Type a handle to search.'),
                  )
                : _SearchResults(
                    query: _query,
                    currentUserId: user.id,
                    sentTo: _sentTo,
                    onSend: _send,
                  ),
          ),
          FilledButton(
            onPressed: widget.saving ? null : widget.onFinish,
            style: FilledButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
            child: widget.saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.query,
    required this.currentUserId,
    required this.sentTo,
    required this.onSend,
  });

  final String query;
  final String currentUserId;
  final Set<String> sentTo;
  final ValueChanged<Profile> onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncResults =
        ref.watch(searchProfilesProvider(query));
    return asyncResults.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) =>
          Center(child: Text('$e')),
      data: (profiles) {
        if (profiles.isEmpty) {
          return const Center(child: Text('No matches.'));
        }
        return ListView.separated(
          itemCount: profiles.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = profiles[i];
            final sent = sentTo.contains(p.id);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.navy.withValues(alpha: 0.1),
                child: Text(
                  p.username.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: AppColors.navy),
                ),
              ),
              title: Text(p.displayName ?? p.username),
              subtitle: Text(p.handle),
              trailing: sent
                  ? const Chip(label: Text('Sent'))
                  : OutlinedButton(
                      onPressed: () => onSend(p),
                      child: const Text('Add'),
                    ),
            );
          },
        );
      },
    );
  }
}
