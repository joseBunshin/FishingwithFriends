import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/profile/data/my_profile_repository_provider.dart';
import 'package:fishing_with_friends/features/profile/presentation/widgets/avatar_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _displayNameCtl = TextEditingController();
  final _usernameCtl = TextEditingController();
  final _homeWaterCtl = TextEditingController();
  final _bioCtl = TextEditingController();
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _displayNameCtl.dispose();
    _usernameCtl.dispose();
    _homeWaterCtl.dispose();
    _bioCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final handle = _usernameCtl.text.trim().toLowerCase();
    if (handle.length < 3 || handle.length > 30) {
      setState(() => _error = 'Handle must be 3–30 characters.');
      return;
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(handle)) {
      setState(() =>
          _error = 'Handle can only contain lowercase letters, numbers, _.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref.read(myProfileRepositoryProvider).updateMyProfile(
            userId: user.id,
            displayName: _displayNameCtl.text.trim(),
            username: handle,
            homeWater: _homeWaterCtl.text.trim(),
            bio: _bioCtl.text.trim(),
          );
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved.')),
      );
      context.pop();
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncProfile = ref.watch(myProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: asyncProfile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text("Couldn't load profile: $e"),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('No profile.'));
          }
          if (!_initialized) {
            _displayNameCtl.text = profile.displayName ?? '';
            _usernameCtl.text = profile.username;
            _homeWaterCtl.text = profile.homeWater ?? '';
            _bioCtl.text = profile.bio ?? '';
            _initialized = true;
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Center(
                child: AvatarPicker(
                  currentAvatarPath: profile.avatarPath,
                  radius: 56,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _displayNameCtl,
                decoration: const InputDecoration(labelText: 'Display name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _usernameCtl,
                decoration: const InputDecoration(
                  labelText: 'Handle',
                  prefixText: '@',
                ),
                autocorrect: false,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _homeWaterCtl,
                decoration: const InputDecoration(labelText: 'Home water'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _bioCtl,
                decoration: const InputDecoration(labelText: 'Bio'),
                maxLines: 3,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.md),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
