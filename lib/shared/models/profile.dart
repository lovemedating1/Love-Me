import 'package:equatable/equatable.dart';

/// Cross-feature user profile model — mirrors the live `profiles` table
/// (migration 001_auth_profiles.sql) for the columns that exist there.
///
/// `bio`/`interests`/`occupation` are read/written against the proposed
/// `profiles.bio`/`profiles.interests`/`profiles.occupation` columns (see
/// `BACKEND_BTIER_HANDOFF.md` §4, [BE-13]) — they round-trip through
/// [fromJson]/[toInsertJson] like any other real field, but those columns
/// don't exist server-side yet, so writes/reads are silently no-ops
/// (`fromJson` reads `null`/empty, `toInsertJson`'s `update()` call just
/// won't find the column) until backend ships them.
///
/// Fields marked "local-only" below (gallery, isPremium, isOnline) are NOT
/// backed by a column/table in the live schema at all (superseded by
/// `profile_photos`, deferred to the final payments tier, and read
/// separately via `presenceForProvider` respectively) — they default to
/// empty/false and are never sent to Supabase.
class Profile extends Equatable {
  const Profile({
    required this.userId,
    required this.name,
    required this.city,
    required this.country,
    this.birthday,
    this.gender,
    this.orientation,
    this.interestedIn,
    this.maritalStatus,
    this.relationshipGoal,
    this.hobbies = const [],
    this.distanceKm,
    this.distancePreferenceKm = 50,
    this.locationLat,
    this.locationLng,
    this.locationAccuracyM,
    this.photoUrl,
    this.isVerified = false,
    this.profileComplete = false,
    this.isPremium = false,
    this.premiumUntil,
    this.planId,
    this.ringtone = '',
    this.bio,
    this.interests = const [],
    this.occupation,
    // Local-only (no backing column/table at all):
    this.gallery = const [],
    this.isOnline = false,
  });

  final String userId;
  final String name;
  final String city;
  final String country;
  final DateTime? birthday;
  final String? gender; // 'male' | 'female'
  final String? orientation;
  final String? interestedIn;
  final String? maritalStatus;
  final String? relationshipGoal;
  final List<String> hobbies;
  final double? distanceKm;
  final int distancePreferenceKm;

  /// Real GPS fix from onboarding's "Use current location" (`geolocator`).
  /// Null until the user grants location permission and captures one.
  final double? locationLat;
  final double? locationLng;
  final double? locationAccuracyM;

  final String? photoUrl;
  final bool isVerified;
  final bool profileComplete;
  final bool isPremium;

  /// When the current subscription lapses. Read-only from the client (set by
  /// the payment backend). `null` when the user has no active plan — the
  /// header's renewal countdown pill is **hidden** in that case rather than
  /// showing a fabricated number.
  final DateTime? premiumUntil;

  /// Which of the 5 locked plan tiers (`SubscriptionPlan.id`) the user is
  /// currently on — read/written against the proposed `profiles.plan_id`
  /// column (see `BACKEND_PAYMENTS_HANDOFF.md` §3). `null` when free/no
  /// active plan, or when the column doesn't exist server-side yet
  /// (read-only from the client; a real purchase sets this server-side via
  /// `verify-purchase`, never a direct client PATCH).
  final String? planId;

  final String ringtone;

  /// Whole days until [premiumUntil], or `null` when unknown/expired.
  int? get premiumDaysLeft {
    final until = premiumUntil;
    if (until == null) return null;
    final days = until.difference(DateTime.now()).inDays;
    return days < 0 ? null : days;
  }

  final String? bio;
  final List<String> interests;
  final String? occupation;

  // Local-only fields (see class doc) — no backing column/table at all.
  final List<String> gallery;
  final bool isOnline;

  /// Computed from [birthday] — the `profiles` table has no `age` column.
  int? get age {
    final b = birthday;
    if (b == null) return null;
    final now = DateTime.now();
    var years = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) {
      years--;
    }
    return years;
  }

  /// Display string for [age] — falls back to '–' when birthday is unknown.
  String get ageLabel => age?.toString() ?? '–';

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      userId: json['user_id'] as String,
      name: json['name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      country: json['country'] as String? ?? '',
      birthday: json['birthday'] == null
          ? null
          : DateTime.parse(json['birthday'] as String),
      gender: json['gender'] as String?,
      orientation: json['orientation'] as String?,
      interestedIn: json['interested_in'] as String?,
      maritalStatus: json['marital_status'] as String?,
      relationshipGoal: json['relationship_goal'] as String?,
      hobbies: (json['hobbies'] as List<dynamic>?)?.cast<String>() ?? const [],
      distancePreferenceKm: json['distance_preference_km'] as int? ?? 50,
      locationLat: (json['location_lat'] as num?)?.toDouble(),
      locationLng: (json['location_lng'] as num?)?.toDouble(),
      locationAccuracyM: (json['location_accuracy_m'] as num?)?.toDouble(),
      photoUrl: json['photo_url'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      profileComplete: json['profile_complete'] as bool? ?? false,
      isPremium: json['is_premium'] as bool? ?? false,
      premiumUntil: json['premium_until'] == null
          ? null
          : DateTime.parse(json['premium_until'] as String),
      planId: json['plan_id'] as String?,
      ringtone: json['ringtone'] as String? ?? '',
      bio: json['bio'] as String?,
      interests:
          (json['interests'] as List<dynamic>?)?.cast<String>() ?? const [],
      occupation: json['occupation'] as String?,
    );
  }

  /// Wire shape for POST/PATCH `/rest/v1/profiles`. Only includes columns
  /// that exist in the live table (`bio`/`interests`/`occupation` are
  /// proposed, not yet live — see class doc).
  Map<String, dynamic> toInsertJson() => {
    'user_id': userId,
    'name': name,
    'city': city,
    'country': country,
    if (birthday != null)
      'birthday':
          '${birthday!.year.toString().padLeft(4, '0')}-${birthday!.month.toString().padLeft(2, '0')}-${birthday!.day.toString().padLeft(2, '0')}',
    if (gender != null) 'gender': gender,
    if (orientation != null) 'orientation': orientation,
    if (interestedIn != null) 'interested_in': interestedIn,
    if (maritalStatus != null) 'marital_status': maritalStatus,
    if (relationshipGoal != null) 'relationship_goal': relationshipGoal,
    'hobbies': hobbies,
    'distance_preference_km': distancePreferenceKm,
    if (locationLat != null) 'location_lat': locationLat,
    if (locationLng != null) 'location_lng': locationLng,
    if (locationAccuracyM != null) 'location_accuracy_m': locationAccuracyM,
    if (photoUrl != null) 'photo_url': photoUrl,
    'ringtone': ringtone,
    'profile_complete': profileComplete,
    if (bio != null) 'bio': bio,
    'interests': interests,
    if (occupation != null) 'occupation': occupation,
  };

  Profile copyWith({
    String? name,
    String? city,
    String? country,
    DateTime? birthday,
    String? gender,
    String? orientation,
    String? interestedIn,
    String? maritalStatus,
    String? relationshipGoal,
    List<String>? hobbies,
    double? distanceKm,
    int? distancePreferenceKm,
    double? locationLat,
    double? locationLng,
    double? locationAccuracyM,
    String? photoUrl,
    bool? isVerified,
    bool? profileComplete,
    bool? isPremium,
    DateTime? premiumUntil,
    String? planId,
    String? ringtone,
    List<String>? gallery,
    String? bio,
    List<String>? interests,
    String? occupation,
    bool? isOnline,
  }) {
    return Profile(
      userId: userId,
      name: name ?? this.name,
      city: city ?? this.city,
      country: country ?? this.country,
      birthday: birthday ?? this.birthday,
      gender: gender ?? this.gender,
      orientation: orientation ?? this.orientation,
      interestedIn: interestedIn ?? this.interestedIn,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      relationshipGoal: relationshipGoal ?? this.relationshipGoal,
      hobbies: hobbies ?? this.hobbies,
      distanceKm: distanceKm ?? this.distanceKm,
      distancePreferenceKm: distancePreferenceKm ?? this.distancePreferenceKm,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      locationAccuracyM: locationAccuracyM ?? this.locationAccuracyM,
      photoUrl: photoUrl ?? this.photoUrl,
      isVerified: isVerified ?? this.isVerified,
      profileComplete: profileComplete ?? this.profileComplete,
      isPremium: isPremium ?? this.isPremium,
      premiumUntil: premiumUntil ?? this.premiumUntil,
      planId: planId ?? this.planId,
      ringtone: ringtone ?? this.ringtone,
      gallery: gallery ?? this.gallery,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      occupation: occupation ?? this.occupation,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  List<Object?> get props => [userId, name, city, country, birthday, gender];
}
