/// Central route path registry — matches the 23 routes in the UI/rebuild docs.
class RoutePaths {
  RoutePaths._();

  // Public / auth flow
  static const String auth = '/auth';
  static const String emailVerified = '/email-verified';
  static const String resetPassword = '/reset-password';
  static const String profileSetup = '/profile-setup';

  // Tabs (inside AppShell)
  static const String discover = '/';
  static const String likes = '/likes';
  static const String messages = '/messages';
  static const String explore = '/explore';
  static const String profile = '/profile';

  // Detail / secondary
  static const String chat = '/chat/:id';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String devices = '/devices';
  static const String subscription = '/subscription';
  static const String safetyReports = '/safety-reports';
  static const String deleteAccount = '/delete-account';

  // Legal
  static const String privacy = '/privacy-policy';
  static const String terms = '/terms';
  static const String refund = '/refund-policy';
  static const String childSafety = '/child-safety';

  /// Build a concrete chat path from a partner id.
  static String chatTo(String id) => '/chat/$id';
}
