import 'package:equatable/equatable.dart';

enum CallType { audio, video }

enum CallStatus { ringing, answered, declined, missed, cancelled, ended }

/// Mirrors the live `call_logs` table (migration 005_chat.sql).
///
/// `ended_by` may only be set together with `ended_at` in the same update
/// (constraint `call_logs_ended_by_requires_ended_at`) — always send both.
class CallLog extends Equatable {
  const CallLog({
    required this.id,
    required this.conversationId,
    required this.callerId,
    required this.receiverId,
    required this.callType,
    required this.callStatus,
    required this.startedAt,
    this.endedAt,
    this.endedBy,
    this.durationSeconds,
  });

  final String id;
  final String conversationId;
  final String callerId;
  final String receiverId;
  final CallType callType;
  final CallStatus callStatus;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? endedBy;
  final int? durationSeconds;

  factory CallLog.fromJson(Map<String, dynamic> json) => CallLog(
        id: json['id'] as String,
        conversationId: json['conversation_id'] as String,
        callerId: json['caller_id'] as String,
        receiverId: json['receiver_id'] as String,
        callType: CallType.values.byName(json['call_type'] as String),
        callStatus: CallStatus.values.byName(json['call_status'] as String),
        startedAt: DateTime.parse(json['started_at'] as String),
        endedAt: json['ended_at'] == null
            ? null
            : DateTime.parse(json['ended_at'] as String),
        endedBy: json['ended_by'] as String?,
        durationSeconds: json['duration_seconds'] as int?,
      );

  @override
  List<Object?> get props => [id, conversationId, callStatus, startedAt];
}
