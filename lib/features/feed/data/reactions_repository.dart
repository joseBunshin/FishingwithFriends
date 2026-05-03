import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/features/feed/data/reaction_dto.dart';
import 'package:fishing_with_friends/features/feed/domain/reaction.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class ReactionsDataSource {
  Future<void> upsert({
    required String catchId,
    required String userId,
    required ReactionKind kind,
  });

  Future<void> delete({required String catchId, required String userId});
}

class SupabaseReactionsDataSource implements ReactionsDataSource {
  SupabaseReactionsDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<void> upsert({
    required String catchId,
    required String userId,
    required ReactionKind kind,
  }) async {
    // Composite PK is (catch_id, user_id) — upsert flips kind atomically.
    await _client.from('feed_reactions').upsert(
          ReactionDto.toInsertRow(
            catchId: catchId,
            userId: userId,
            kind: kind,
          ),
          onConflict: 'catch_id,user_id',
        );
  }

  @override
  Future<void> delete({
    required String catchId,
    required String userId,
  }) async {
    await _client
        .from('feed_reactions')
        .delete()
        .eq('catch_id', catchId)
        .eq('user_id', userId);
  }
}

class ReactionsRepository {
  ReactionsRepository({required this.dataSource});

  final ReactionsDataSource dataSource;

  /// Toggle: if the user has [kind] on [catchId], delete; otherwise upsert.
  /// Returns the new kind (null = no reaction).
  Future<ReactionKind?> toggle({
    required String catchId,
    required String userId,
    required ReactionKind kind,
    required ReactionKind? currentKind,
  }) async {
    if (userId.isEmpty) {
      throw const AuthFailure('Sign in to react.');
    }
    try {
      if (currentKind == kind) {
        await dataSource.delete(catchId: catchId, userId: userId);
        return null;
      }
      await dataSource.upsert(
        catchId: catchId,
        userId: userId,
        kind: kind,
      );
      return kind;
    } on PostgrestException catch (e) {
      throw NetworkFailure('Reaction failed: ${e.message}', cause: e);
    }
  }
}
