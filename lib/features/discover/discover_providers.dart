import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/data/repositories.dart';
import '../../shared/models/profile.dart';
import '../../shared/models/profile_photo.dart';

/// Radius presets shown as chips in the search-radius sheet (km).
const List<int> kRadiusPresetsKm = [5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000];

/// Discover feed filters.
class DiscoverFilters {
  const DiscoverFilters({
    this.minAge = 18,
    this.maxAge = 60,
    this.maxDistanceKm = 500,
    this.gender, // null = all
    this.onlineOnly = false,
    this.verifiedOnly = false,
  });

  final int minAge;
  final int maxAge;
  final double maxDistanceKm;
  final String? gender;
  final bool onlineOnly;
  final bool verifiedOnly;

  DiscoverFilters copyWith({
    int? minAge,
    int? maxAge,
    double? maxDistanceKm,
    String? gender,
    bool clearGender = false,
    bool? onlineOnly,
    bool? verifiedOnly,
  }) =>
      DiscoverFilters(
        minAge: minAge ?? this.minAge,
        maxAge: maxAge ?? this.maxAge,
        maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
        gender: clearGender ? null : (gender ?? this.gender),
        onlineOnly: onlineOnly ?? this.onlineOnly,
        verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      );

  bool matches(Profile p) {
    final age = p.age;
    if (age != null && (age < minAge || age > maxAge)) return false;
    if ((p.distanceKm ?? 0) > maxDistanceKm) return false;
    if (gender != null && p.gender != gender) return false;
    if (onlineOnly && !p.isOnline) return false;
    if (verifiedOnly && !p.isVerified) return false;
    return true;
  }
}

final discoverFiltersProvider =
    NotifierProvider<DiscoverFiltersController, DiscoverFilters>(
        DiscoverFiltersController.new);

class DiscoverFiltersController extends Notifier<DiscoverFilters> {
  @override
  DiscoverFilters build() => const DiscoverFilters();
  void set(DiscoverFilters f) => state = f;
  void reset() => state = const DiscoverFilters();
}

/// The filtered feed of profiles — real `profiles` rows from the database
/// (see `SupabaseProfileRepository.discoverFeed`), with the local
/// [DiscoverFilters] applied on top.
final discoverFeedProvider = FutureProvider<List<Profile>>((ref) async {
  final all = await ref.watch(profileRepositoryProvider).discoverFeed();
  final filters = ref.watch(discoverFiltersProvider);
  return all.where(filters.matches).toList();
});

/// Worldwide search toggle — when on, the radius slider/filters are ignored.
final worldwideSearchProvider = StateProvider<bool>((ref) => true);

/// Selected search radius in km (used only when worldwide is off).
final searchRadiusKmProvider = StateProvider<int>((ref) => 50);

/// Gallery photos for a Discover card, keyed by user id. Falls back to just
/// the single `photoUrl` when the user has no `profile_photos` rows (e.g.
/// mock candidates, or real users who haven't uploaded a gallery yet).
final cardPhotosProvider =
    FutureProvider.family<List<ProfilePhoto>, String>((ref, userId) async {
  try {
    return await ref.read(profilePhotoRepositoryProvider).photosFor(userId);
  } catch (_) {
    return const [];
  }
});
