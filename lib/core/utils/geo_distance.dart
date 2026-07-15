import 'dart:math';

/// Client-side great-circle distance — the only geo math this app does
/// today. Backend has no PostGIS/geo-ranking RPC yet ([BE-9]/`get_discover_profiles`
/// doesn't sort or filter by distance server-side), so `discoverFeed()`/
/// `byCountry()` compute this themselves from each profile's captured
/// `location_lat`/`location_lng` (real GPS fixes from onboarding's "Use
/// current location" step) against the current user's own coordinates.
///
/// Returns `null` if either point is missing a coordinate — callers should
/// treat that as "distance unknown" (hide the badge), never fabricate 0.
class GeoDistance {
  GeoDistance._();

  static const _earthRadiusKm = 6371.0;

  static double? betweenKm({
    required double? lat1,
    required double? lng1,
    required double? lat2,
    required double? lng2,
  }) {
    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
      return null;
    }
    final dLat = _radians(lat2 - lat1);
    final dLng = _radians(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_radians(lat1)) *
            cos(_radians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  static double _radians(double degrees) => degrees * pi / 180;
}
