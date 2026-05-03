import 'package:meta/meta.dart';

@immutable
class Profile {
  const Profile({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarPath,
    this.bio,
    this.homeWater,
    this.onboardingCompletedAt,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? avatarPath;
  final String? bio;
  final String? homeWater;
  final DateTime? onboardingCompletedAt;

  String get handle => '@$username';

  /// True once the user has finished the M7 onboarding flow. Used by the
  /// router to redirect new users to /onboarding.
  bool get hasCompletedOnboarding => onboardingCompletedAt != null;

  Profile copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatarPath,
    String? bio,
    String? homeWater,
    DateTime? onboardingCompletedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarPath: avatarPath ?? this.avatarPath,
      bio: bio ?? this.bio,
      homeWater: homeWater ?? this.homeWater,
      onboardingCompletedAt: onboardingCompletedAt ?? this.onboardingCompletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Profile &&
          other.id == id &&
          other.username == username &&
          other.displayName == displayName &&
          other.avatarPath == avatarPath &&
          other.bio == bio &&
          other.homeWater == homeWater &&
          other.onboardingCompletedAt == onboardingCompletedAt;

  @override
  int get hashCode => Object.hash(
        id,
        username,
        displayName,
        avatarPath,
        bio,
        homeWater,
        onboardingCompletedAt,
      );
}
