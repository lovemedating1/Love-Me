import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/calls/agora_call_service.dart';
import '../../core/config/agora_config.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/call_log.dart';
import 'call_state.dart';

/// How long an outgoing call rings before we give up and mark it missed.
const _kRingTimeout = Duration(seconds: 35);

/// The single active-call controller. Owns the [AgoraCallService], the
/// `call_logs` row lifecycle, and the realtime subscriptions that keep both
/// sides in sync. Exactly one call may be active at a time.
///
/// Design split:
/// - **Signaling** = Supabase `call_logs` + Realtime (ring / accept / decline /
///   end are status changes on the row; the other side observes them live).
/// - **Media** = Agora ([AgoraCallService]); we only ever join the Agora
///   channel once a call is `answered`.
class CallController extends StateNotifier<CallState> {
  CallController(this._ref) : super(const CallState());

  final Ref _ref;

  final AgoraCallService agora = AgoraCallService();

  CallRepository get _calls => _ref.read(callRepositoryProvider);

  sb.RealtimeChannel? _callChannel;
  Timer? _ringTimeout;
  Timer? _durationTimer;

  String get _myId => sb.Supabase.instance.client.auth.currentUser!.id;

  /// Derives a stable positive 32-bit Agora uid from a user id, used when the
  /// backend hasn't assigned explicit `*_agora_uid` columns. Deterministic so
  /// the token (minted for this uid) and the join match.
  static int agoraUidFor(String userId) {
    // Simple stable hash → positive 31-bit int (Agora uids are uint32; keep it
    // well within range and non-zero).
    var h = 0;
    for (final code in userId.codeUnits) {
      h = 0x1fffffff & (h * 31 + code);
    }
    return h == 0 ? 1 : h;
  }

  // ---- Outgoing --------------------------------------------------------------

  /// Places a call to [partnerId] in [conversationId]. Creates the ringing row,
  /// moves to [CallPhase.outgoingRinging], and waits (via realtime) for the
  /// callee to answer/decline.
  Future<void> placeCall({
    required String conversationId,
    required String partnerId,
    required String partnerName,
    String? partnerPhotoUrl,
    required bool video,
  }) async {
    if (state.isActive) return; // one call at a time
    if (!AgoraConfig.isConfigured) {
      state = state.copyWith(
        phase: CallPhase.ended,
        endReason: CallEndReason.failed,
        errorMessage: 'Calling is not configured in this build.',
      );
      return;
    }

    final ok = await AgoraCallService.ensurePermissions(video: video);
    if (!ok) {
      state = state.copyWith(
        phase: CallPhase.ended,
        endReason: CallEndReason.failed,
        errorMessage: video
            ? 'Camera and microphone permission are required.'
            : 'Microphone permission is required.',
      );
      return;
    }

    state = CallState(
      phase: CallPhase.outgoingRinging,
      partnerId: partnerId,
      partnerName: partnerName,
      partnerPhotoUrl: partnerPhotoUrl,
      isVideo: video,
      amICaller: true,
    );

    try {
      final call = await _calls.startCall(
        conversationId: conversationId,
        receiverId: partnerId,
        callType: video ? CallType.video : CallType.audio,
      );
      state = state.copyWith(call: call);
      _listenToCall(call.id);
      _ringTimeout = Timer(_kRingTimeout, () => _onRingTimeout(call.id));
    } catch (e) {
      state = state.copyWith(
        phase: CallPhase.ended,
        endReason: CallEndReason.failed,
        errorMessage: 'Could not start the call. Try again.',
      );
    }
  }

  Future<void> _onRingTimeout(String callId) async {
    if (state.phase != CallPhase.outgoingRinging) return;
    try {
      await _calls.markMissed(callId);
    } catch (_) {}
    _end(CallEndReason.missed);
  }

  // ---- Incoming --------------------------------------------------------------

  /// Presents an incoming call (triggered by the global incoming-calls
  /// listener). Only shown if we're idle — a second incoming call while busy is
  /// dropped (the caller will time out to missed).
  void presentIncoming(
    CallLog call, {
    String? partnerName,
    String? partnerPhotoUrl,
  }) {
    if (state.isActive) return;
    state = CallState(
      phase: CallPhase.incomingRinging,
      call: call,
      partnerId: call.callerId,
      partnerName: partnerName,
      partnerPhotoUrl: partnerPhotoUrl,
      isVideo: call.callType == CallType.video,
      amICaller: false,
    );
    _listenToCall(call.id);
  }

  /// Callee accepts the incoming call.
  Future<void> acceptIncoming() async {
    final call = state.call;
    if (call == null || state.phase != CallPhase.incomingRinging) return;

    final ok = await AgoraCallService.ensurePermissions(video: state.isVideo);
    if (!ok) {
      await declineIncoming();
      return;
    }
    try {
      await _calls.answerCall(call.id);
    } catch (_) {}
    await _joinMedia(call);
  }

  /// Callee rejects the incoming call.
  Future<void> declineIncoming() async {
    final call = state.call;
    if (call != null) {
      try {
        await _calls.declineCall(call.id);
      } catch (_) {}
    }
    _end(CallEndReason.declined);
  }

  // ---- Media join (both sides, once answered) --------------------------------

  Future<void> _joinMedia(CallLog call) async {
    state = state.copyWith(phase: CallPhase.connecting);
    final channel = call.channelName ?? call.id; // fallback: the row id
    final uid = _agoraUidFor(call);

    try {
      final tokenRes = await _calls.getAgoraToken(
        channelName: channel,
        uid: uid,
        callType: call.callType,
      );
      await agora.join(
        channelName: channel,
        uid: uid,
        token: tokenRes.token,
        video: state.isVideo,
        onRemoteJoined: _onRemoteJoined,
        onRemoteLeft: _onRemoteLeftMedia,
        onError: (reason) => _onMediaError(reason),
      );
    } on AgoraTokenException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      await _hangUpAndClose(CallEndReason.failed);
    } catch (_) {
      state = state.copyWith(errorMessage: 'Could not connect the call.');
      await _hangUpAndClose(CallEndReason.failed);
    }
  }

  int _agoraUidFor(CallLog call) {
    final iAmCaller = call.amICaller(_myId);
    final explicit = iAmCaller ? call.callerAgoraUid : call.receiverAgoraUid;
    return explicit ?? agoraUidFor(_myId);
  }

  void _onRemoteJoined() {
    _ringTimeout?.cancel();
    if (state.phase == CallPhase.connecting ||
        state.phase == CallPhase.outgoingRinging) {
      state = state.copyWith(phase: CallPhase.connected);
      _startDurationTimer();
    }
  }

  void _onRemoteLeftMedia() {
    // The other side left the Agora channel (hung up). Treat as end.
    if (state.phase == CallPhase.connected ||
        state.phase == CallPhase.connecting) {
      _hangUpAndClose(CallEndReason.remoteLeft, alreadyEndedRemotely: true);
    }
  }

  void _onMediaError(String reason) {
    state = state.copyWith(errorMessage: reason);
  }

  // ---- Realtime: observe the row's status transitions ------------------------

  void _listenToCall(String callId) {
    _callChannel?.unsubscribe();
    _callChannel = _calls.subscribeToCall(callId, _onCallRowUpdated);
  }

  Future<void> _onCallRowUpdated(CallLog updated) async {
    // Keep our copy fresh.
    state = state.copyWith(call: updated);

    switch (updated.callStatus) {
      case CallStatus.answered:
        // Caller side: the callee accepted → join the media channel.
        if (state.amICaller && state.phase == CallPhase.outgoingRinging) {
          _ringTimeout?.cancel();
          await _joinMedia(updated);
        }
        break;
      case CallStatus.declined:
        _end(CallEndReason.declined);
        break;
      case CallStatus.cancelled:
        _end(CallEndReason.cancelled);
        break;
      case CallStatus.missed:
        _end(CallEndReason.missed);
        break;
      case CallStatus.ended:
        // The other side ended a connected call.
        if (updated.endedBy != _myId) {
          await _hangUpAndClose(
            CallEndReason.remoteLeft,
            alreadyEndedRemotely: true,
          );
        }
        break;
      case CallStatus.ringing:
        break;
    }
  }

  // ---- Duration timer --------------------------------------------------------

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(durationSeconds: state.durationSeconds + 1);
    });
  }

  // ---- Hang up / end ---------------------------------------------------------

  /// The local user pressed "end". Behaviour depends on phase:
  /// - ringing (caller): cancel the call.
  /// - connecting/connected: hang up, write duration.
  Future<void> hangUp() async {
    final call = state.call;
    switch (state.phase) {
      case CallPhase.outgoingRinging:
        if (call != null) {
          try {
            await _calls.cancelCall(call.id);
          } catch (_) {}
        }
        _end(CallEndReason.cancelled);
        break;
      case CallPhase.incomingRinging:
        await declineIncoming();
        break;
      case CallPhase.connecting:
      case CallPhase.connected:
        await _hangUpAndClose(CallEndReason.hangUp);
        break;
      case CallPhase.idle:
      case CallPhase.ended:
        break;
    }
  }

  Future<void> _hangUpAndClose(
    CallEndReason reason, {
    bool alreadyEndedRemotely = false,
  }) async {
    final call = state.call;
    final duration = state.durationSeconds;
    await agora.leave();
    if (call != null && !alreadyEndedRemotely) {
      try {
        await _calls.endCall(call.id, durationSeconds: duration);
      } catch (_) {}
    }
    _end(reason);
  }

  /// Terminal cleanup shared by every end path.
  void _end(CallEndReason reason) {
    _ringTimeout?.cancel();
    _durationTimer?.cancel();
    _callChannel?.unsubscribe();
    _callChannel = null;
    // Ensure media is down even on signaling-only ends (decline before join).
    unawaited(agora.leave());
    state = state.copyWith(phase: CallPhase.ended, endReason: reason);
  }

  /// Clears back to idle once the end-of-call UI has been shown & dismissed.
  void reset() {
    state = const CallState();
  }

  // ---- Media controls (thin pass-through to the Agora service) ---------------

  Future<void> toggleMic() => agora.toggleMic();
  Future<void> toggleCamera() => agora.toggleCamera();
  Future<void> switchCamera() => agora.switchCamera();
  Future<void> toggleSpeaker() => agora.toggleSpeaker();

  @override
  void dispose() {
    _ringTimeout?.cancel();
    _durationTimer?.cancel();
    _callChannel?.unsubscribe();
    agora.leave();
    agora.dispose();
    super.dispose();
  }
}

/// The single app-wide call controller.
final callControllerProvider = StateNotifierProvider<CallController, CallState>(
  (ref) {
    return CallController(ref);
  },
);
