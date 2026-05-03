import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Resolved coordinate pair returned by [LocationService.currentPosition].
typedef Coordinates = ({double latitude, double longitude});

/// Thin wrapper over `geolocator`. Returns `null` when the user has denied
/// permission, the device has no location services enabled, or the lookup
/// times out — the catch-log form treats `null` as "fall back to manual
/// location" rather than blocking Save.
class LocationService {
  const LocationService();

  Future<Coordinates?> currentPosition({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final servicesEnabled = await Geolocator.isLocationServiceEnabled();
    if (!servicesEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      return (latitude: pos.latitude, longitude: pos.longitude);
    } on Exception {
      return null;
    }
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => const LocationService(),
);
