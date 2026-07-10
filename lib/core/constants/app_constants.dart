/// App-wide numeric / string constants (front-end).
class AppConstants {
  AppConstants._();

  static const String appName = 'Love Me';
  static const double maxContainerWidth = 448; // mobile container cap
  static const double defaultRadius = 14;
  static const double cardRadius = 16;
  static const double bottomNavHeight = 72;

  // Business caps (free tier) — UI-side mirrors of server gates.
  static const int dailyLikeCap = 50;
  static const int monthlyFreeViewCap = 50;
  static const int freeTrialDays = 3;

  // Content limits.
  /// Old app shows "Min 6 characters" on both Login and Sign Up.
  static const int minPasswordChars = 6;

  static const int maxBioChars = 500;
  static const int maxInterests = 8;
  static const int messageMaxChars = 2000;
  static const int minAge = 18;
  static const int nearbyMaxKm = 500;

  /// Sentinel value stored in `profiles.distance_preference_km` to mean
  /// "worldwide" — larger than any real preset (Discover's radius sheet
  /// tops out at 5000km) and larger than any possible real-world distance,
  /// so it's unambiguous. Avoids adding a separate boolean column.
  static const int kWorldwideDistanceKm = 20000;

  static const String supportEmail = 'support@loveme-app.com';
}
