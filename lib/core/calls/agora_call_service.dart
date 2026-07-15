import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/agora_config.dart';

/// Low-level wrapper around the Agora RTC engine.
///
/// Owns exactly one [RtcEngine] instance for the lifetime of a single call:
/// [join] creates + configures the engine and joins the channel; [leave]
/// tears it all down. The higher-level call state machine (CallController)
/// drives this — this class knows nothing about `call_logs`, ringing, or the
/// UI; it only moves audio/video bits.
///
/// Media transport is Agora; **signaling** (who is calling whom, ring/accept/
/// decline) is handled entirely by Supabase `call_logs` + Realtime elsewhere.
class AgoraCallService {
  RtcEngine? _engine;

  /// The remote participant's Agora uid once they've joined the channel, or
  /// null while we're still alone in it.
  final ValueNotifier<int?> remoteUid = ValueNotifier<int?>(null);

  /// True once we have successfully joined the channel.
  final ValueNotifier<bool> joined = ValueNotifier<bool>(false);

  /// Local mic muted state.
  final ValueNotifier<bool> micMuted = ValueNotifier<bool>(false);

  /// Local camera enabled state (video calls only).
  final ValueNotifier<bool> cameraOn = ValueNotifier<bool>(true);

  /// Speakerphone routing (audio calls default to earpiece, video to speaker).
  final ValueNotifier<bool> speakerOn = ValueNotifier<bool>(false);

  RtcEngine? get engine => _engine;
  bool get isVideo => _isVideo;
  bool _isVideo = false;

  /// Requests mic (and camera, for video) runtime permissions. Returns true
  /// only if every required permission was granted.
  static Future<bool> ensurePermissions({required bool video}) async {
    final needed = <Permission>[
      Permission.microphone,
      if (video) Permission.camera,
    ];
    final statuses = await needed.request();
    return statuses.values.every((s) => s.isGranted);
  }

  /// Creates the engine, joins [channelName] as [uid] with [token], and starts
  /// audio (and video, if [video]). Safe to call once per call.
  Future<void> join({
    required String channelName,
    required int uid,
    required String? token,
    required bool video,
    void Function()? onRemoteJoined,
    void Function()? onRemoteLeft,
    void Function(String reason)? onError,
  }) async {
    assert(AgoraConfig.isConfigured, 'AGORA_APP_ID not set');
    _isVideo = video;

    final engine = createAgoraRtcEngine();
    _engine = engine;
    await engine.initialize(RtcEngineContext(appId: AgoraConfig.appId));

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          joined.value = true;
        },
        onUserJoined: (connection, remote, elapsed) {
          remoteUid.value = remote;
          onRemoteJoined?.call();
        },
        onUserOffline: (connection, remote, reason) {
          if (remoteUid.value == remote) remoteUid.value = null;
          onRemoteLeft?.call();
        },
        onError: (err, msg) {
          onError?.call('${err.name}: $msg');
        },
      ),
    );

    await engine.enableAudio();
    if (video) {
      await engine.enableVideo();
      await engine.startPreview();
      cameraOn.value = true;
    } else {
      await engine.disableVideo();
    }

    // Audio calls stay on the earpiece; video defaults to speaker.
    speakerOn.value = video;
    await engine.setEnableSpeakerphone(video);

    await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await engine.joinChannel(
      token: token ?? '',
      channelId: channelName,
      uid: uid,
      options: ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        publishMicrophoneTrack: true,
        publishCameraTrack: video,
        autoSubscribeAudio: true,
        autoSubscribeVideo: video,
      ),
    );
  }

  Future<void> toggleMic() async {
    final next = !micMuted.value;
    await _engine?.muteLocalAudioStream(next);
    micMuted.value = next;
  }

  Future<void> toggleCamera() async {
    if (!_isVideo) return;
    final next = !cameraOn.value;
    await _engine?.muteLocalVideoStream(!next);
    await _engine?.enableLocalVideo(next);
    cameraOn.value = next;
  }

  Future<void> switchCamera() async {
    if (!_isVideo) return;
    await _engine?.switchCamera();
  }

  Future<void> toggleSpeaker() async {
    final next = !speakerOn.value;
    await _engine?.setEnableSpeakerphone(next);
    speakerOn.value = next;
  }

  /// Leaves the channel and releases the engine. Idempotent.
  Future<void> leave() async {
    final engine = _engine;
    _engine = null;
    joined.value = false;
    remoteUid.value = null;
    if (engine == null) return;
    try {
      if (_isVideo) await engine.stopPreview();
      await engine.leaveChannel();
    } catch (_) {
      // Best-effort teardown.
    } finally {
      await engine.release();
    }
  }

  void dispose() {
    remoteUid.dispose();
    joined.dispose();
    micMuted.dispose();
    cameraOn.dispose();
    speakerOn.dispose();
  }
}
