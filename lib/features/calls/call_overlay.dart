import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/router/navigator_key.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/call_log.dart';
import 'call_controller.dart';
import 'call_screen.dart';

/// App-wide glue that (1) subscribes to incoming calls for the signed-in user
/// and (2) pushes the full-screen [CallScreen] whenever a call becomes active
/// (incoming ring OR an outgoing call this device placed).
///
/// Mounted once, above the router (via MaterialApp.router's `builder`), so a
/// call surfaces no matter which tab/screen the user is on. Media/signaling
/// live in [CallController]; this widget is purely presentation glue.
class CallOverlay extends ConsumerStatefulWidget {
  const CallOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends ConsumerState<CallOverlay> {
  sb.RealtimeChannel? _incomingChannel;
  StreamSubscription<sb.AuthState>? _authSub;
  bool _callRouteOpen = false;

  @override
  void initState() {
    super.initState();
    // (Re)subscribe to incoming calls whenever auth state settles on a user.
    _authSub = sb.Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _resubscribeIncoming();
    });
    _resubscribeIncoming();
  }

  void _resubscribeIncoming() {
    final user = sb.Supabase.instance.client.auth.currentUser;
    _incomingChannel?.unsubscribe();
    _incomingChannel = null;
    if (user == null) return;
    _incomingChannel = ref
        .read(callRepositoryProvider)
        .subscribeToIncomingCalls(_onIncomingCall);
  }

  Future<void> _onIncomingCall(CallLog call) async {
    final controller = ref.read(callControllerProvider.notifier);
    if (ref.read(callControllerProvider).isActive) return; // already busy

    // Resolve the caller's name/photo for the ringing screen.
    String? name;
    String? photo;
    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .byId(call.callerId);
      name = profile?.name;
      photo = profile?.photoUrl;
    } catch (_) {
      // Non-fatal — ring without the name/photo.
    }
    controller.presentIncoming(call, partnerName: name, partnerPhotoUrl: photo);
  }

  @override
  void dispose() {
    _incomingChannel?.unsubscribe();
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Push/pop the call route in reaction to the call becoming active/idle.
    ref.listen(callControllerProvider.select((s) => s.isActive), (_, active) {
      if (active && !_callRouteOpen) {
        _callRouteOpen = true;
        rootNavigatorKey.currentState
            ?.push(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => const CallScreen(),
              ),
            )
            .whenComplete(() => _callRouteOpen = false);
      }
    });

    return widget.child;
  }
}
