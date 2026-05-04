import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/features/notifications/domain/app_notification.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsRepository {
  NotificationsRepository(this._client);

  final SupabaseClient _client;

  Future<List<AppNotification>> myNotifications(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final rows = await _client
          .from('notifications')
          .select('id, recipient_id, kind, payload, read_at, created_at')
          .eq('recipient_id', userId)
          .order('created_at', ascending: false)
          .limit(100);
      return List<Map<String, dynamic>>.from(rows)
          .map(_fromRow)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw NetworkFailure(
        'Failed to load notifications: ${e.message}',
        cause: e,
      );
    }
  }

  Future<void> markRead(String id) async {
    try {
      // .select('id') chained so PostgREST returns the affected row.
      // RLS denial returns an empty list with no exception — treating
      // empty as success silently strands the unread bell on Home.
      // Scoped to the id column so the full payload doesn't cross
      // the wire on every mark-read.
      final rows = await _client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id)
          .select('id');
      if (rows.isEmpty) {
        debugPrint(
          'notifications-mark-read: zero rows affected for id=$id; '
          'RLS denial or stale session',
        );
        throw const NetworkFailure(
          "Couldn't mark that notification read. Try again.",
        );
      }
    } on PostgrestException catch (e) {
      throw NetworkFailure(
        'Failed to mark notification read: ${e.message}',
        cause: e,
      );
    }
  }

  Future<void> markAllRead(String userId) async {
    if (userId.isEmpty) return;
    try {
      final rows = await _client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('recipient_id', userId)
          .filter('read_at', 'is', null)
          .select('id');
      // markAllRead with no unread rows is not a failure — return cleanly.
      // Logged for visibility into "no-op vs RLS denial" for future debugging.
      if (rows.isEmpty) {
        debugPrint(
          'notifications-mark-all-read: zero rows affected for user=$userId; '
          'no unread or RLS denial (treating as no-op)',
        );
      }
    } on PostgrestException catch (e) {
      throw NetworkFailure(
        'Failed to mark all read: ${e.message}',
        cause: e,
      );
    }
  }

  /// Hard-delete a single notification by id. RLS policy
  /// `notifications_delete_own` (migration 0027) gates this to the row's
  /// recipient. `.select('id')` chained so a silently-denied delete
  /// (RLS returns zero affected rows with no exception) surfaces as a
  /// throw, not as a fake success that lets the row reappear on refresh.
  Future<void> delete(String id) async {
    try {
      final rows = await _client
          .from('notifications')
          .delete()
          .eq('id', id)
          .select('id');
      if (rows.isEmpty) {
        debugPrint(
          'notifications-delete: zero rows affected for id=$id; '
          'RLS denial or stale session',
        );
        throw const NetworkFailure(
          "Couldn't delete that notification. Try again.",
        );
      }
    } on PostgrestException catch (e) {
      throw NetworkFailure(
        'Failed to delete notification: ${e.message}',
        cause: e,
      );
    }
  }

  AppNotification _fromRow(Map<String, dynamic> row) {
    final readRaw = row['read_at'] as String?;
    final payload = row['payload'];
    return AppNotification(
      id: row['id'] as String,
      recipientId: row['recipient_id'] as String,
      kind: NotificationKindX.parse(row['kind'] as String),
      payload: payload is Map<String, dynamic>
          ? Map<String, dynamic>.from(payload)
          : const {},
      readAt: readRaw == null ? null : DateTime.parse(readRaw).toUtc(),
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
    );
  }
}
