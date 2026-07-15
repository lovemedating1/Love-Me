import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/data/presence_repository.dart';
import '../../shared/data/repositories.dart' show presenceRepositoryProvider;

/// Drives `user_presence.is_online`/`last_seen` off the app's lifecycle —
/// there is no server-side heartbeat/staleness sweep yet (see
/// BACKEND_SCHEMA_VERIFICATION_QUESTIONS.md §4), so "online" is purely
/// whatever the client last wrote. A user who force-quits (rather than
/// backgrounding normally) may show as online until their next
/// foreground/background transition elsewhere — a known limitation, not a bug,
/// until a server-side staleness sweep exists.
///
/// Call [start] once after sign-in and [stop] on sign-out.
class PresenceService with WidgetsBindingObserver {
  PresenceService(this._repository);

  final PresenceRepository _repository;

  /// Re-asserts "online" periodically while the app is foregrounded, so a
  /// crash/kill without a clean "went to background" transition doesn't leave
  /// a stale `is_online: true` forever once *something* eventually checks
  /// `last_seen` server-side.
  static const _heartbeatInterval = Duration(minutes: 2);

  Timer? _heartbeat;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _setOnline(true);
    _heartbeat = Timer.periodic(_heartbeatInterval, (_) => _setOnline(true));
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
    _heartbeat = null;
    _setOnline(false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _setOnline(true);
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _setOnline(false);
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _setOnline(bool online) {
    // Fire-and-forget: presence is best-effort, never worth blocking or
    // surfacing an error toast for.
    unawaited(_repository.setOnline(online).catchError((_) {}));
  }
}

/// One [PresenceService] for the app's lifetime — [start]/[stop] are called
/// from AuthController around sign-in/sign-out rather than tied to widget
/// lifecycles, since presence should track the session, not any one screen.
final presenceServiceProvider = Provider<PresenceService>((ref) {
  final service = PresenceService(ref.read(presenceRepositoryProvider));
  ref.onDispose(service.stop);
  return service;
});
