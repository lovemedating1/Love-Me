import 'package:flutter/widgets.dart';

/// App-wide navigator key so code with no [BuildContext] — namely the FCM
/// background/terminated message-tap handlers in
/// `core/notifications/fcm_service.dart`, which run before any widget tree
/// exists — can still resolve the [GoRouter] and navigate.
final rootNavigatorKey = GlobalKey<NavigatorState>();
