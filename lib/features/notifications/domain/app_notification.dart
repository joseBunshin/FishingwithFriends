import 'package:meta/meta.dart';

enum NotificationKind {
  friendRequest,
  friendAccepted,
  tournamentInvite,
  tournamentMemberApproved,
  tournamentMemberRejected,
  tournamentEntryApproved,
  tournamentEntryRejected,
  system,
}

extension NotificationKindX on NotificationKind {
  String get dbValue => switch (this) {
        NotificationKind.friendRequest => 'friend_request',
        NotificationKind.friendAccepted => 'friend_accepted',
        NotificationKind.tournamentInvite => 'tournament_invite',
        NotificationKind.tournamentMemberApproved =>
          'tournament_member_approved',
        NotificationKind.tournamentMemberRejected =>
          'tournament_member_rejected',
        NotificationKind.tournamentEntryApproved =>
          'tournament_entry_approved',
        NotificationKind.tournamentEntryRejected =>
          'tournament_entry_rejected',
        NotificationKind.system => 'system',
      };

  static NotificationKind parse(String raw) => switch (raw) {
        'friend_request' => NotificationKind.friendRequest,
        'friend_accepted' => NotificationKind.friendAccepted,
        'tournament_invite' => NotificationKind.tournamentInvite,
        'tournament_member_approved' =>
          NotificationKind.tournamentMemberApproved,
        'tournament_member_rejected' =>
          NotificationKind.tournamentMemberRejected,
        'tournament_entry_approved' =>
          NotificationKind.tournamentEntryApproved,
        'tournament_entry_rejected' =>
          NotificationKind.tournamentEntryRejected,
        'system' => NotificationKind.system,
        _ => NotificationKind.system,
      };
}

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String recipientId;
  final NotificationKind kind;
  final Map<String, dynamic> payload;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  /// Best-effort title from payload + kind. Triggers in 0005/0006 may
  /// stash a `title` directly; otherwise we synthesize one.
  String get title {
    final t = payload['title'];
    if (t is String && t.isNotEmpty) return t;
    return switch (kind) {
      NotificationKind.friendRequest => 'New friend request',
      NotificationKind.friendAccepted => 'Friend request accepted',
      NotificationKind.tournamentInvite => 'Tournament invite',
      NotificationKind.tournamentMemberApproved =>
        'You were approved for a tournament',
      NotificationKind.tournamentMemberRejected =>
        'Tournament request declined',
      NotificationKind.tournamentEntryApproved =>
        'Your catch was approved',
      NotificationKind.tournamentEntryRejected =>
        'Your catch was rejected',
      NotificationKind.system => 'Notification',
    };
  }

  String? get body {
    final b = payload['body'];
    if (b is String && b.isNotEmpty) return b;
    return null;
  }

  /// Optional deeplink path baked into the payload by triggers
  /// (e.g. `/tournaments/<id>`). Used by the Notifications screen on tap.
  String? get deeplinkPath {
    final p = payload['deeplink_path'];
    if (p is String && p.isNotEmpty) return p;
    // Heuristic fallbacks for kinds without an explicit deeplink.
    final tournamentId = payload['tournament_id'];
    if (tournamentId is String && tournamentId.isNotEmpty) {
      return '/tournaments/$tournamentId';
    }
    if (kind == NotificationKind.friendRequest ||
        kind == NotificationKind.friendAccepted) {
      return '/friends';
    }
    final catchId = payload['catch_id'];
    if (catchId is String && catchId.isNotEmpty) {
      return '/catches/$catchId';
    }
    return null;
  }
}
