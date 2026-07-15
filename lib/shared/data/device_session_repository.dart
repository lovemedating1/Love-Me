import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../models/device_session.dart';

/// Device sessions — live against `active_sessions` (migration
/// 001_auth_profiles.sql). Composite PK `(user_id, session_token)`; full CRUD
/// RLS scoped to `auth.uid() = user_id`.
///
/// **No server-side single-device enforcement exists yet** (see
/// BACKEND_REMAINING.md [BE-1]) — registering a session here does not revoke
/// any other device's session. This repository only gives the client an
/// honest list of its own recorded sessions and a way to delete rows (the
/// "revoke" UI wired to it is informational until a backend trigger enforces
/// the free-tier single-device rule).
abstract interface class DeviceSessionRepository {
  /// Registers (or re-touches) a session row for the current device. Called
  /// once per app start once a user is signed in. Returns the session token
  /// so this device can identify "is this me" in the returned list.
  Future<String> registerSession({
    required String deviceLabel,
    String? userAgent,
  });

  /// Updates `last_seen_at` for an existing session — a lightweight
  /// heartbeat so "Last active" reflects real usage, not just login time.
  Future<void> touchSession(String sessionToken);

  Future<List<DeviceSession>> mySessions({required String currentSessionToken});

  /// Deletes a specific session row ("sign out that device").
  Future<void> revoke(String sessionToken);

  /// Deletes every session row except [keepSessionToken] ("sign out of other
  /// devices").
  Future<void> revokeAllOthers(String keepSessionToken);
}

class SupabaseDeviceSessionRepository implements DeviceSessionRepository {
  const SupabaseDeviceSessionRepository();

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  @override
  Future<String> registerSession({
    required String deviceLabel,
    String? userAgent,
  }) async {
    final myId = _client.auth.currentUser!.id;
    final token = const Uuid().v4();
    await _client.from('active_sessions').insert({
      'user_id': myId,
      'session_token': token,
      'device_label': deviceLabel,
      if (userAgent != null) 'user_agent': userAgent,
    });
    return token;
  }

  @override
  Future<void> touchSession(String sessionToken) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return;
    await _client
        .from('active_sessions')
        .update({'last_seen_at': DateTime.now().toIso8601String()})
        .eq('user_id', myId)
        .eq('session_token', sessionToken);
  }

  @override
  Future<List<DeviceSession>> mySessions({
    required String currentSessionToken,
  }) async {
    final myId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('active_sessions')
        .select()
        .eq('user_id', myId)
        .order('last_seen_at', ascending: false);
    return (rows as List).map((r) {
      final row = r as Map<String, dynamic>;
      final token = row['session_token'] as String;
      return DeviceSession(
        id: token,
        label: (row['device_label'] as String?)?.trim().isNotEmpty == true
            ? row['device_label'] as String
            : 'Unknown device',
        os: row['user_agent'] as String? ?? '',
        lastActive: DateTime.parse(row['last_seen_at'] as String),
        isCurrent: token == currentSessionToken,
      );
    }).toList();
  }

  @override
  Future<void> revoke(String sessionToken) async {
    final myId = _client.auth.currentUser!.id;
    await _client
        .from('active_sessions')
        .delete()
        .eq('user_id', myId)
        .eq('session_token', sessionToken);
  }

  @override
  Future<void> revokeAllOthers(String keepSessionToken) async {
    final myId = _client.auth.currentUser!.id;
    await _client
        .from('active_sessions')
        .delete()
        .eq('user_id', myId)
        .neq('session_token', keepSessionToken);
  }
}
