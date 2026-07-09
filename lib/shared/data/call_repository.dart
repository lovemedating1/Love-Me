import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/call_log.dart';

/// Calls — live against `call_logs` (migration 005_chat.sql).
abstract interface class CallRepository {
  Future<CallLog> startCall({
    required String conversationId,
    required String receiverId,
    required CallType callType,
  });

  Future<void> updateCallStatus(String callId, CallStatus status);

  /// `ended_by` may only be set together with `ended_at` — always send both.
  Future<void> endCall(String callId, {required int durationSeconds});

  Future<List<CallLog>> getCallHistory(String conversationId);
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
        })
        .select()
        .single();
    return CallLog.fromJson(response);
  }

  @override
  Future<void> updateCallStatus(String callId, CallStatus status) => _client
      .from('call_logs')
      .update({'call_status': status.name}).eq('id', callId);

  @override
  Future<void> endCall(String callId, {required int durationSeconds}) async {
    final myId = _client.auth.currentUser!.id;
    await _client.from('call_logs').update({
      'call_status': CallStatus.ended.name,
      'ended_at': DateTime.now().toIso8601String(),
      'ended_by': myId,
      'duration_seconds': durationSeconds,
    }).eq('id', callId);
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
}
