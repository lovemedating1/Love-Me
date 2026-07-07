import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/app_notification.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/profile.dart';
import 'match_repository.dart';
import 'mock_data.dart';
import 'swipe_repository.dart';

export 'match_repository.dart';
export 'swipe_repository.dart' show AlreadySwipedException;

/// Repository interfaces + implementations.
///
/// This is the seam the backend track swaps: keep the interfaces stable and
/// replace `Mock*` with Supabase-backed implementations — the presentation
/// layer (screens/providers) does not change.
///
/// Migration 001 (`profiles`, `user_roles`, `active_sessions`, `fcm_tokens`/
/// `push_tokens`, `user_presence`) and migration 002/003 (`likes`, `passes`,
/// `matches`, `profile_views`) are live. [SupabaseProfileRepository] covers
/// `me()`/`byId()` plus `likedYou()`/`matches()` (joined against the live
/// tables); `discoverFeed()`/`byCountry()` stay on mock candidate data since
/// real discovery/ranking/geography filtering isn't built server-side yet.

abstract interface class ProfileRepository {
  Future<Profile> me();
  Future<List<Profile>> discoverFeed();
  Future<Profile?> byId(String id);
  Future<List<Profile>> likedYou();
  Future<List<Profile>> matches();
  Future<List<Profile>> byCountry(String country);
}

abstract interface class ConversationRepository {
  Future<List<Conversation>> conversations();
}

abstract interface class MessageRepository {
  Future<List<Message>> forPartner(String partnerId);
}

abstract interface class NotificationRepository {
  Future<List<AppNotification>> notifications();
}

// ---- Mock implementations --------------------------------------------------

/// Live-backed for `me()`/`byId()` (the `profiles` table) and for
/// `likedYou()`/`matches()` (joined against the live `likes`/`matches`
/// tables). `discoverFeed()` is still the mock candidate deck — real
/// discovery/ranking isn't built server-side yet — but it excludes profiles
/// already swiped via the live `likes`/`passes` tables. `byCountry()` stays
/// mock (Explore's candidate list isn't backed by a table yet either).
class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository({
    this.swipeRepository = const SupabaseSwipeRepository(),
    this.matchRepository = const SupabaseMatchRepository(),
  });

  final SwipeRepository swipeRepository;
  final MatchRepository matchRepository;

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  @override
  Future<Profile> me() async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('profiles')
        .select()
        .eq('user_id', userId)
        .single();
    return Profile.fromJson(row);
  }

  @override
  Future<Profile?> byId(String id) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('user_id', id)
        .maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  @override
  Future<List<Profile>> discoverFeed() async {
    final swiped = await swipeRepository.getSwipedUserIds();
    return MockData.profiles.where((p) => !swiped.contains(p.userId)).toList();
  }

  /// Everyone who liked the current user (`likes.to_user_id = me`), resolved
  /// to their `profiles` row.
  @override
  Future<List<Profile>> likedYou() async {
    final myId = _client.auth.currentUser!.id;
    final likeRows = await _client
        .from('likes')
        .select('from_user_id')
        .eq('to_user_id', myId)
        .order('created_at', ascending: false);
    final fromIds = (likeRows as List)
        .map((r) => r['from_user_id'] as String)
        .toList();
    if (fromIds.isEmpty) return [];
    final profileRows =
        await _client.from('profiles').select().inFilter('user_id', fromIds);
    return (profileRows as List)
        .map((p) => Profile.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// Active matches resolved to the other participant's `profiles` row.
  @override
  Future<List<Profile>> matches() async {
    final myId = _client.auth.currentUser!.id;
    final matches = await matchRepository.myMatches();
    final otherIds = matches.map((m) => m.otherUserId(myId)).toList();
    if (otherIds.isEmpty) return [];
    final profileRows =
        await _client.from('profiles').select().inFilter('user_id', otherIds);
    return (profileRows as List)
        .map((p) => Profile.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Profile>> byCountry(String country) => Future.delayed(
      const Duration(milliseconds: 400),
      () => MockData.profiles.where((p) => p.country == country).toList());
}

class MockProfileRepository implements ProfileRepository {
  const MockProfileRepository();

  Future<T> _delayed<T>(T value) =>
      Future.delayed(const Duration(milliseconds: 400), () => value);

  @override
  Future<Profile> me() => _delayed(MockData.me);

  @override
  Future<List<Profile>> discoverFeed() => _delayed(MockData.profiles);

  @override
  Future<Profile?> byId(String id) {
    if (id == MockData.me.userId) return _delayed<Profile?>(MockData.me);
    for (final p in MockData.profiles) {
      if (p.userId == id) return _delayed<Profile?>(p);
    }
    return _delayed<Profile?>(null);
  }

  @override
  Future<List<Profile>> likedYou() => _delayed(MockData.likedYou);

  @override
  Future<List<Profile>> matches() => _delayed(MockData.matches);

  @override
  Future<List<Profile>> byCountry(String country) =>
      _delayed(MockData.profiles.where((p) => p.country == country).toList());
}

class MockConversationRepository implements ConversationRepository {
  const MockConversationRepository();

  @override
  Future<List<Conversation>> conversations() => Future.delayed(
      const Duration(milliseconds: 400), () => MockData.conversations);
}

class MockMessageRepository implements MessageRepository {
  const MockMessageRepository();

  @override
  Future<List<Message>> forPartner(String partnerId) => Future.delayed(
      const Duration(milliseconds: 300),
      () => List<Message>.from(MockData.messages[partnerId] ?? const []));
}

class MockNotificationRepository implements NotificationRepository {
  const MockNotificationRepository();

  @override
  Future<List<AppNotification>> notifications() => Future.delayed(
      const Duration(milliseconds: 400), () => MockData.notifications);
}

// ---- Providers -------------------------------------------------------------

final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => const SupabaseProfileRepository());

final swipeRepositoryProvider =
    Provider<SwipeRepository>((ref) => const SupabaseSwipeRepository());

final matchRepositoryProvider =
    Provider<MatchRepository>((ref) => const SupabaseMatchRepository());

final conversationRepositoryProvider = Provider<ConversationRepository>(
    (ref) => const MockConversationRepository());

final messageRepositoryProvider =
    Provider<MessageRepository>((ref) => const MockMessageRepository());

final notificationRepositoryProvider = Provider<NotificationRepository>(
    (ref) => const MockNotificationRepository());

/// The current signed-in user's profile (live).
final currentUserProvider =
    FutureProvider<Profile>((ref) => ref.watch(profileRepositoryProvider).me());

/// Whether the current user has premium (mock — drives feature gates/blur).
final isPremiumProvider = StateProvider<bool>((ref) => false);

/// Whether the current user has the admin role (mock — gates Admin Diagnostics).
final isAdminProvider = StateProvider<bool>((ref) => false);

// ---- Async list providers for Phase 3 screens ------------------------------
final likedYouProvider =
    FutureProvider((ref) => ref.watch(profileRepositoryProvider).likedYou());
final matchesProvider =
    FutureProvider((ref) => ref.watch(profileRepositoryProvider).matches());
final conversationsProvider =
    FutureProvider((ref) => ref.watch(conversationRepositoryProvider).conversations());
final messagesProvider = FutureProvider.family(
    (ref, String partnerId) =>
        ref.watch(messageRepositoryProvider).forPartner(partnerId));
final profileByIdProvider = FutureProvider.family(
    (ref, String id) => ref.watch(profileRepositoryProvider).byId(id));
final notificationsProvider = FutureProvider(
    (ref) => ref.watch(notificationRepositoryProvider).notifications());
final safetyReportsProvider = FutureProvider(
    (ref) => Future.delayed(
        const Duration(milliseconds: 300), () => MockData.reports));
final devicesProvider = FutureProvider(
    (ref) => Future.delayed(
        const Duration(milliseconds: 300), () => MockData.devices));
final profilesByCountryProvider = FutureProvider.family(
    (ref, String country) =>
        ref.watch(profileRepositoryProvider).byCountry(country));
