import 'package:meta/meta.dart';

@immutable
class TripInput {
  const TripInput({required this.title, this.bodyOfWater});

  final String title;
  final String? bodyOfWater;
}
