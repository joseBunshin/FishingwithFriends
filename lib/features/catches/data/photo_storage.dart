import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Photo upload + signed-URL retrieval against the private `catches` bucket.
/// Abstracted so the repository orchestrator can be unit-tested without a
/// live Supabase storage backend.
abstract class PhotoStorage {
  /// Upload a single photo and return its storage path.
  /// Path convention: `<anglerId>/<catchId>/<index>.<ext>`.
  Future<String> upload({
    required XFile file,
    required String anglerId,
    required String catchId,
    required int index,
  });

  /// Mint a short-lived signed URL for an already-uploaded path.
  Future<String> signedUrl(String path, {Duration ttl});
}

class SupabasePhotoStorage implements PhotoStorage {
  SupabasePhotoStorage(this._client, {this.bucket = 'catches'});

  final SupabaseClient _client;
  final String bucket;

  @override
  Future<String> upload({
    required XFile file,
    required String anglerId,
    required String catchId,
    required int index,
  }) async {
    final ext = _extensionFor(file.name);
    final path = '$anglerId/$catchId/$index$ext';
    final bytes = await file.readAsBytes();
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: file.mimeType,
          ),
        );
    return path;
  }

  @override
  Future<String> signedUrl(String path, {Duration ttl = const Duration(hours: 1)}) {
    return _client.storage.from(bucket).createSignedUrl(path, ttl.inSeconds);
  }

  String _extensionFor(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0 || dot == filename.length - 1) return '.jpg';
    return filename.substring(dot).toLowerCase();
  }
}
