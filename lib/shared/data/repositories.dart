import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/utils/geo_distance.dart';
import '../models/blocked_user.dart';
import '../models/call_log.dart';
import '../models/device_session.dart';
import '../models/profile.dart';
import '../models/safety_report.dart';
import '../models/verification_request.dart';
import 'call_repository.dart';
import 'chat_repository.dart';
import 'conversation_repository.dart';
import 'device_session_repository.dart';
import 'match_repository.dart';
import 'mock_data.dart';
import 'notification_repository.dart';
import 'presence_repository.dart';
import 'profile_photo_repository.dart';
import 'profile_view_repository.dart';
import 'purchase_repository.dart';
import 'safety_repository.dart';
import 'swipe_repository.dart';
import 'verification_repository.dart';

export 'call_repository.dart';
export 'chat_repository.dart' show ChatRepository, MessageConstraintException;
export 'conversation_repository.dart';
export 'device_session_repository.dart';
export 'match_repository.dart';
export 'notification_repository.dart';
export 'presence_repository.dart';
export 'profile_photo_repository.dart';
export 'profile_view_repository.dart';
export 'purchase_repository.dart';
export 'safety_repository.dart';
export 'swipe_repository.dart'
    show AlreadySwipedException, DailyLikeCapExceededException;
export 'verification_repository.dart';

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
/// tables); `discoverFeed()` queries real `profiles_discoverable` rows (see
/// its own doc comment for the ranking caveats) — only `byCountry()` still
/// stays on mock candidate data, pending a real by-country RPC ([BE-9]).

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

  /// Real per-country user counts for the Explore grid. Prefers the
  /// proposed `get_country_counts` RPC (see `BACKEND_BTIER_HANDOFF.md` §1);
  /// falls back to counting real `profiles_discoverable` rows client-side,
  /// grouped by country, if that RPC doesn't exist yet. Never fabricates a
  /// number — a country with 0 discoverable profiles is simply absent from
  /// the returned map rather than shown with a fake count.
  Future<Map<String, int>> countryCounts();

  /// Patches editable fields on the current user's `profiles` row.
  Future<void> updateMyProfile({
    String? name,
    int? distancePreferenceKm,
    String? bio,
    List<String>? interests,
    String? occupation,
  });
}

// ---- Mock implementations --------------------------------------------------

/// Live-backed for `me()`/`byId()` (the `profiles` table), `discoverFeed()`/
/// `byCountry()` (real `profiles_discoverable` rows), and `likedYou()`/
/// `matches()` (joined against the live `likes`/`matches` tables). Country
/// *counts* shown on the Explore grid still come from a proposed
/// `get_country_counts` RPC that isn't built server-side yet ([BE-9], see
/// `BACKEND_BTIER_HANDOFF.md`) — `myStats()`/Explore fall back to a
/// client-computed approximation in that case (see `explore_screen.dart`).
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

  /// The Discover candidate deck — real profile rows from the database,
  /// excluding myself and anyone I've already liked/passed.
  ///
  /// Calls the `get_discover_profiles_page(p_limit, p_offset)` RPC (backend
  /// 2026-07-14, `039_fix_discover_profiles_overload_ambiguity.sql` — see
  /// `app doctumant/B-TIER Backend Response.md` §3), NOT the older 0-arg
  /// `get_discover_profiles()` (a different, pre-existing function this
  /// client has never called — see the A-TIER follow-up thread). The paged
  /// RPC returns `setof profiles_discoverable` — the same `security_invoker`
  /// view already used for blocking (`035_blocked_users_table_level_gating.sql`),
  /// so self/suspended/already-liked/passed/matched/blocked exclusion all
  /// happen server-side; no client-side `neq`/exclusion filtering needed
  /// beyond the defensive already-swiped check below (kept in case the
  /// view's timing lags a same-session swipe).
  ///
  /// Still no server-side ranking/geo-sort or per-plan daily cap ([BE-9],
  /// see `BACKEND_BTIER_HANDOFF.md` §2 — both need a product decision before
  /// backend builds further). This is a thin pagination wrapper only,
  /// newest-complete-profiles-first, same order as before. Distance is
  /// filled in client-side via [GeoDistance] against my own
  /// `location_lat`/`location_lng` (real GPS fixes captured at onboarding) —
  /// display-only, not server-side sorting/filtering. Age/gender/etc.
  /// filtering still happens in `discoverFiltersProvider` on top of this
  /// list.
  @override
  Future<List<Profile>> discoverFeed() async {
    final swiped = await swipeRepository.getSwipedUserIds();
    final me = await this.me();

    final rows = await _client.rpc(
      'get_discover_profiles_page',
      params: {'p_limit': 100, 'p_offset': 0},
    );

    return (rows as List)
        .map((p) => Profile.fromJson(p as Map<String, dynamic>))
        .where((p) => !swiped.contains(p.userId))
        .map((p) => _withDistance(p, me))
        .toList();
  }

  /// Fills in [Profile.distanceKm] via client-side great-circle distance
  /// against my own coordinates — see [discoverFeed]'s doc comment.
  Profile _withDistance(Profile p, Profile me) {
    final km = GeoDistance.betweenKm(
      lat1: me.locationLat,
      lng1: me.locationLng,
      lat2: p.locationLat,
      lng2: p.locationLng,
    );
    return km == null ? p : p.copyWith(distanceKm: km);
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
    final profileRows = await _client
        .from('profiles')
        .select()
        .inFilter('user_id', fromIds);
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
    final profileRows = await _client
        .from('profiles')
        .select()
        .inFilter('user_id', otherIds);
    return (profileRows as List)
        .map((p) => Profile.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// Explore's by-country list — real `profiles_discoverable` rows (same
  /// blocked/suspended/self exclusion as [discoverFeed], but NOT excluding
  /// already-liked/passed/matched users, since browsing Explore isn't the
  /// swipe deck). Distance is filled in the same client-side way as
  /// [discoverFeed] when both users have a captured location.
  @override
  Future<List<Profile>> byCountry(String country) async {
    final myId = _client.auth.currentUser!.id;
    final me = await this.me();

    final rows = await _client
        .from('profiles_discoverable')
        .select()
        .neq('user_id', myId)
        .eq('country', country)
        .eq('profile_complete', true)
        .order('created_at', ascending: false)
        .limit(100);

    return (rows as List)
        .map((p) => Profile.fromJson(p as Map<String, dynamic>))
        .map((p) => _withDistance(p, me))
        .toList();
  }

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

  /// Prefers the proposed `get_country_counts` RPC (returns
  /// `[{"country": "Kenya", "count": 42}, ...]`); falls back to counting
  /// real `profiles_discoverable` rows client-side (paged in batches of
  /// 1000, grouped by `country`) if that RPC isn't live yet. Either way,
  /// only countries with at least one real discoverable profile appear —
  /// no zero-padding, no fabricated minimums.
  @override
  Future<Map<String, int>> countryCounts() async {
    try {
      final rows = await _client.rpc('get_country_counts');
      final counts = <String, int>{};
      for (final row in rows as List) {
        final r = row as Map<String, dynamic>;
        final country = r['country'] as String?;
        final count = r['count'] as int?;
        if (country != null && count != null) counts[country] = count;
      }
      return counts;
    } catch (_) {
      // RPC missing — fall back to a client-side aggregate.
    }

    final counts = <String, int>{};
    var offset = 0;
    const pageSize = 1000;
    while (true) {
      final rows = await _client
          .from('profiles_discoverable')
          .select('country')
          .eq('profile_complete', true)
          .range(offset, offset + pageSize - 1);
      final page = rows as List;
      for (final row in page) {
        final country = (row as Map<String, dynamic>)['country'] as String?;
        if (country == null || country.isEmpty) continue;
        counts[country] = (counts[country] ?? 0) + 1;
      }
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return counts;
  }

  @override
  Future<void> updateMyProfile({
    String? name,
    int? distancePreferenceKm,
    String? bio,
    List<String>? interests,
    String? occupation,
  }) async {
    if (name == null &&
        distancePreferenceKm == null &&
        bio == null &&
        interests == null &&
        occupation == null) {
      return;
    }
    final myId = _client.auth.currentUser!.id;
    await _client
        .from('profiles')
        .update({
          if (name != null) 'name': name,
          if (distancePreferenceKm != null)
            'distance_preference_km': distancePreferenceKm,
          if (bio != null) 'bio': bio,
          if (interests != null) 'interests': interests,
          if (occupation != null) 'occupation': occupation,
        })
        .eq('user_id', myId);
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
  Future<ProfileStats> myStats() => _delayed(
    const ProfileStats(
      views: MockData.viewsCount,
      likes: MockData.likesCount,
      matches: MockData.matchesCount,
    ),
  );

  @override
  Future<Map<String, int>> countryCounts() =>
      _delayed({for (final c in MockData.countries) c.name: c.count});

  @override
  Future<void> updateMyProfile({
    String? name,
    int? distancePreferenceKm,
    String? bio,
    List<String>? interests,
    String? occupation,
  }) async {}
}

// ---- Providers -------------------------------------------------------------

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => const SupabaseProfileRepository(),
);

final swipeRepositoryProvider = Provider<SwipeRepository>(
  (ref) => const SupabaseSwipeRepository(),
);

final matchRepositoryProvider = Provider<MatchRepository>(
  (ref) => const SupabaseMatchRepository(),
);

final conversationRepositoryProvider = Provider<ConversationRepository>(
  (ref) => const SupabaseConversationRepository(),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => const SupabaseChatRepository(),
);

final callRepositoryProvider = Provider<CallRepository>(
  (ref) => const SupabaseCallRepository(),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => const SupabaseNotificationRepository(),
);

final profilePhotoRepositoryProvider = Provider<ProfilePhotoRepository>(
  (ref) => const SupabaseProfilePhotoRepository(),
);

final presenceRepositoryProvider = Provider<PresenceRepository>(
  (ref) => const SupabasePresenceRepository(),
);

final deviceSessionRepositoryProvider = Provider<DeviceSessionRepository>(
  (ref) => const SupabaseDeviceSessionRepository(),
);

final profileViewRepositoryProvider = Provider<ProfileViewRepository>(
  (ref) => const SupabaseProfileViewRepository(),
);

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => const SupabaseSafetyRepository(),
);

final verificationRepositoryProvider = Provider<VerificationRepository>(
  (ref) => const SupabaseVerificationRepository(),
);

final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (ref) => const SupabasePurchaseRepository(),
);

/// Another user's live presence row (online/last-seen). Returns `null` if
/// they have never had a presence row written (e.g. never opened the app
/// since this feature shipped) — callers should treat that as "unknown", not
/// "offline".
final presenceForProvider = FutureProvider.family<UserPresence?, String>(
  (ref, userId) => ref.watch(presenceRepositoryProvider).presenceFor(userId),
);

/// The current signed-in user's profile (live).
final currentUserProvider = FutureProvider<Profile>(
  (ref) => ref.watch(profileRepositoryProvider).me(),
);

/// Whether the current user has an active premium plan — derived from the
/// real, backend-set `profiles.is_premium` column (via [currentUserProvider]),
/// not a local mock toggle. Drives every premium feature gate/blur in the
/// app (Discover's profile cap copy, Likes' blur gate, Profile's plan
/// card, Settings). Real purchases update `profiles.is_premium`/
/// `premium_until` server-side (see `BACKEND_PAYMENTS_HANDOFF.md`) —
/// `ref.invalidate(currentUserProvider)` after a successful purchase is
/// what actually flips this, not a direct write to this provider (which no
/// longer has a settable `.notifier).state`, unlike the old mock version).
final isPremiumProvider = Provider<bool>(
  (ref) => ref.watch(currentUserProvider).valueOrNull?.isPremium ?? false,
);

// ---- Async list providers for Phase 3 screens ------------------------------
final likedYouProvider = FutureProvider(
  (ref) => ref.watch(profileRepositoryProvider).likedYou(),
);
final matchesProvider = FutureProvider(
  (ref) => ref.watch(profileRepositoryProvider).matches(),
);
final conversationsProvider = FutureProvider(
  (ref) => ref.watch(conversationRepositoryProvider).conversationsForMe(),
);

/// The conversation for a given partner's user id, or `null` if none exists
/// yet — a conversation only exists if backend created it out-of-band (no
/// insert policy / trigger yet, see ConversationRepository doc).
final conversationForPartnerProvider = FutureProvider.family(
  (ref, String partnerUserId) =>
      ref.watch(conversationRepositoryProvider).forPartner(partnerUserId),
);

final messagesProvider = FutureProvider.family(
  (ref, String conversationId) =>
      ref.watch(chatRepositoryProvider).getMessages(conversationId),
);
final profileByIdProvider = FutureProvider.family(
  (ref, String id) => ref.watch(profileRepositoryProvider).byId(id),
);
final notificationsProvider = FutureProvider(
  (ref) => ref.watch(notificationRepositoryProvider).notifications(),
);

/// Real reports the user has submitted, against the (not-yet-live) `reports`
/// table (see `BACKEND_ATIER_HANDOFF.md` §1). Surfaces an empty list rather
/// than an error when the table doesn't exist yet
/// ([SafetyFeatureUnavailableException]) — the screen shows its normal empty
/// state instead of an error banner while backend ships this.
final safetyReportsProvider = FutureProvider<List<SafetyReport>>((ref) async {
  try {
    return await ref.watch(safetyRepositoryProvider).myReports();
  } on SafetyFeatureUnavailableException {
    return const [];
  }
});

/// Real blocked-user rows, against the (not-yet-live) `blocked_users` table
/// (see `BACKEND_ATIER_HANDOFF.md` §2). Same not-yet-live fallback as
/// [safetyReportsProvider].
final blockedUsersProvider = FutureProvider<List<BlockedUser>>((ref) async {
  try {
    return await ref.watch(safetyRepositoryProvider).myBlockedUsers();
  } on SafetyFeatureUnavailableException {
    return const [];
  }
});

/// The current user's most recent identity-verification submission, against
/// the (not-yet-live) `verification_requests` table (see
/// `BACKEND_VERIFICATION_HANDOFF.md`). `null` (not-yet-submitted) rather
/// than an error when the table doesn't exist yet.
final myVerificationRequestProvider = FutureProvider<VerificationRequest?>((
  ref,
) async {
  try {
    return await ref.watch(verificationRepositoryProvider).myLatestRequest();
  } on VerificationFeatureUnavailableException {
    return null;
  }
});

/// Remaining likes in the current free-tier 24h window. `null` = premium or
/// unknown (quota RPC not live yet, see [SwipeRepository.remainingLikesToday]).
final remainingLikesTodayProvider = FutureProvider<int?>(
  (ref) => ref.watch(swipeRepositoryProvider).remainingLikesToday(),
);

/// Remaining profile views in the current free-tier monthly window. `null` =
/// premium or unknown (quota RPC not live yet).
final remainingViewsThisMonthProvider = FutureProvider<int?>(
  (ref) => ref.watch(profileViewRepositoryProvider).remainingViewsThisMonth(),
);

/// This device's `active_sessions.session_token` for the current login,
/// set once by [DeviceSessionRegistrar] right after sign-in/session-restore.
/// Null until registration completes.
final currentSessionTokenProvider = StateProvider<String?>((ref) => null);

/// Real active-session rows for the current user (live `active_sessions`).
/// Empty (not an error) if the current session hasn't finished registering
/// yet — the Devices screen just shows nothing-to-revoke-yet briefly.
final devicesProvider = FutureProvider((ref) async {
  final token = ref.watch(currentSessionTokenProvider);
  if (token == null) return const <DeviceSession>[];
  return ref
      .watch(deviceSessionRepositoryProvider)
      .mySessions(currentSessionToken: token);
});
final profilesByCountryProvider = FutureProvider.family(
  (ref, String country) =>
      ref.watch(profileRepositoryProvider).byCountry(country),
);

/// Real per-country user counts for the Explore grid (see
/// `ProfileRepository.countryCounts` doc for the RPC/fallback behavior).
final countryCountsProvider = FutureProvider<Map<String, int>>(
  (ref) => ref.watch(profileRepositoryProvider).countryCounts(),
);
final myPhotosProvider = FutureProvider(
  (ref) => ref.watch(profilePhotoRepositoryProvider).myPhotos(),
);

/// Live counts for the Profile stats row (views is always 0 — see myStats()).
final myStatsProvider = FutureProvider(
  (ref) => ref.watch(profileRepositoryProvider).myStats(),
);

/// Reactions on a conversation's messages, keyed by conversation id.
final reactionsProvider = FutureProvider.family((
  ref,
  String conversationId,
) async {
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
  (ref) => ref.watch(notificationRepositoryProvider).getPreferences(),
);

/// Raw active `matches` rows — needed to unmatch/block, which key off the
/// match id (matchesProvider only exposes the partner's Profile).
final myMatchRowsProvider = FutureProvider(
  (ref) => ref.watch(matchRepositoryProvider).myMatches(),
);
