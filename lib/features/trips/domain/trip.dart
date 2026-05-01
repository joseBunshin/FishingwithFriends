import 'package:meta/meta.dart';

@immutable
class Trip {
  const Trip({
    required this.id,
    required this.anglerId,
    required this.title,
    required this.startedAt,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.bodyOfWater,
    this.coverPhotoPath,
    this.endedAt,
  });

  final String id;
  final String anglerId;
  final String title;
  final String? bodyOfWater;
  final String? coverPhotoPath;
  final DateTime startedAt;
  final DateTime? endedAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Trip copyWith({
    String? id,
    String? anglerId,
    String? title,
    String? bodyOfWater,
    String? coverPhotoPath,
    DateTime? startedAt,
    DateTime? endedAt,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      anglerId: anglerId ?? this.anglerId,
      title: title ?? this.title,
      bodyOfWater: bodyOfWater ?? this.bodyOfWater,
      coverPhotoPath: coverPhotoPath ?? this.coverPhotoPath,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Trip &&
          other.id == id &&
          other.anglerId == anglerId &&
          other.title == title &&
          other.bodyOfWater == bodyOfWater &&
          other.coverPhotoPath == coverPhotoPath &&
          other.startedAt == startedAt &&
          other.endedAt == endedAt &&
          other.isActive == isActive &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hashAll([
        id,
        anglerId,
        title,
        bodyOfWater,
        coverPhotoPath,
        startedAt,
        endedAt,
        isActive,
        createdAt,
        updatedAt,
      ]);
}
