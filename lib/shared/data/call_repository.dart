import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/call_log.dart';

/// A short-lived Agora RTC token plus the identity it was minted for.
///
/// Returned by the `get-agora-token` Edge Function (see
/// BACKEND_CALLS_HANDOFF.md §3). [token] is `null` only when the project runs
/// in App-ID-only / testing mode (no App Certificate) — the client may then
/// join with a null token.
class AgoraToken {
  const AgoraToken({
    required this.channelName,
    required this.uid,
    required this.token,
    this.expiresAt,
  });

  final String channelName;
  final int uid;
  final String? token;
  final DateTime? expiresAt;

  factory AgoraToken.fromJson(Map<String, dynamic> json) => AgoraToken(
    channelName: json['channel_name'] as String,
    uid: (json['uid'] as num).toInt(),
    token: json['token'] as String?,
    expiresAt: json['expires_at'] == null
        ? null
        : DateTime.parse(json['expires_at'] as String),
  );
}

/// Thrown when the token Edge Function is missing/errors, or the current user
/// isn't allowed a token for the requested channel.
class AgoraTokenException implements Exception {
  const AgoraTokenException(this.message);
  final String message;
  @override
  String toString() => 'AgoraTokenException: $message';
}

/// Calls — live against `call_logs` (migration 005_chat.sql), EXTENDED for
/// Agora voice/video calling.
///
/// The backend work this depends on is specified in BACKEND_CALLS_HANDOFF.md:
/// - `channel_name` / `caller_agora_uid` / `receiver_agora_uid` columns on
///   `call_logs` (§2),
/// - a `get-agora-token` Edge Function (§3),
/// - Supabase Realtime enabled on `call_logs` so the callee is rung (§4),
/// - a `notify_on_missed_call` trigger for the missed-call notification (§5).
abstract interface class CallRepository {
  /// Inserts a `ringing` row and returns it. The backend is expected to
  /// populate `channel_name` on insert (recommended: the row's id). If it
  /// doesn't yet, the client falls back to the row id as the channel name.
  Future<CallLog> startCall({
    required String conversationId,
    required String receiverId,
    required CallType callType,
  });

  /// Callee accepted — flips status to `answered`.
  Future<void> answerCall(String callId);

  /// Callee rejected — flips status to `declined` and closes the call.
  Future<void> declineCall(String callId);

  /// Caller hung up before answer — flips status to `cancelled` and closes.
  Future<void> cancelCall(String callId);

  /// Callee never answered within the ring timeout — flips status to `missed`.
  Future<void> markMissed(String callId);

  Future<void> updateCallStatus(String callId, CallStatus status);

  /// `ended_by` may only be set together with `ended_at` — always send both.
  Future<void> endCall(String callId, {required int durationSeconds});

  /// Fetches (or mints) a short-lived Agora RTC token for [channelName] as
  /// [uid], via the `get-agora-token` Edge Function.
  Future<AgoraToken> getAgoraToken({
    required String channelName,
    required int uid,
    required CallType callType,
  });

  /// Re-reads a single call row (to observe status transitions the other side
  /// made — answered/declined/cancelled/ended).
  Future<CallLog?> getCall(String callId);

  Future<List<CallLog>> getCallHistory(String conversationId);

  /// Subscribes to NEW incoming calls for the current user (rows where
  /// `receiver_id == me` and `call_status == 'ringing'`). Requires Realtime to
  /// be enabled on `call_logs` server-side (§4). Returns the channel so the
  /// caller can `unsubscribe()`.
  sb.RealtimeChannel subscribeToIncomingCalls(
    void Function(CallLog) onIncoming,
  );

  /// Subscribes to UPDATES on a specific call row — how the caller learns the
  /// callee answered/declined, and how either side learns the other ended.
  sb.RealtimeChannel subscribeToCall(
    String callId,
    void Function(CallLog) onUpdate,
  );
}

class SupabaseCallRepository implements CallRepository {
  const SupabaseCallRepository();

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  @override
  Future<CallLog> startCall({
    required String conversationId,
    required String receiverId,
    required CallType callType,
  }) async {
    final myId = _client.auth.currentUser!.id;
    final response = await _client
        .from('call_logs')
        .insert({
          'conversation_id': conversationId,
          'caller_id': myId,
          'receiver_id': receiverId,
          'call_type': callType.name,
          'call_status': CallStatus.ringing.name,
        })
        .select()
        .single();
    return CallLog.fromJson(response);
  }

  @override
  Future<void> answerCall(String callId) =>
      updateCallStatus(callId, CallStatus.answered);

  @override
  Future<void> declineCall(String callId) =>
      updateCallStatus(callId, CallStatus.declined);

  @override
  Future<void> cancelCall(String callId) =>
      updateCallStatus(callId, CallStatus.cancelled);

  @override
  Future<void> markMissed(String callId) =>
      updateCallStatus(callId, CallStatus.missed);

  @override
  Future<void> updateCallStatus(String callId, CallStatus status) => _client
      .from('call_logs')
      .update({'call_status': status.name})
      .eq('id', callId);

  @override
  Future<void> endCall(String callId, {required int durationSeconds}) async {
    final myId = _client.auth.currentUser!.id;
    await _client
        .from('call_logs')
        .update({
          'call_status': CallStatus.ended.name,
          'ended_at': DateTime.now().toIso8601String(),
          'ended_by': myId,
          'duration_seconds': durationSeconds,
        })
        .eq('id', callId);
  }

  @override
  Future<AgoraToken> getAgoraToken({
    required String channelName,
    required int uid,
    required CallType callType,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'get-agora-token',
        body: {
          'channel_name': channelName,
          'uid': uid,
          'call_type': callType.name,
        },
      );
      final data = res.data;
      if (data is Map<String, dynamic> && data['token'] != null) {
        return AgoraToken.fromJson(data);
      }
      throw const AgoraTokenException('Malformed token response.');
    } on sb.FunctionException catch (e) {
      // Status-code contract from the backend's Agora status doc (2026-07-13 §4):
      //   401 session expired/invalid · 400 bad request · 404 no such call ·
      //   403 not a participant OR the call is no longer ringing/answered ·
      //   500 server misconfig.
      throw AgoraTokenException(switch (e.status) {
        401 => 'Your session expired. Sign in again to make calls.',
        404 => 'This call no longer exists.',
        403 => 'This call is no longer active.',
        500 => 'Calling is temporarily unavailable. Try again shortly.',
        _ => 'Could not connect the call. Try again.',
      });
    } catch (e) {
      throw AgoraTokenException('Could not get a call token: $e');
    }
  }

  @override
  Future<CallLog?> getCall(String callId) async {
    final row = await _client
        .from('call_logs')
        .select()
        .eq('id', callId)
        .maybeSingle();
    return row == null ? null : CallLog.fromJson(row);
  }

  @override
  Future<List<CallLog>> getCallHistory(String conversationId) async {
    final response = await _client
        .from('call_logs')
        .select()
        .eq('conversation_id', conversationId)
        .order('started_at', ascending: false);
    return (response as List)
        .map((c) => CallLog.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  @override
  sb.RealtimeChannel subscribeToIncomingCalls(
    void Function(CallLog) onIncoming,
  ) {
    final myId = _client.auth.currentUser!.id;
    final channel = _client.channel('incoming_calls:$myId');
    channel
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.insert,
          schema: 'public',
          table: 'call_logs',
          filter: sb.PostgresChangeFilter(
            type: sb.PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: myId,
          ),
          callback: (payload) {
            final call = CallLog.fromJson(payload.newRecord);
            if (call.callStatus == CallStatus.ringing) onIncoming(call);
          },
        )
        .subscribe();
    return channel;
  }

  @override
  sb.RealtimeChannel subscribeToCall(
    String callId,
    void Function(CallLog) onUpdate,
  ) {
    final channel = _client.channel('call:$callId');
    channel
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.update,
          schema: 'public',
          table: 'call_logs',
          filter: sb.PostgresChangeFilter(
            type: sb.PostgresChangeFilterType.eq,
            column: 'id',
            value: callId,
          ),
          callback: (payload) => onUpdate(CallLog.fromJson(payload.newRecord)),
        )
        .subscribe();
    return channel;
  }
}
