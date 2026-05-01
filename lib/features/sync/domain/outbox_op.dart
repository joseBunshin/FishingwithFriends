import 'dart:convert';

import 'package:meta/meta.dart';

/// Status lifecycle of an outbox row.
///   pending → uploading → synced
///                       ↘ failed → uploading → ...  (retry)
///                       ↘ permanently_failed       (after retry budget)
enum OutboxStatus { pending, uploading, failed, permanentlyFailed, synced }

extension OutboxStatusX on OutboxStatus {
  String get dbValue => switch (this) {
        OutboxStatus.pending => 'pending',
        OutboxStatus.uploading => 'uploading',
        OutboxStatus.failed => 'failed',
        OutboxStatus.permanentlyFailed => 'permanently_failed',
        OutboxStatus.synced => 'synced',
      };

  static OutboxStatus parse(String raw) => switch (raw) {
        'pending' => OutboxStatus.pending,
        'uploading' => OutboxStatus.uploading,
        'failed' => OutboxStatus.failed,
        'permanently_failed' => OutboxStatus.permanentlyFailed,
        'synced' => OutboxStatus.synced,
        _ => throw FormatException('Unknown outbox status: $raw'),
      };
}

/// Sealed-style payload union. Each kind serializes to / parses from
/// the JSON `payload` text column on the outbox table.
@immutable
sealed class OutboxOpKind {
  const OutboxOpKind();

  String get opType;
  Map<String, dynamic> toJson();

  String encode() => jsonEncode(toJson());

  static OutboxOpKind decode(String opType, String payloadJson) {
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Outbox payload must be a JSON object');
    }
    return switch (opType) {
      'catch_create' => CatchCreateOp.fromJson(decoded),
      'entry_create' => EntryCreateOp.fromJson(decoded),
      'photo_upload' => PhotoUploadOp.fromJson(decoded),
      _ => throw FormatException('Unknown outbox op_type: $opType'),
    };
  }
}

@immutable
class CatchCreateOp extends OutboxOpKind {
  const CatchCreateOp({
    required this.catchId,
    required this.anglerId,
    required this.row,
    required this.localPhotoPaths,
  });

  factory CatchCreateOp.fromJson(Map<String, dynamic> json) {
    return CatchCreateOp(
      catchId: json['catch_id'] as String,
      anglerId: json['angler_id'] as String,
      row: Map<String, dynamic>.from(json['row'] as Map),
      localPhotoPaths: List<String>.from(json['local_photo_paths'] as List),
    );
  }

  /// Pre-assigned client-side UUID — same id used in the eventual
  /// server-side row.
  final String catchId;
  final String anglerId;

  /// The row payload to insert (excluding photo_paths, which are
  /// resolved by the photo_upload ops that precede this one).
  final Map<String, dynamic> row;

  /// Absolute filesystem paths of the queued photos (parallel to
  /// PhotoUploadOp ops with the same catchId). Used by sync orchestrator
  /// to clean up files after sync.
  final List<String> localPhotoPaths;

  @override
  String get opType => 'catch_create';

  @override
  Map<String, dynamic> toJson() => {
        'catch_id': catchId,
        'angler_id': anglerId,
        'row': row,
        'local_photo_paths': localPhotoPaths,
      };
}

@immutable
class EntryCreateOp extends OutboxOpKind {
  const EntryCreateOp({
    required this.tournamentId,
    required this.sourceCatchId,
    required this.anglerId,
  });

  factory EntryCreateOp.fromJson(Map<String, dynamic> json) {
    return EntryCreateOp(
      tournamentId: json['tournament_id'] as String,
      sourceCatchId: json['source_catch_id'] as String,
      anglerId: json['angler_id'] as String,
    );
  }

  final String tournamentId;
  final String sourceCatchId;
  final String anglerId;

  @override
  String get opType => 'entry_create';

  @override
  Map<String, dynamic> toJson() => {
        'tournament_id': tournamentId,
        'source_catch_id': sourceCatchId,
        'angler_id': anglerId,
      };
}

@immutable
class PhotoUploadOp extends OutboxOpKind {
  const PhotoUploadOp({
    required this.localPath,
    required this.anglerId,
    required this.catchId,
    required this.index,
  });

  factory PhotoUploadOp.fromJson(Map<String, dynamic> json) {
    return PhotoUploadOp(
      localPath: json['local_path'] as String,
      anglerId: json['angler_id'] as String,
      catchId: json['catch_id'] as String,
      index: json['index'] as int,
    );
  }

  final String localPath;
  final String anglerId;
  final String catchId;
  final int index;

  @override
  String get opType => 'photo_upload';

  @override
  Map<String, dynamic> toJson() => {
        'local_path': localPath,
        'angler_id': anglerId,
        'catch_id': catchId,
        'index': index,
      };
}

/// A whole outbox row decoded into its typed shape.
@immutable
class OutboxOp {
  const OutboxOp({
    required this.id,
    required this.kind,
    required this.status,
    required this.retryCount,
    required this.createdAt,
    this.lastAttemptAt,
    this.lastError,
  });

  final int id;
  final OutboxOpKind kind;
  final OutboxStatus status;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final String? lastError;
  final DateTime createdAt;
}
