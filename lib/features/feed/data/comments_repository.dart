import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/features/feed/data/comment_dto.dart';
import 'package:fishing_with_friends/features/feed/domain/comment.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class CommentsDataSource {
  Future<List<Map<String, dynamic>>> selectForCatch(String catchId);
  Future<Map<String, dynamic>> insertComment(Map<String, dynamic> row);
  Future<void> softDelete(String commentId);
}

class SupabaseCommentsDataSource implements CommentsDataSource {
  SupabaseCommentsDataSource(this._client);

  final SupabaseClient _client;

  static const _columns = '*';

  @override
  Future<List<Map<String, dynamic>>> selectForCatch(String catchId) async {
    final rows = await _client
        .from('comments')
        .select(_columns)
        .eq('catch_id', catchId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<Map<String, dynamic>> insertComment(
    Map<String, dynamic> row,
  ) async {
    return _client.from('comments').insert(row).select(_columns).single();
  }

  @override
  Future<void> softDelete(String commentId) async {
    await _client
        .from('comments')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', commentId);
  }
}

class CommentsRepository {
  CommentsRepository({required this.dataSource});

  final CommentsDataSource dataSource;

  static const int maxLength = 2000;

  Future<List<Comment>> getForCatch(String catchId) async {
    try {
      final rows = await dataSource.selectForCatch(catchId);
      return rows.map(CommentDto.fromRow).toList(growable: false);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to load comments: ${e.message}', cause: e);
    }
  }

  Future<Comment> post({
    required String catchId,
    required String authorId,
    required String body,
  }) async {
    if (authorId.isEmpty) {
      throw const AuthFailure('Sign in to comment.');
    }
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw const ValidationFailure('Write something first.');
    }
    if (trimmed.length > maxLength) {
      throw const ValidationFailure(
        'Comments must be 2000 characters or fewer.',
      );
    }
    try {
      final row = await dataSource.insertComment(
        CommentDto.toInsertRow(
          catchId: catchId,
          authorId: authorId,
          body: trimmed,
        ),
      );
      return CommentDto.fromRow(row);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Comment failed: ${e.message}', cause: e);
    }
  }

  Future<void> softDelete(String commentId) async {
    try {
      await dataSource.softDelete(commentId);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Could not delete: ${e.message}', cause: e);
    }
  }
}
