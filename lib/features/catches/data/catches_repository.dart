import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/features/catches/data/catch_dto.dart';
import 'package:fishing_with_friends/features/catches/data/catches_data_source.dart';
import 'package:fishing_with_friends/features/catches/data/photo_storage.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/catches/domain/catch_input.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Orchestrates catch persistence + reads.
///
/// `create(...)` uploads photos *first*, then inserts the row. The catch's
/// id is generated client-side so the photo path can include it before the
/// row exists. If the insert fails after photos upload, the photos are
/// orphaned in storage — accepted in M1 and reaped by the M6 sync queue.
class CatchesRepository {
  CatchesRepository({
    required this.dataSource,
    required this.storage,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final CatchesDataSource dataSource;
  final PhotoStorage storage;
  final Uuid _uuid;

  Future<Catch> create(
    CatchInput input, {
    required String anglerId,
  }) async {
    if (anglerId.isEmpty) {
      throw const AuthFailure('You must be signed in to log a catch.');
    }
    if (input.photos.isEmpty) {
      throw const ValidationFailure(
        'At least one photo is required to log a catch.',
      );
    }

    final catchId = _uuid.v4();
    final photoPaths = <String>[];

    try {
      for (var i = 0; i < input.photos.length; i++) {
        final path = await storage.upload(
          file: input.photos[i],
          anglerId: anglerId,
          catchId: catchId,
          index: i,
        );
        photoPaths.add(path);
      }
    } on StorageException catch (e) {
      throw NetworkFailure('Photo upload failed: ${e.message}', cause: e);
    }

    try {
      final row = CatchDto.toInsertRow(
        input,
        catchId: catchId,
        anglerId: anglerId,
        photoPaths: photoPaths,
      );
      final inserted = await dataSource.insertCatch(row);
      return CatchDto.fromRow(inserted);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to save catch: ${e.message}', cause: e);
    }
  }

  Future<List<Catch>> getMine(String anglerId) async {
    if (anglerId.isEmpty) {
      throw const AuthFailure('You must be signed in.');
    }
    try {
      final rows = await dataSource.selectMine(anglerId);
      return rows.map(CatchDto.fromRow).toList(growable: false);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to load catches: ${e.message}', cause: e);
    }
  }

  Future<List<Catch>> getFriendsCatches({
    required List<String> friendIds,
  }) async {
    try {
      final rows = await dataSource.selectFriendsView(friendIds: friendIds);
      return rows.map(CatchDto.fromRow).toList(growable: false);
    } on PostgrestException catch (e) {
      throw NetworkFailure(
        "Failed to load friends' catches: ${e.message}",
        cause: e,
      );
    }
  }

  Future<Catch?> getById(String id) async {
    try {
      final row = await dataSource.selectById(id);
      return row == null ? null : CatchDto.fromRow(row);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to load catch: ${e.message}', cause: e);
    }
  }
}
