import 'package:equatable/equatable.dart';

enum CallType { audio, video }

/// Lifecycle of a call, mirrored from `call_logs.call_status`.
///
/// - [ringing]   — created by the caller; the callee's device is ringing.
/// - [answered]  — the callee accepted; both sides are (or are joining) the
///                 Agora channel. Media is flowing / connecting.
/// - [declined]  — the callee explicitly rejected the call.
/// - [missed]    — the callee never answered (timed out / no response).
/// - [cancelled] — the caller hung up before the callee answered.
/// - [ended]     — a connected call finished normally (has a duration).
enum CallStatus { ringing, answered, declined, missed, cancelled, ended }

/// Mirrors the live `call_logs` table (migration 005_chat.sql), EXTENDED for
/// Agora voice/video calling (see BACKEND_CALLS_HANDOFF.md §2 — the backend
/// must add `channel_name`, `caller_agora_uid`, `receiver_agora_uid`).
///
/// `ended_by` may only be set together with `ended_at` in the same update
/// (constraint `call_logs_ended_by_requires_ended_at`) — always send both.
///
/// The Agora columns are read defensively (nullable): a row written before the
/// backend adds them simply has `channelName == null`, and the call flow treats
/// that as "not joinable" rather than crashing.
class CallLog extends Equatable {
  const CallLog({
    required this.id,
    required this.conversationId,
    required this.callerId,
    required this.receiverId,
    required this.callType,
    required this.callStatus,
    required this.startedAt,
    this.channelName,
    this.callerAgoraUid,
    this.receiverAgoraUid,
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

  /// The Agora RTC channel both participants join. Backend auto-fills this on
  /// INSERT with the call row's own id (globally unique) via the
  /// `set_call_channel_name` trigger, so it is **always populated** on rows
  /// created since the calling backend went live (2026-07-13). Nullable only
  /// for defensiveness against any legacy row; the controller falls back to
  /// `id` if ever null.
  final String? channelName;

  /// Stable per-participant numeric Agora uid. **The backend intentionally
  /// leaves these null** (confirmed 2026-07-13) — the client's deterministic
  /// locally-derived uid (a stable hash of the user id, see CallController.
  /// agoraUidFor) is the source of truth. These columns exist only as a future
  /// hook if the server ever needs to be authoritative about uids.
  final int? callerAgoraUid;
  final int? receiverAgoraUid;

  final DateTime? endedAt;
  final String? endedBy;
  final int? durationSeconds;

  /// The other participant's user id, given my own.
  String otherUserId(String myId) => callerId == myId ? receiverId : callerId;

  /// True when [myId] initiated this call.
  bool amICaller(String myId) => callerId == myId;

  factory CallLog.fromJson(Map<String, dynamic> json) => CallLog(
    id: json['id'] as String,
    conversationId: json['conversation_id'] as String,
    callerId: json['caller_id'] as String,
    receiverId: json['receiver_id'] as String,
    callType: CallType.values.byName(json['call_type'] as String),
    callStatus: CallStatus.values.byName(json['call_status'] as String),
    startedAt: DateTime.parse(json['started_at'] as String),
    channelName: json['channel_name'] as String?,
    callerAgoraUid: (json['caller_agora_uid'] as num?)?.toInt(),
    receiverAgoraUid: (json['receiver_agora_uid'] as num?)?.toInt(),
    endedAt: json['ended_at'] == null
        ? null
        : DateTime.parse(json['ended_at'] as String),
    endedBy: json['ended_by'] as String?,
    durationSeconds: json['duration_seconds'] as int?,
  );

  @override
  List<Object?> get props => [
    id,
    conversationId,
    callStatus,
    startedAt,
    channelName,
  ];
}
