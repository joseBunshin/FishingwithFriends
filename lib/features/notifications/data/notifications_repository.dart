import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/features/notifications/domain/app_notification.dart';
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
      await _client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
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
      await _client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('recipient_id', userId)
          .filter('read_at', 'is', null);
    } on PostgrestException catch (e) {
      throw NetworkFailure(
        'Failed to mark all read: ${e.message}',
        cause: e,
      );
    }
  }

  /// Hard-delete a single notification by id. RLS policy
  /// `notifications_delete_own` (migration 0027) gates this to the row's
  /// recipient.
  Future<void> delete(String id) async {
    try {
      await _client.from('notifications').delete().eq('id', id);
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
