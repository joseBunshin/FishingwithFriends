import 'package:cached_network_image/cached_network_image.dart';
import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/profile/data/avatar_storage.dart';
import 'package:fishing_with_friends/features/profile/data/my_profile_repository_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Tap-to-pick avatar with edit overlay. Uploads to the public avatars
/// bucket and writes the resulting path to `profiles.avatar_path`.
///
/// Renders the current avatar (signed URL via the public bucket) when
/// [currentAvatarPath] is non-null, otherwise a navy-tinted placeholder.
class AvatarPicker extends ConsumerStatefulWidget {
  const AvatarPicker({
    required this.currentAvatarPath,
    this.radius = 48,
    super.key,
  });

  final String? currentAvatarPath;
  final double radius;

  @override
  ConsumerState<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends ConsumerState<AvatarPicker> {
  bool _busy = false;

  Future<void> _pickAndUpload() async {
    if (_busy) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final picker = ImagePicker();
    XFile? picked;
    try {
      ImageSource source;
      if (kIsWeb) {
        source = ImageSource.gallery;
      } else {
        final choice = await showModalBottomSheet<ImageSource>(
          context: context,
          builder: (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take a photo'),
                  onTap: () =>
                      Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Pick from library'),
                  onTap: () =>
                      Navigator.of(context).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
        if (choice == null) return;
        source = choice;
      }

      picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't open picker: $e")),
      );
      return;
    }
    if (picked == null) return;

    setState(() => _busy = true);
    try {
      final result = await ref.read(avatarStorageProvider).upload(
            file: picked,
            userId: user.id,
          );
      await ref.read(myProfileRepositoryProvider).updateMyProfile(
            userId: user.id,
            avatarPath: result.path,
          );
      // Best-effort cleanup of the previous file.
      final old = widget.currentAvatarPath;
      if (old != null && old.isNotEmpty && old != result.path) {
        await ref.read(avatarStorageProvider).deleteIfExists(old);
      }
      ref.invalidate(myProfileProvider);
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.currentAvatarPath == null
        ? null
        : ref.watch(avatarStorageProvider).publicUrlFor(
              widget.currentAvatarPath!,
            );

    return GestureDetector(
      onTap: _pickAndUpload,
      child: Stack(
        children: [
          ClipOval(
            child: SizedBox(
              width: widget.radius * 2,
              height: widget.radius * 2,
              child: url == null
                  ? _Placeholder(radius: widget.radius)
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          _Placeholder(radius: widget.radius),
                      errorWidget: (_, __, ___) =>
                          _Placeholder(radius: widget.radius),
                    ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: const BoxDecoration(
                color: AppColors.orange,
                shape: BoxShape.circle,
              ),
              child: _busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(
                      Icons.edit,
                      size: 14,
                      color: AppColors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.radius});
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.primary.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        size: radius,
        color: scheme.primary,
      ),
    );
  }
}
