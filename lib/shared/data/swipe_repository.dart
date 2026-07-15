import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Likes & passes (swipe actions) — live against `likes`/`passes`
/// (migration 003_matching.sql / 004_matching_rls.sql).
///
/// No `matches` insert here: a mutual like is turned into a `matches` row
/// (and a `conversations` row) automatically by the live `SECURITY DEFINER`
/// triggers `create_match_on_mutual_like` + `create_conversation_on_match`
/// (migrations 014/011, deployed & verified 2026-07-10). So a `likeProfile`
/// that completes the pair simply succeeds — the match/conversation appear
/// server-side and surface via the realtime subscriptions in
/// [MatchRepository.subscribeToNewMatches] / the Likes screen.
abstract interface class SwipeRepository {
  Future<void> likeProfile(String toUserId);
  Future<void> passProfile(String toUserId);
  Future<void> unlikeProfile(String toUserId);
  Future<Set<String>> getSwipedUserIds();

  /// Remaining likes in the current free-tier 24h window, or `null` if the
  /// user is premium (unlimited) / the quota RPC isn't available. Backed by
  /// the `can_send_like` RPC proposed in `BACKEND_ATIER_HANDOFF.md` §4 —
  /// returns `null` today since that RPC doesn't exist yet ([BE-10]).
  Future<int?> remainingLikesToday();
}

/// Thrown when the server rejects a swipe because it was already recorded
/// (`likes`/`passes` unique violation, Postgres code 23505).
class AlreadySwipedException implements Exception {
  const AlreadySwipedException();
}

/// Thrown when the free-tier daily like cap (50/24h, `AppConstants.dailyLikeCap`)
/// has been reached — surfaced by the `can_send_like` RPC proposed in
/// `BACKEND_ATIER_HANDOFF.md` §4. Not reachable today since that RPC doesn't
/// exist server-side yet ([BE-10]); reserved for when it ships.
class DailyLikeCapExceededException implements Exception {
  const DailyLikeCapExceededException();
}

class SupabaseSwipeRepository implements SwipeRepository {
  const SupabaseSwipeRepository();

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  @override
  Future<void> likeProfile(String toUserId) async {
    final myId = _client.auth.currentUser!.id;
    try {
      // Pre-flight quota check via the proposed `can_send_like` RPC (see
      // BACKEND_ATIER_HANDOFF.md §4). Swallows any error other than an
      // explicit `false` result — if the RPC doesn't exist yet (today), this
      // silently no-ops and the insert below proceeds unguarded, same as
      // before this quota work landed.
      try {
        final allowed = await _client.rpc('can_send_like');
        if (allowed == false) throw const DailyLikeCapExceededException();
      } on DailyLikeCapExceededException {
        rethrow;
      } catch (_) {
        // RPC missing/erroring — fall through, no client-side gate.
      }
      await _client.from('likes').insert({
        'from_user_id': myId,
        'to_user_id': toUserId,
      });
    } on sb.PostgrestException catch (e) {
      if (e.code == '23505') throw const AlreadySwipedException();
      rethrow;
    }
  }

  /// Reads the remaining-likes count from the proposed `get_like_quota` RPC
  /// (`BACKEND_ATIER_HANDOFF.md` §4). Returns `null` (unknown/unlimited) if
  /// the RPC doesn't exist yet — callers should hide quota UI in that case
  /// rather than show a fabricated number.
  @override
  Future<int?> remainingLikesToday() async {
    try {
      final result = await _client.rpc('get_like_quota');
      if (result is Map && result['remaining'] != null) {
        return result['remaining'] as int;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> passProfile(String toUserId) async {
    final myId = _client.auth.currentUser!.id;
    try {
      await _client.from('passes').insert({
        'from_user_id': myId,
        'to_user_id': toUserId,
      });
    } on sb.PostgrestException catch (e) {
      if (e.code == '23505') throw const AlreadySwipedException();
      rethrow;
    }
  }

  @override
  Future<void> unlikeProfile(String toUserId) async {
    final myId = _client.auth.currentUser!.id;
    await _client
        .from('likes')
        .delete()
        .eq('from_user_id', myId)
        .eq('to_user_id', toUserId);
  }

  @override
  Future<Set<String>> getSwipedUserIds() async {
    final myId = _client.auth.currentUser!.id;
    final liked = await _client
        .from('likes')
        .select('to_user_id')
        .eq('from_user_id', myId);
    final passed = await _client
        .from('passes')
        .select('to_user_id')
        .eq('from_user_id', myId);

    final ids = <String>{};
    for (final row in liked as List) {
      ids.add(row['to_user_id'] as String);
    }
    for (final row in passed as List) {
      ids.add(row['to_user_id'] as String);
    }
    return ids;
  }
}
