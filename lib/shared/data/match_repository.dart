import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/match.dart';

/// Matches — live against `matches` (migration 003_matching.sql).
///
/// RLS grants SELECT/UPDATE only: matches are system-created by a mutual-like
/// trigger that hasn't shipped yet, so there is no `create`/insert here.
abstract interface class MatchRepository {
  Future<List<Match>> myMatches();
  Future<void> unmatch(String matchId);
  Future<void> block(String matchId);

  /// Fires when a new `matches` row involving the current user is inserted
  /// (i.e. once the mutual-like trigger exists and creates one).
  sb.RealtimeChannel subscribeToNewMatches(void Function(Match) onNewMatch);
}

class SupabaseMatchRepository implements MatchRepository {
  const SupabaseMatchRepository();

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  @override
  Future<List<Match>> myMatches() async {
    final myId = _client.auth.currentUser!.id;
    final response = await _client
        .from('matches')
        .select()
        .or('user1_id.eq.$myId,user2_id.eq.$myId')
        .eq('status', 'active')
        .order('matched_at', ascending: false);
    return (response as List)
        .map((m) => Match.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> unmatch(String matchId) => _client
      .from('matches')
      .update({'status': 'unmatched'}).eq('id', matchId);

  @override
  Future<void> block(String matchId) {
    final myId = _client.auth.currentUser!.id;
    return _client
        .from('matches')
        .update({'status': 'blocked', 'blocked_by': myId}).eq('id', matchId);
  }

  @override
  sb.RealtimeChannel subscribeToNewMatches(void Function(Match) onNewMatch) {
    final myId = _client.auth.currentUser!.id;
    return _client
        .channel('public:matches:$myId')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.insert,
          schema: 'public',
          table: 'matches',
          callback: (payload) {
            final match = Match.fromJson(payload.newRecord);
            if (match.user1Id == myId || match.user2Id == myId) {
              onNewMatch(match);
            }
          },
        )
        .subscribe();
  }
}
