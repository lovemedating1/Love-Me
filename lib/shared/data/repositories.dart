import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/call_log.dart';
import '../models/profile.dart';
import 'call_repository.dart';
import 'chat_repository.dart';
import 'conversation_repository.dart';
import 'match_repository.dart';
import 'mock_data.dart';
import 'notification_repository.dart';
import 'profile_photo_repository.dart';
import 'swipe_repository.dart';

export 'call_repository.dart';
export 'chat_repository.dart' show ChatRepository, MessageConstraintException;
export 'conversation_repository.dart';
export 'match_repository.dart';
export 'notification_repository.dart';
export 'profile_photo_repository.dart';
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

/// Counts shown on the Profile screen's stats row.
class ProfileStats {
  const ProfileStats({this.views = 0, this.likes = 0, this.matches = 0});
  final int views;
  final int likes;
  final int matches;
}

abstract interface class ProfileRepository {
  Future<Profile> me();
  Future<List<Profile>> discoverFeed();
  Future<Profile?> byId(String id);
  Future<List<Profile>> likedYou();
  Future<List<Profile>> matches();
  Future<List<Profile>> byCountry(String country);

  /// Live counts for the Profile screen: how many people viewed me, liked me,
  /// and how many active matches I have.
  Future<ProfileStats> myStats();

  /// Patches editable fields on the current user's `profiles` row.
  Future<void> updateMyProfile({String? name, int? distancePreferenceKm});
}

// ---- Mock implementations --------------------------------------------------

/// Live-backed for `me()`/`byId()` (the `profiles` table), `discoverFeed()`
/// (real `profiles` rows, excluding self + already-swiped users), and
/// `likedYou()`/`matches()` (joined against the live `likes`/`matches`
/// tables). Only `byCountry()` stays on mock data — Explore's country RPC
/// (`get_country_counts`) isn't built server-side yet ([BE-9]).
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

  /// The Discover candidate deck — real `profiles` rows from the database,
  /// excluding myself and anyone I've already liked/passed.
  ///
  /// There's no server-side discovery/ranking RPC yet ([BE-9]): no geo
  /// ranking, no per-plan daily cap, no distance. This is a plain query
  /// (newest complete profiles first, capped) with client-side exclusion of
  /// already-swiped users. Age/gender/etc. filtering still happens in
  /// `discoverFiltersProvider` on top of this list.
  @override
  Future<List<Profile>> discoverFeed() async {
    final myId = _client.auth.currentUser!.id;
    final swiped = await swipeRepository.getSwipedUserIds();

    final rows = await _client
        .from('profiles')
        .select()
        .neq('user_id', myId)
        .eq('profile_complete', true)
        .order('created_at', ascending: false)
        .limit(100);

    return (rows as List)
        .map((p) => Profile.fromJson(p as Map<String, dynamic>))
        .where((p) => !swiped.contains(p.userId))
        .toList();
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

  /// `likes` and `matches` are counted for real. **`views` is always 0** —
  /// `profile_views` RLS only exposes views *you made*, not views *of you*
  /// ("who viewed me" needs a premium RPC that doesn't exist yet, per
  /// migration_002.md §5). We surface 0 rather than a fabricated number.
  @override
  Future<ProfileStats> myStats() async {
    final myId = _client.auth.currentUser!.id;

    final likes = await _client
        .from('likes')
        .count(sb.CountOption.exact)
        .eq('to_user_id', myId);

    final matches = await _client
        .from('matches')
        .count(sb.CountOption.exact)
        .or('user1_id.eq.$myId,user2_id.eq.$myId')
        .eq('status', 'active');

    return ProfileStats(views: 0, likes: likes, matches: matches);
  }

  @override
  Future<void> updateMyProfile({String? name, int? distancePreferenceKm}) async {
    if (name == null && distancePreferenceKm == null) return;
    final myId = _client.auth.currentUser!.id;
    await _client.from('profiles').update({
      if (name != null) 'name': name,
      if (distancePreferenceKm != null)
        'distance_preference_km': distancePreferenceKm,
    }).eq('user_id', myId);
  }
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

  @override
  Future<ProfileStats> myStats() => _delayed(const ProfileStats(
      views: MockData.viewsCount,
      likes: MockData.likesCount,
      matches: MockData.matchesCount));

  @override
  Future<void> updateMyProfile({String? name, int? distancePreferenceKm}) async {}
}

// ---- Providers -------------------------------------------------------------

final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => const SupabaseProfileRepository());

final swipeRepositoryProvider =
    Provider<SwipeRepository>((ref) => const SupabaseSwipeRepository());

final matchRepositoryProvider =
    Provider<MatchRepository>((ref) => const SupabaseMatchRepository());

final conversationRepositoryProvider = Provider<ConversationRepository>(
    (ref) => const SupabaseConversationRepository());

final chatRepositoryProvider =
    Provider<ChatRepository>((ref) => const SupabaseChatRepository());

final callRepositoryProvider =
    Provider<CallRepository>((ref) => const SupabaseCallRepository());

final notificationRepositoryProvider = Provider<NotificationRepository>(
    (ref) => const SupabaseNotificationRepository());

final profilePhotoRepositoryProvider = Provider<ProfilePhotoRepository>(
    (ref) => const SupabaseProfilePhotoRepository());

/// The current signed-in user's profile (live).
final currentUserProvider =
    FutureProvider<Profile>((ref) => ref.watch(profileRepositoryProvider).me());

/// Whether the current user has premium (mock — drives feature gates/blur).
final isPremiumProvider = StateProvider<bool>((ref) => false);

// ---- Async list providers for Phase 3 screens ------------------------------
final likedYouProvider =
    FutureProvider((ref) => ref.watch(profileRepositoryProvider).likedYou());
final matchesProvider =
    FutureProvider((ref) => ref.watch(profileRepositoryProvider).matches());
final conversationsProvider = FutureProvider(
    (ref) => ref.watch(conversationRepositoryProvider).conversationsForMe());

/// The conversation for a given partner's user id, or `null` if none exists
/// yet — a conversation only exists if backend created it out-of-band (no
/// insert policy / trigger yet, see ConversationRepository doc).
final conversationForPartnerProvider = FutureProvider.family(
    (ref, String partnerUserId) =>
        ref.watch(conversationRepositoryProvider).forPartner(partnerUserId));

final messagesProvider = FutureProvider.family(
    (ref, String conversationId) =>
        ref.watch(chatRepositoryProvider).getMessages(conversationId));
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
final myPhotosProvider = FutureProvider(
    (ref) => ref.watch(profilePhotoRepositoryProvider).myPhotos());

/// Live counts for the Profile stats row (views is always 0 — see myStats()).
final myStatsProvider =
    FutureProvider((ref) => ref.watch(profileRepositoryProvider).myStats());

/// Reactions on a conversation's messages, keyed by conversation id.
final reactionsProvider = FutureProvider.family(
    (ref, String conversationId) async {
  final messages = await ref.watch(messagesProvider(conversationId).future);
  return ref
      .watch(chatRepositoryProvider)
      .reactionsFor(messages.map((m) => m.id));
});

/// Call history for the Calls tab — every call across the user's conversations.
final callHistoryProvider = FutureProvider((ref) async {
  final convos = await ref.watch(conversationsProvider.future);
  final repo = ref.watch(callRepositoryProvider);
  final all = <CallLog>[];
  for (final c in convos) {
    all.addAll(await repo.getCallHistory(c.conversation.id));
  }
  all.sort((a, b) => b.startedAt.compareTo(a.startedAt));
  return all;
});

/// The current user's notification preferences row.
final notificationPreferencesProvider = FutureProvider(
    (ref) => ref.watch(notificationRepositoryProvider).getPreferences());

/// Raw active `matches` rows — needed to unmatch/block, which key off the
/// match id (matchesProvider only exposes the partner's Profile).
final myMatchRowsProvider =
    FutureProvider((ref) => ref.watch(matchRepositoryProvider).myMatches());
