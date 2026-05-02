import 'package:cached_network_image/cached_network_image.dart';
import 'package:fishing_with_friends/features/profile/data/avatar_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Read-only circular avatar. Mirrors the rendering side of `AvatarPicker`
/// without the tap-to-edit affordance — used on profile views, comment
/// rows, and anywhere we surface someone else's identity.
class AvatarView extends ConsumerWidget {
  const AvatarView({
    required this.avatarPath,
    this.radius = 48,
    super.key,
  });

  final String? avatarPath;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = (avatarPath == null || avatarPath!.isEmpty)
        ? null
        : ref.watch(avatarStorageProvider).publicUrlFor(avatarPath!);

    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: url == null
            ? _Placeholder(radius: radius)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => _Placeholder(radius: radius),
                errorWidget: (_, __, ___) => _Placeholder(radius: radius),
              ),
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
