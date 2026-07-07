import '../models/app_notification.dart';
import '../models/conversation.dart';
import '../models/device_session.dart';
import '../models/message.dart';
import '../models/profile.dart';
import '../models/safety_report.dart';
import '../models/subscription_plan.dart';

/// In-memory sample data used by the whole front end during the mock-first
/// phases. When backend integration begins, this file is dropped and the
/// repositories point at real Supabase data sources instead.
class MockData {
  MockData._();

  /// Deterministic placeholder avatar (front-end only).
  static String _avatar(int seed) =>
      'https://picsum.photos/seed/loveme$seed/600/800';

  /// Mock helper — `profiles` stores `birthday`, not `age`.
  static DateTime _birthdayForAge(int age) =>
      DateTime.now().subtract(Duration(days: age * 365 + 20));

  static final List<Profile> profiles = [
    Profile(
      userId: 'u1',
      name: 'Sara',
      birthday: _birthdayForAge(26),
      gender: 'female',
      country: 'Kenya',
      city: 'Nairobi',
      photoUrl: _avatar(1),
      gallery: [_avatar(1), _avatar(11), _avatar(21)],
      bio: 'Coffee, hiking and good conversations. Looking for something real.',
      interests: ['Coffee', 'Hiking', 'Travel', 'Music'],
      distanceKm: 3.2,
      isOnline: true,
      isVerified: true,
      relationshipGoal: 'Long-term',
    ),
    Profile(
      userId: 'u2',
      name: 'Liam',
      birthday: _birthdayForAge(29),
      gender: 'male',
      country: 'Nigeria',
      city: 'Lagos',
      photoUrl: _avatar(2),
      gallery: [_avatar(2), _avatar(12)],
      bio: 'Software engineer by day, guitarist by night.',
      interests: ['Music', 'Tech', 'Football'],
      distanceKm: 8.7,
      isOnline: false,
      isVerified: false,
      relationshipGoal: 'Dating',
    ),
    Profile(
      userId: 'u3',
      name: 'Amara',
      birthday: _birthdayForAge(24),
      gender: 'female',
      country: 'Ghana',
      city: 'Accra',
      photoUrl: _avatar(3),
      gallery: [_avatar(3), _avatar(13), _avatar(23), _avatar(33)],
      bio: 'Foodie and beach lover. Send me your favourite playlist.',
      interests: ['Food', 'Beach', 'Movies', 'Yoga'],
      distanceKm: 12.0,
      isOnline: true,
      isVerified: true,
      isPremium: true,
      relationshipGoal: 'Friendship',
    ),
    Profile(
      userId: 'u4',
      name: 'Noah',
      birthday: _birthdayForAge(31),
      gender: 'male',
      country: 'South Africa',
      city: 'Cape Town',
      photoUrl: _avatar(4),
      gallery: [_avatar(4)],
      bio: 'Mountains, cameras, and spontaneous road trips.',
      interests: ['Photography', 'Travel', 'Coffee'],
      distanceKm: 21.5,
      isOnline: false,
      isVerified: true,
      relationshipGoal: 'Long-term',
    ),
    Profile(
      userId: 'u5',
      name: 'Zara',
      birthday: _birthdayForAge(27),
      gender: 'female',
      country: 'Egypt',
      city: 'Cairo',
      photoUrl: _avatar(5),
      gallery: [_avatar(5), _avatar(15)],
      bio: 'Artist and dreamer. Love deep talks over tea.',
      interests: ['Art', 'Tea', 'Books', 'Museums'],
      distanceKm: 40.1,
      isOnline: true,
      isVerified: false,
      relationshipGoal: 'Dating',
    ),
  ];

  /// The signed-in user (mock).
  static final Profile me = Profile(
    userId: 'me',
    name: 'Alex',
    birthday: _birthdayForAge(28),
    gender: 'male',
    country: 'Kenya',
    city: 'Nairobi',
    photoUrl: _avatar(99),
    gallery: [_avatar(99), _avatar(88)],
    bio: 'Just here to meet interesting people.',
    interests: ['Travel', 'Coffee', 'Tech'],
    isVerified: true,
    isPremium: false,
    relationshipGoal: 'Long-term',
  );

  static final List<Conversation> conversations = [
    Conversation(
      partnerId: 'u1',
      partnerName: 'Sara',
      partnerPhotoUrl: _avatar(1),
      lastMessage: 'That sounds perfect 😊',
      lastAt: DateTime.now().subtract(const Duration(minutes: 4)),
      unreadCount: 2,
      isOnline: true,
      isVerified: true,
    ),
    Conversation(
      partnerId: 'u3',
      partnerName: 'Amara',
      partnerPhotoUrl: _avatar(3),
      lastMessage: 'Haha you have to try it!',
      lastAt: DateTime.now().subtract(const Duration(hours: 2)),
      isOnline: true,
      isVerified: true,
    ),
    Conversation(
      partnerId: 'u4',
      partnerName: 'Noah',
      partnerPhotoUrl: _avatar(4),
      lastMessage: 'Let\'s plan that trip.',
      lastAt: DateTime.now().subtract(const Duration(days: 1)),
      isMuted: true,
      isVerified: true,
    ),
  ];

  static final List<AppNotification> notifications = [
    AppNotification(
      id: 'n1',
      type: NotificationType.match,
      title: 'It\'s a match!',
      body: 'You and Sara liked each other.',
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      relatedUserId: 'u1',
    ),
    AppNotification(
      id: 'n2',
      type: NotificationType.like,
      title: 'New like',
      body: 'Amara liked your profile.',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      isRead: false,
      relatedUserId: 'u3',
    ),
    AppNotification(
      id: 'n3',
      type: NotificationType.message,
      title: 'New message',
      body: 'Noah sent you a message.',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
      relatedUserId: 'u4',
    ),
  ];

  /// Profiles who liked "me" (Liked You tab) — a subset of [profiles].
  static List<Profile> get likedYou =>
      profiles.where((p) => ['u2', 'u3', 'u5'].contains(p.userId)).toList();

  /// Mutual matches (Matches tab) — partners we also have conversations with.
  static List<Profile> get matches =>
      profiles.where((p) => ['u1', 'u3', 'u4'].contains(p.userId)).toList();

  /// Own profile stats for the Profile screen.
  static const int viewsCount = 128;
  static const int likesCount = 42;
  static const int matchesCount = 7;

  /// Messages keyed by partner id (Chat screen).
  static Map<String, List<Message>> messages = {
    'u1': [
      Message(
        id: 'm1',
        senderId: 'u1',
        text: 'Hey Alex! Loved your travel photos 😊',
        sentAt: DateTime.now().subtract(const Duration(minutes: 40)),
        isRead: true,
      ),
      Message(
        id: 'm2',
        senderId: 'me',
        text: 'Thanks Sara! Where was your last trip?',
        sentAt: DateTime.now().subtract(const Duration(minutes: 32)),
        isRead: true,
      ),
      Message(
        id: 'm3',
        senderId: 'u1',
        text: 'Zanzibar — beaches were unreal 🏝️',
        sentAt: DateTime.now().subtract(const Duration(minutes: 20)),
        isRead: true,
        reaction: '❤️',
      ),
      Message(
        id: 'm4',
        senderId: 'u1',
        text: 'That sounds perfect 😊',
        sentAt: DateTime.now().subtract(const Duration(minutes: 4)),
        isRead: false,
      ),
    ],
    'u3': [
      Message(
        id: 'm5',
        senderId: 'me',
        text: 'That new cafe downtown is amazing',
        sentAt: DateTime.now().subtract(const Duration(hours: 3)),
        isRead: true,
      ),
      Message(
        id: 'm6',
        senderId: 'u3',
        text: 'Haha you have to try it!',
        sentAt: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: true,
      ),
    ],
  };

  /// Countries for Explore, with mock user counts.
  static const List<({String flag, String name, int count})> countries = [
    (flag: '🇰🇪', name: 'Kenya', count: 1240),
    (flag: '🇳🇬', name: 'Nigeria', count: 3180),
    (flag: '🇬🇭', name: 'Ghana', count: 870),
    (flag: '🇿🇦', name: 'South Africa', count: 1560),
    (flag: '🇪🇬', name: 'Egypt', count: 990),
    (flag: '🇮🇳', name: 'India', count: 5400),
    (flag: '🇺🇸', name: 'United States', count: 4100),
    (flag: '🇬🇧', name: 'United Kingdom', count: 2050),
  ];

  /// Premium plans (placeholder duration tiers — see SubscriptionPlan doc note).
  static const List<SubscriptionPlan> plans = [
    SubscriptionPlan(
        id: 'monthly', name: 'Monthly', priceUsd: 9.99, period: 'month'),
    SubscriptionPlan(
        id: 'quarterly',
        name: 'Quarterly',
        priceUsd: 24.99,
        period: '3 months',
        popular: true,
        savingsLabel: 'Save 17%'),
    SubscriptionPlan(
        id: 'yearly',
        name: 'Yearly',
        priceUsd: 79.99,
        period: 'year',
        savingsLabel: 'Save 33%'),
  ];

  static const List<String> premiumPerks = [
    'Unlimited likes',
    'See who liked you',
    'Read receipts',
    'Voice & video calls',
    'Advanced filters',
    'No ads',
  ];

  /// Safety reports the user has submitted.
  static final List<SafetyReport> reports = [
    SafetyReport(
      id: 'r1',
      reportedName: 'Unknown user',
      reason: 'Inappropriate photos',
      status: ReportStatus.resolved,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      description: 'Profile had explicit images.',
      adminResponse: 'Thanks — the account was removed.',
    ),
    SafetyReport(
      id: 'r2',
      reportedName: 'Spam account',
      reason: 'Spam / scam',
      status: ReportStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      description: 'Kept sending payment links.',
    ),
  ];

  /// Active signed-in device sessions (single-device policy demo).
  static final List<DeviceSession> devices = [
    DeviceSession(
      id: 'd1',
      label: 'Pixel 8 · Love Me app',
      os: 'Android 15',
      lastActive: DateTime.now(),
      isCurrent: true,
    ),
    DeviceSession(
      id: 'd2',
      label: 'Chrome · Windows',
      os: 'Windows 11',
      lastActive: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];
}
