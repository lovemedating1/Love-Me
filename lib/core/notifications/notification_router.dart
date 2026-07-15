import 'package:go_router/go_router.dart';

import '../constants/route_paths.dart';
import '../../shared/models/app_notification.dart';

/// Where a notification of [type] should deep-link to. Shared by the
/// in-app notifications list (`notifications_screen.dart`) and the FCM
/// push-tap handler (`core/notifications/fcm_service.dart`) so the two
/// never drift apart.
///
/// `newMessage`/`newMatch`/call types carry a `conversation_id`, not a
/// partner user id — the chat route is keyed by partner id, so those go to
/// the Messages list rather than guessing at a conversion (migration_004.md).
String routeForNotificationType(NotificationType type) => switch (type) {
  NotificationType.newLike => RoutePaths.likes,
  NotificationType.newMatch ||
  NotificationType.newMessage ||
  NotificationType.callIncoming ||
  NotificationType.callMissed => RoutePaths.messages,
  NotificationType.profileView ||
  NotificationType.profileVerified => RoutePaths.profile,
  NotificationType.subscriptionExpiring ||
  NotificationType.subscriptionActive => RoutePaths.subscription,
  NotificationType.reportUpdate => RoutePaths.safetyReports,
  NotificationType.system => '',
};

/// Navigates to the deep link for [type] using [router], or no-ops for
/// [NotificationType.system].
void navigateForNotificationType(GoRouter router, NotificationType type) {
  final path = routeForNotificationType(type);
  if (path.isNotEmpty) router.push(path);
}
