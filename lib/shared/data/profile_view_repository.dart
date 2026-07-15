import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Profile-view logging — live against `profile_views` (migration
/// 003_matching.sql). RLS only exposes rows **you** created
/// (`viewer_user_id = auth.uid()`) — there is no way to query "who viewed
/// me" from the client; that needs a premium RPC that doesn't exist yet
/// (BACKEND_REMAINING.md [BE-10]). This repository only covers the write
/// side: recording that the current user viewed someone.
///
/// Quota enforcement is attempted via the `record_profile_view` RPC proposed
/// in `BACKEND_ATIER_HANDOFF.md` §4 (falls back to the old best-effort direct
/// insert if that RPC doesn't exist yet, so this stays a no-op change until
/// backend ships it — see [MonthlyViewCapExceededException]).
abstract interface class ProfileViewRepository {
  Future<void> recordView(String viewedUserId);

  /// Remaining profile views in the current free-tier monthly window, or
  /// `null` if premium/unknown (RPC missing). Backed by the proposed
  /// `get_view_quota` RPC — see `BACKEND_ATIER_HANDOFF.md` §4.
  Future<int?> remainingViewsThisMonth();
}

/// Thrown when the free-tier monthly profile-view cap
/// (`AppConstants.monthlyFreeViewCap`) has been reached, surfaced by the
/// proposed `record_profile_view` RPC. Not reachable today — that RPC
/// doesn't exist server-side yet ([BE-10]); reserved for when it ships.
class MonthlyViewCapExceededException implements Exception {
  const MonthlyViewCapExceededException();
}

class SupabaseProfileViewRepository implements ProfileViewRepository {
  const SupabaseProfileViewRepository();

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  @override
  Future<void> recordView(String viewedUserId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null || myId == viewedUserId) return;

    // Prefer the proposed `record_profile_view` RPC (does the insert +
    // quota check server-side atomically, see BACKEND_ATIER_HANDOFF.md §4).
    try {
      final result = await _client.rpc(
        'record_profile_view',
        params: {'viewed_user_id': viewedUserId},
      );
      if (result is Map && result['allowed'] == false) {
        throw const MonthlyViewCapExceededException();
      }
      return;
    } on MonthlyViewCapExceededException {
      rethrow;
    } catch (_) {
      // RPC missing — fall through to the old direct best-effort insert.
    }

    try {
      await _client.from('profile_views').insert({
        'viewer_user_id': myId,
        'viewed_user_id': viewedUserId,
      });
    } catch (_) {
      // Best-effort logging — never worth surfacing an error to the user for
      // a view they don't even know is being recorded.
    }
  }

  @override
  Future<int?> remainingViewsThisMonth() async {
    try {
      final result = await _client.rpc('get_view_quota');
      if (result is Map && result['remaining'] != null) {
        return result['remaining'] as int;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
