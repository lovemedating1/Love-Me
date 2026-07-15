import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/data/repositories.dart';

/// Registers this device as an `active_sessions` row right after sign-in/
/// sign-up/session-restore, and exposes the resulting session token via
/// [currentSessionTokenProvider] so the Devices screen can mark "this device".
///
/// **No single-device enforcement runs server-side yet** (see
/// BACKEND_REMAINING.md [BE-1]) — registering a session here does not revoke
/// anyone else's. This only makes the Devices screen show real data instead
/// of `MockData.devices`.
class DeviceSessionRegistrar {
  DeviceSessionRegistrar(this._ref);

  final Ref _ref;

  /// Same device label for the lifetime of the process — re-registering on
  /// every sign-in (e.g. sign-out then sign-back-in) creates a fresh row
  /// rather than reusing a stale token from a previous session.
  String get _deviceLabel {
    if (kIsWeb) return 'Web browser';
    try {
      return switch (Platform.operatingSystem) {
        'android' => 'Android device',
        'ios' => 'iPhone/iPad',
        'macos' => 'Mac',
        'windows' => 'Windows PC',
        'linux' => 'Linux',
        _ => Platform.operatingSystem,
      };
    } catch (_) {
      return 'Unknown device';
    }
  }

  String get _userAgent {
    if (kIsWeb) return 'web';
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return '';
    }
  }

  /// Call once after a session becomes available (sign-in/sign-up success,
  /// or a restored session on cold start). Safe to call repeatedly — each
  /// call registers a new session row; only call it once per actual sign-in.
  Future<void> registerForCurrentUser() async {
    try {
      final token = await _ref
          .read(deviceSessionRepositoryProvider)
          .registerSession(deviceLabel: _deviceLabel, userAgent: _userAgent);
      _ref.read(currentSessionTokenProvider.notifier).state = token;
    } catch (e) {
      if (kDebugMode) debugPrint('active_sessions registration failed: $e');
    }
  }

  /// Clears the locally-tracked session token on sign-out. The row itself is
  /// intentionally left in `active_sessions` — it's a history of this
  /// device's past sessions, matching what "Signed in Nd ago" needs; explicit
  /// revoke (delete) is a separate user action from the Devices screen.
  void clearOnSignOut() {
    _ref.read(currentSessionTokenProvider.notifier).state = null;
  }
}

final deviceSessionRegistrarProvider = Provider(
  (ref) => DeviceSessionRegistrar(ref),
);
