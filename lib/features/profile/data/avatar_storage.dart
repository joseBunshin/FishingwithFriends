import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads avatar images to the public `avatars` bucket and returns a
/// public URL. Path convention: `<user_id>/<timestamp>.<ext>`.
class AvatarStorage {
  AvatarStorage(this._client, {this.bucket = 'avatars'});

  final SupabaseClient _client;
  final String bucket;

  /// Upload [file] for [userId] and return the **public URL** suitable
  /// for direct use in cached_network_image. The path stored on the
  /// profile row is the storage path, not the URL — call
  /// [publicUrlFor] to render later.
  Future<({String path, String url})> upload({
    required XFile file,
    required String userId,
  }) async {
    if (userId.isEmpty) {
      throw const AuthFailure('You must be signed in.');
    }
    final ext = _extensionFor(file.name);
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}$ext';
    final bytes = await file.readAsBytes();
    try {
      await _client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: file.mimeType,
            ),
          );
    } on StorageException catch (e) {
      throw NetworkFailure('Avatar upload failed: ${e.message}', cause: e);
    }
    final url = _client.storage.from(bucket).getPublicUrl(path);
    return (path: path, url: url);
  }

  /// Resolve the public URL for a stored path. No network call.
  ///
  /// Pass-through for absolute URLs: when [path] already looks like an
  /// http(s) URL, return it unchanged. Lets dev seed populate avatar_path
  /// with external stock-photo URLs (pravatar, unsplash) without touching
  /// the avatars bucket. Real bucket paths still resolve via Supabase.
  String publicUrlFor(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  /// Best-effort cleanup of a previous avatar after a successful new upload.
  Future<void> deleteIfExists(String path) async {
    if (path.isEmpty) return;
    try {
      await _client.storage.from(bucket).remove([path]);
    } on StorageException {
      // Non-fatal — if the old object is already gone, fine.
    }
  }

  String _extensionFor(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0 || dot == filename.length - 1) return '.jpg';
    return filename.substring(dot).toLowerCase();
  }
}

final avatarStorageProvider = Provider<AvatarStorage>((ref) {
  return AvatarStorage(ref.watch(supabaseClientProvider));
});
