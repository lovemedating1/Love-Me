import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../shared/models/app_notification.dart';
import '../router/navigator_key.dart';
import 'notification_router.dart';

/// Must match `android:name="com.google.firebase.messaging.default_notification_channel_id"`
/// in AndroidManifest.xml — this is how a `notification`-block FCM message
/// gets Android to treat it as HIGH importance (heads-up banner + sound)
/// even with the app backgrounded/killed, instead of falling back to
/// Android's auto-created default channel, whose importance isn't
/// guaranteed. See BACKEND_PUSH_BACKGROUND_BUG_INVESTIGATION.md — backend
/// confirmed the payload itself was never the issue; a missing explicit
/// channel is the other client-side candidate they flagged.
const _fcmChannelId = 'loveme_default_channel';

final _localNotifications = FlutterLocalNotificationsPlugin();

/// Must be a top-level (or static) function — the plugin runs it in a
/// separate background isolate with no access to app state, so it can only
/// do isolate-safe work. Registered once in `bootstrap.dart` before
/// `runApp()`. It doesn't touch the DB: the `notifications` row for a push
/// is written by backend logic (migration_004.md), not the client.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {}

/// Thin wrapper around `firebase_messaging` for push notifications.
///
/// Requests permission, obtains a device token, and persists it to the live
/// `fcm_tokens` table (unique on `(user_id, token)` as of 2026-07-13 — see
/// BACKEND_PUSH_FINAL_STEPS.md). Push delivery itself (a `send-fcm-push`
/// Edge Function triggered on `notifications` insert) is now live
/// server-side too — this class only covers the client's half: permission,
/// token capture/refresh, and reacting to a message once one arrives.
class FcmService {
  FcmService._();
  static final instance = FcmService._();

  final _messaging = FirebaseMessaging.instance;
  String? deviceToken;

  Future<void> init() async {
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    await _createNotificationChannel();

    deviceToken = await _messaging.getToken();
    if (deviceToken != null) await _registerToken(deviceToken!);
    _messaging.onTokenRefresh.listen((token) {
      deviceToken = token;
      _registerToken(token);
    });

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _onMessageOpenedApp(initialMessage);
  }

  /// Upserts the device token for the currently signed-in user. A no-op
  /// while signed out — call [registerTokenForCurrentUser] again right
  /// after sign-in/sign-up so a token obtained before login still gets saved.
  ///
  /// `onConflict` targets the `(user_id, token)` unique constraint (backend
  /// switched this 2026-07-13 from a `token`-alone constraint — see
  /// BACKEND_PUSH_FINAL_STEPS.md — closing the gap where a reused/reissued
  /// token could silently reassign an existing row to a different user).
  Future<void> _registerToken(String token) async {
    final userId = sb.Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await sb.Supabase.instance.client.from('fcm_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': defaultTargetPlatform.name,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,token');
    } catch (e) {
      if (kDebugMode) debugPrint('fcm_tokens upsert failed: $e');
    }
  }

  /// Call after sign-in/sign-up succeeds, in case the token was already
  /// obtained (e.g. app was opened signed-out first) before a user existed
  /// to attach it to.
  Future<void> registerTokenForCurrentUser() async {
    final token = deviceToken;
    if (token != null) await _registerToken(token);
  }

  /// Android auto-creates a default channel with unspecified importance if
  /// none is registered before the first message arrives — that's a
  /// plausible reason a `notification`-block message could fail to surface
  /// as a heads-up/tray notification while backgrounded or killed, even
  /// though the FCM payload itself is correct (backend ruled that out —
  /// see BACKEND_PUSH_BACKGROUND_BUG_INVESTIGATION.md). Explicitly creating
  /// a HIGH-importance channel here, and pointing FCM at it via the
  /// manifest's `default_notification_channel_id` meta-data, removes that
  /// variable so a re-test actually isolates the remaining candidates.
  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      _fcmChannelId,
      'Love Me Notifications',
      description: 'Likes, matches, messages, calls, and other activity.',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  void _onForegroundMessage(RemoteMessage message) {
    // FCM does not show a system banner for a foregrounded app on Android —
    // show one ourselves via the same channel, so a foreground push is at
    // least as visible as a backgrounded one. The in-app notifications list
    // is still the source of truth for content; this is just the banner.
    final notification = message.notification;
    if (notification == null) return;
    _localNotifications.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _fcmChannelId,
          'Love Me Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    final type = message.data['type'] as String?;
    if (type == null) return;
    final router = rootNavigatorKey.currentContext == null
        ? null
        : GoRouter.of(rootNavigatorKey.currentContext!);
    if (router == null) return;
    navigateForNotificationType(router, notificationTypeFromWireValue(type));
  }
}
