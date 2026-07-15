import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/blocked_user.dart';
import '../models/safety_report.dart';

/// Reports &amp; blocking — targets the `reports` and `blocked_users` tables
/// proposed in `app doctumant/BACKEND_ATIER_HANDOFF.md` §1-2. **Neither table
/// exists server-side yet** (confirmed 404 in `BACKEND_REMAINING.md` [BE-5]);
/// every call here will fail until backend ships them. The interface/shape
/// is final so the swap is a no-op once the tables land — see the handoff
/// doc for the exact schema this repository assumes.
abstract interface class SafetyRepository {
  /// Submits a report against [reportedUserId]. If [alsoBlock] is true, also
  /// inserts a `blocked_users` row in the same call (used by the chat
  /// "Report &amp; Block" action).
  Future<void> submitReport({
    required String reportedUserId,
    required String reportedName,
    required ReportReason reason,
    String? description,
    bool alsoBlock = false,
  });

  Future<List<SafetyReport>> myReports();

  Future<void> blockUser({
    required String blockedUserId,
    required String blockedName,
  });

  Future<void> unblockUser(String blockedUserId);

  Future<List<BlockedUser>> myBlockedUsers();

  /// Whether the current user has already blocked [userId] — used to hide
  /// blocked profiles from Discover/Explore once backend also filters them
  /// server-side (see handoff doc §2, open question on discoverFeed()).
  Future<bool> hasBlocked(String userId);
}

/// Thrown when the `reports`/`blocked_users` tables don't exist yet
/// (Postgrest 42P01 "relation does not exist", surfaced as a 404 by
/// PostgREST) — lets the UI show "not available yet" instead of a raw error.
class SafetyFeatureUnavailableException implements Exception {
  const SafetyFeatureUnavailableException();
}

class SupabaseSafetyRepository implements SafetyRepository {
  const SupabaseSafetyRepository();

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  Never _mapError(Object e) {
    if (e is sb.PostgrestException &&
        (e.code == '42P01' || e.code == 'PGRST205')) {
      throw const SafetyFeatureUnavailableException();
    }
    throw e;
  }

  @override
  Future<void> submitReport({
    required String reportedUserId,
    required String reportedName,
    required ReportReason reason,
    String? description,
    bool alsoBlock = false,
  }) async {
    final myId = _client.auth.currentUser!.id;
    try {
      await _client.from('reports').insert({
        'reporter_user_id': myId,
        'reported_user_id': reportedUserId,
        'reported_name': reportedName,
        'reason': reason.wireValue,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        'status': 'pending',
      });
      if (alsoBlock) {
        await blockUser(
          blockedUserId: reportedUserId,
          blockedName: reportedName,
        );
      }
    } catch (e) {
      _mapError(e);
    }
  }

  @override
  Future<List<SafetyReport>> myReports() async {
    try {
      final myId = _client.auth.currentUser!.id;
      final rows = await _client
          .from('reports')
          .select()
          .eq('reporter_user_id', myId)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => SafetyReport.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _mapError(e);
    }
  }

  @override
  Future<void> blockUser({
    required String blockedUserId,
    required String blockedName,
  }) async {
    final myId = _client.auth.currentUser!.id;
    try {
      await _client.from('blocked_users').insert({
        'blocker_user_id': myId,
        'blocked_user_id': blockedUserId,
        'blocked_name': blockedName,
      });
    } on sb.PostgrestException catch (e) {
      if (e.code == '23505') return; // already blocked — treat as success
      _mapError(e);
    } catch (e) {
      _mapError(e);
    }
  }

  @override
  Future<void> unblockUser(String blockedUserId) async {
    final myId = _client.auth.currentUser!.id;
    try {
      await _client
          .from('blocked_users')
          .delete()
          .eq('blocker_user_id', myId)
          .eq('blocked_user_id', blockedUserId);
    } catch (e) {
      _mapError(e);
    }
  }

  @override
  Future<List<BlockedUser>> myBlockedUsers() async {
    try {
      final myId = _client.auth.currentUser!.id;
      final rows = await _client
          .from('blocked_users')
          .select()
          .eq('blocker_user_id', myId)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => BlockedUser.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _mapError(e);
    }
  }

  @override
  Future<bool> hasBlocked(String userId) async {
    try {
      final myId = _client.auth.currentUser!.id;
      final row = await _client
          .from('blocked_users')
          .select('id')
          .eq('blocker_user_id', myId)
          .eq('blocked_user_id', userId)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }
}
