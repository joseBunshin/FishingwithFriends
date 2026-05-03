import 'package:meta/meta.dart';

@immutable
class Badge {
  const Badge({
    required this.code,
    required this.title,
    required this.description,
    required this.iconName,
    required this.predicate,
    required this.params,
  });

  final String code;
  final String title;
  final String description;
  final String iconName;
  final String predicate;
  final Map<String, dynamic> params;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Badge &&
          other.code == code &&
          other.title == title &&
          other.description == description &&
          other.iconName == iconName &&
          other.predicate == predicate;

  @override
  int get hashCode =>
      Object.hash(code, title, description, iconName, predicate);
}
