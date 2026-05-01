import 'package:meta/meta.dart';

@immutable
class Profile {
  const Profile({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarPath,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? avatarPath;

  String get handle => '@$username';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Profile &&
          other.id == id &&
          other.username == username &&
          other.displayName == displayName &&
          other.avatarPath == avatarPath;

  @override
  int get hashCode => Object.hash(id, username, displayName, avatarPath);
}
