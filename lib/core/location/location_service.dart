import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// A real GPS fix: latitude/longitude + the device's reported accuracy in
/// meters (stored so the UI/backend can flag low-accuracy fixes later).
class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
}

/// Thrown when the user denies the location permission (once, or
/// permanently via "don't ask again" / device settings).
class LocationPermissionDeniedException implements Exception {
  const LocationPermissionDeniedException({required this.permanently});
  final bool permanently;
}

/// Thrown when location services (GPS) are off at the OS level.
class LocationServiceDisabledException implements Exception {
  const LocationServiceDisabledException();
}

/// One-shot GPS capture for onboarding's "Use current location" — this is
/// NOT background tracking; it takes a single fix and returns.
class LocationService {
  /// Requests permission (if needed) and returns one current GPS fix.
  Future<LocationFix> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationPermissionDeniedException(permanently: false);
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionDeniedException(permanently: true);
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return LocationFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
    );
  }
}

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());
