import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Presence — live against `user_presence` (migration 001_auth_profiles.sql).
/// One row per user (`user_id` is the PK). SELECT is open to any signed-in
/// user (so others can see someone's online status); INSERT/UPDATE/DELETE are
/// scoped to `auth.uid() = user_id`.
abstract interface class PresenceRepository {
  /// Upserts `is_online` + refreshes `last_seen` for the current user.
  Future<void> setOnline(bool online);

  /// Reads a single user's presence row. Returns `null` if the row doesn't
  /// exist yet (a user who has never gone through a presence write).
  Future<UserPresence?> presenceFor(String userId);
}

/// Mirrors the live `user_presence` table.
class UserPresence {
  const UserPresence({
    required this.userId,
    required this.isOnline,
    required this.lastSeen,
  });

  final String userId;
  final bool isOnline;
  final DateTime lastSeen;

  factory UserPresence.fromJson(Map<String, dynamic> json) => UserPresence(
    userId: json['user_id'] as String,
    isOnline: json['is_online'] as bool? ?? false,
    lastSeen: DateTime.parse(json['last_seen'] as String),
  );
}

class SupabasePresenceRepository implements PresenceRepository {
  const SupabasePresenceRepository();

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  @override
  Future<void> setOnline(bool online) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return;
    await _client.from('user_presence').upsert({
      'user_id': myId,
      'is_online': online,
      'last_seen': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<UserPresence?> presenceFor(String userId) async {
    final row = await _client
        .from('user_presence')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : UserPresence.fromJson(row);
  }
}
