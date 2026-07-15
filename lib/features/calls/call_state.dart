import 'package:equatable/equatable.dart';

import '../../shared/models/call_log.dart';

/// Where in its lifecycle the current call is.
enum CallPhase {
  /// No active call.
  idle,

  /// I placed a call; the callee's device is ringing; waiting for answer.
  outgoingRinging,

  /// A call is ringing on MY device; I haven't accepted/declined yet.
  incomingRinging,

  /// Accepted on one side; joining the Agora channel / waiting for the remote
  /// participant to join the media channel.
  connecting,

  /// Both participants are in the channel; media is flowing.
  connected,

  /// The call has ended (declined, missed, cancelled, or hung up). Terminal —
  /// the UI shows a brief end state, then pops.
  ended,
}

/// Why a call ended, for the end-of-call summary.
enum CallEndReason { hangUp, declined, missed, cancelled, failed, remoteLeft }

/// Immutable snapshot of the single in-flight call. There is at most one call
/// at a time (enforced by CallController).
class CallState extends Equatable {
  const CallState({
    this.phase = CallPhase.idle,
    this.call,
    this.partnerId,
    this.partnerName,
    this.partnerPhotoUrl,
    this.isVideo = false,
    this.amICaller = true,
    this.durationSeconds = 0,
    this.endReason,
    this.errorMessage,
  });

  final CallPhase phase;

  /// The backing `call_logs` row, once created/received.
  final CallLog? call;

  /// The other participant (for the call UI header/avatar).
  final String? partnerId;
  final String? partnerName;
  final String? partnerPhotoUrl;

  final bool isVideo;

  /// True if I initiated this call (outgoing), false if I'm the callee.
  final bool amICaller;

  /// Seconds since the call connected (drives the in-call timer).
  final int durationSeconds;

  final CallEndReason? endReason;

  /// Non-null when something failed (token error, permission denied, etc.).
  final String? errorMessage;

  bool get isActive => phase != CallPhase.idle && phase != CallPhase.ended;

  CallState copyWith({
    CallPhase? phase,
    CallLog? call,
    String? partnerId,
    String? partnerName,
    String? partnerPhotoUrl,
    bool? isVideo,
    bool? amICaller,
    int? durationSeconds,
    CallEndReason? endReason,
    String? errorMessage,
  }) {
    return CallState(
      phase: phase ?? this.phase,
      call: call ?? this.call,
      partnerId: partnerId ?? this.partnerId,
      partnerName: partnerName ?? this.partnerName,
      partnerPhotoUrl: partnerPhotoUrl ?? this.partnerPhotoUrl,
      isVideo: isVideo ?? this.isVideo,
      amICaller: amICaller ?? this.amICaller,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      endReason: endReason ?? this.endReason,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    phase,
    call?.id,
    partnerId,
    isVideo,
    amICaller,
    durationSeconds,
    endReason,
  ];
}
