import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/config/agora_config.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_avatar.dart';
import 'call_controller.dart';
import 'call_state.dart';

/// Full-screen call surface. One screen renders every phase (outgoing ring,
/// incoming ring, connecting, connected audio, connected video, ended) off the
/// single [callControllerProvider] state — so a call that transitions from
/// ringing → connected never rebuilds a different route.
///
/// Presented as a root-level overlay route (see call_overlay.dart), NOT a tab —
/// a call takes over the whole screen regardless of where the user was.
class CallScreen extends ConsumerWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(callControllerProvider);
    final controller = ref.read(callControllerProvider.notifier);

    // When a call ends, briefly show the end state then close.
    ref.listen(callControllerProvider.select((s) => s.phase), (prev, next) {
      if (next == CallPhase.ended) {
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (context.mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          controller.reset();
        });
      }
    });

    return PopScope(
      // Don't let a back gesture silently abandon a live call — the user must
      // use the on-screen end button (which writes duration / cancels).
      canPop: state.phase == CallPhase.ended || state.phase == CallPhase.idle,
      child: Scaffold(
        backgroundColor: const Color(0xFF10070C),
        body: SafeArea(
          child: _CallBody(state: state, controller: controller),
        ),
      ),
    );
  }
}

class _CallBody extends StatelessWidget {
  const _CallBody({required this.state, required this.controller});

  final CallState state;
  final CallController controller;

  @override
  Widget build(BuildContext context) {
    final showVideoStage =
        state.isVideo &&
        (state.phase == CallPhase.connected ||
            state.phase == CallPhase.connecting);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (showVideoStage)
          _VideoStage(controller: controller, state: state)
        else
          _AudioBackdrop(state: state),

        // Foreground: partner identity + status (hidden on connected video so
        // it doesn't cover the remote feed — a slim top bar is shown instead).
        if (!(showVideoStage && state.phase == CallPhase.connected))
          _Identity(state: state)
        else
          _VideoTopBar(state: state),

        // Bottom controls change per phase.
        Align(
          alignment: Alignment.bottomCenter,
          child: _Controls(state: state, controller: controller),
        ),
      ],
    );
  }
}

// ---- Audio / ringing backdrop ------------------------------------------------

class _AudioBackdrop extends StatelessWidget {
  const _AudioBackdrop({required this.state});
  final CallState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A0E24), Color(0xFF10070C)],
        ),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.state});
  final CallState state;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.35),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAvatar(photoUrl: state.partnerPhotoUrl, size: 128),
          const SizedBox(height: 20),
          Text(
            state.partnerName ?? 'Unknown',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _StatusLine(state: state),
        ],
      ),
    );
  }
}

class _VideoTopBar extends StatelessWidget {
  const _VideoTopBar({required this.state});
  final CallState state;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.partnerName ?? 'Unknown',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _fmt(state.durationSeconds),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});
  final CallState state;

  @override
  Widget build(BuildContext context) {
    final text = switch (state.phase) {
      CallPhase.outgoingRinging => 'Ringing…',
      CallPhase.incomingRinging =>
        state.isVideo ? 'Incoming video call' : 'Incoming voice call',
      CallPhase.connecting => 'Connecting…',
      CallPhase.connected => _fmt(state.durationSeconds),
      CallPhase.ended => _endText(state.endReason),
      CallPhase.idle => '',
    };
    return Column(
      children: [
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              state.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.gold, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }
}

// ---- Video stage -------------------------------------------------------------

class _VideoStage extends StatelessWidget {
  const _VideoStage({required this.controller, required this.state});
  final CallController controller;
  final CallState state;

  @override
  Widget build(BuildContext context) {
    final engine = controller.agora.engine;
    if (engine == null || !AgoraConfig.isConfigured) {
      return const _AudioBackdrop(state: CallState(isVideo: true));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // Remote (full screen) — shows placeholder until the peer joins.
        ValueListenableBuilder<int?>(
          valueListenable: controller.agora.remoteUid,
          builder: (_, remoteUid, _) {
            if (remoteUid == null) {
              return const _AudioBackdrop(state: CallState(isVideo: true));
            }
            return AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: engine,
                canvas: VideoCanvas(uid: remoteUid),
                connection: RtcConnection(
                  channelId: state.call?.channelName ?? state.call?.id,
                ),
              ),
            );
          },
        ),
        // Local preview — small, top-right.
        Positioned(
          top: 60,
          right: 16,
          width: 108,
          height: 160,
          child: ValueListenableBuilder<bool>(
            valueListenable: controller.agora.cameraOn,
            builder: (_, camOn, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: camOn
                    ? AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: engine,
                          canvas: const VideoCanvas(uid: 0),
                        ),
                      )
                    : Container(
                        color: Colors.black54,
                        child: const Icon(
                          LucideIcons.videoOff,
                          color: Colors.white54,
                        ),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---- Controls ----------------------------------------------------------------

class _Controls extends StatelessWidget {
  const _Controls({required this.state, required this.controller});
  final CallState state;
  final CallController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40, top: 16),
      child: switch (state.phase) {
        CallPhase.incomingRinging => _IncomingControls(controller: controller),
        CallPhase.connected || CallPhase.connecting => _InCallControls(
          state: state,
          controller: controller,
        ),
        CallPhase.outgoingRinging => _CircleButton(
          icon: LucideIcons.phoneOff,
          color: AppColors.destructive,
          onTap: controller.hangUp,
          label: 'Cancel',
        ),
        _ => const SizedBox(height: 80),
      },
    );
  }
}

class _IncomingControls extends StatelessWidget {
  const _IncomingControls({required this.controller});
  final CallController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CircleButton(
          icon: LucideIcons.phoneOff,
          color: AppColors.destructive,
          onTap: controller.declineIncoming,
          label: 'Decline',
        ),
        _CircleButton(
          icon: LucideIcons.phone,
          color: AppColors.online,
          onTap: controller.acceptIncoming,
          label: 'Accept',
        ),
      ],
    );
  }
}

class _InCallControls extends StatelessWidget {
  const _InCallControls({required this.state, required this.controller});
  final CallState state;
  final CallController controller;

  @override
  Widget build(BuildContext context) {
    final agora = controller.agora;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 22,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: agora.micMuted,
              builder: (_, muted, _) => _SmallToggle(
                icon: muted ? LucideIcons.micOff : LucideIcons.mic,
                active: !muted,
                label: muted ? 'Unmute' : 'Mute',
                onTap: controller.toggleMic,
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: agora.speakerOn,
              builder: (_, on, _) => _SmallToggle(
                icon: on ? LucideIcons.volume2 : LucideIcons.volume1,
                active: on,
                label: 'Speaker',
                onTap: controller.toggleSpeaker,
              ),
            ),
            if (state.isVideo) ...[
              ValueListenableBuilder<bool>(
                valueListenable: agora.cameraOn,
                builder: (_, on, _) => _SmallToggle(
                  icon: on ? LucideIcons.video : LucideIcons.videoOff,
                  active: on,
                  label: 'Camera',
                  onTap: controller.toggleCamera,
                ),
              ),
              _SmallToggle(
                icon: LucideIcons.switchCamera,
                active: true,
                label: 'Flip',
                onTap: controller.switchCamera,
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        _CircleButton(
          icon: LucideIcons.phoneOff,
          color: AppColors.destructive,
          onTap: controller.hangUp,
          label: 'End',
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 68,
              height: 68,
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }
}

class _SmallToggle extends StatelessWidget {
  const _SmallToggle({
    required this.icon,
    required this.active,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: active
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.9),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(
                icon,
                color: active ? Colors.white : const Color(0xFF10070C),
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }
}

// ---- helpers -----------------------------------------------------------------

String _fmt(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

String _endText(CallEndReason? reason) => switch (reason) {
  CallEndReason.declined => 'Call declined',
  CallEndReason.missed => 'No answer',
  CallEndReason.cancelled => 'Call cancelled',
  CallEndReason.failed => 'Call failed',
  CallEndReason.remoteLeft => 'Call ended',
  CallEndReason.hangUp => 'Call ended',
  null => 'Call ended',
};
