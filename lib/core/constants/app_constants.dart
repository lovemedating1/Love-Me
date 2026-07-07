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
  static const int maxBioChars = 500;
  static const int maxInterests = 8;
  static const int maxGalleryPhotos = 6;
  static const int messageMaxChars = 2000;
  static const int minAge = 18;
  static const int nearbyMaxKm = 500;

  static const String supportEmail = 'support@loveme-app.com';
}
