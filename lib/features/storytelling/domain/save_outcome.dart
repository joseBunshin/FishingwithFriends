import 'package:fishing_with_friends/features/storytelling/domain/personal_record.dart';
import 'package:fishing_with_friends/features/storytelling/domain/user_badge.dart';
import 'package:meta/meta.dart';

/// Aggregate of what storytelling rows the trigger produced for a single
/// just-saved catch. Used by the catch-log save flow to decide whether
/// to celebrate.
@immutable
class SaveOutcome {
  const SaveOutcome({
    required this.newPRs,
    required this.newBadges,
  });

  const SaveOutcome.empty()
      : newPRs = const [],
        newBadges = const [];

  final List<PersonalRecord> newPRs;
  final List<UserBadge> newBadges;

  bool get isCelebratory => newPRs.isNotEmpty || newBadges.isNotEmpty;
  int get totalCount => newPRs.length + newBadges.length;
}
