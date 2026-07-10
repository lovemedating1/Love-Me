import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/auth/email_verified_screen.dart';
import '../../features/auth/reset_password_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/delete_account/delete_account_screen.dart';
import '../../features/devices/devices_screen.dart';
import '../../features/discover/discover_screen.dart';
import '../../features/explore/explore_screen.dart';
import '../../features/legal/legal_screen.dart';
import '../../features/likes/likes_screen.dart';
import '../../features/messages/messages_screen.dart';
import '../../features/misc/not_found_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/onboarding/profile_setup_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/safety/safety_reports_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/subscription/subscription_screen.dart';
import '../../shared/widgets/app_shell.dart';
import '../constants/route_paths.dart';
import 'router_guards.dart';

/// go_router configuration.
///
/// Phase 2: /auth, /email-verified, /reset-password, /profile-setup and the
/// Discover tab (/) are REAL screens; the guard enforces auth + profile-complete
/// using the mock session. Remaining screens are still PlaceholderScreen and get
/// built in Phases 3-4.
final routerProvider = Provider<GoRouter>((ref) {
  final guards = ref.watch(routerGuardsProvider);
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: RoutePaths.discover,
    debugLogDiagnostics: true,
    refreshListenable: refresh,
    redirect: guards.redirect,
    routes: [
      // ---- Public / auth flow ------------------------------------------
      GoRoute(path: RoutePaths.auth, builder: (_, _) => const AuthScreen()),
      GoRoute(
          path: RoutePaths.emailVerified,
          builder: (_, _) => const EmailVerifiedScreen()),
      GoRoute(
          path: RoutePaths.resetPassword,
          builder: (_, _) => const ResetPasswordScreen()),
      GoRoute(
          path: RoutePaths.profileSetup,
          builder: (_, _) => const ProfileSetupScreen()),

      // ---- Tabs (AppShell) ---------------------------------------------
      ShellRoute(
        builder: (context, state, child) {
          final loc = state.matchedLocation;
          return AppShell(
            currentRoute: loc,
            title: _titleFor(loc),
            onNavigate: (route) => context.go(route),
            headerActions: _headerActionsFor(context, loc),
            child: child,
          );
        },
        routes: [
          GoRoute(path: RoutePaths.discover, builder: (_, _) => const DiscoverScreen()),
          GoRoute(path: RoutePaths.likes, builder: (_, _) => const LikesScreen()),
          GoRoute(
              path: RoutePaths.messages,
              builder: (_, _) => const MessagesScreen()),
          GoRoute(
              path: RoutePaths.explore, builder: (_, _) => const ExploreScreen()),
          GoRoute(
              path: RoutePaths.profile, builder: (_, _) => const ProfileScreen()),
        ],
      ),

      // ---- Detail / secondary (full screen) ----------------------------
      GoRoute(
        path: RoutePaths.chat,
        builder: (_, state) =>
            ChatScreen(partnerId: state.pathParameters['id']!),
      ),
      GoRoute(
          path: RoutePaths.notifications,
          builder: (_, _) => const NotificationsScreen()),
      GoRoute(
          path: RoutePaths.settings,
          builder: (_, _) => const SettingsScreen()),
      GoRoute(
          path: RoutePaths.devices, builder: (_, _) => const DevicesScreen()),
      GoRoute(
          path: RoutePaths.subscription,
          builder: (_, _) => const SubscriptionScreen()),
      GoRoute(
          path: RoutePaths.safetyReports,
          builder: (_, _) => const SafetyReportsScreen()),
      GoRoute(
          path: RoutePaths.deleteAccount,
          builder: (_, _) => const DeleteAccountScreen()),

      // ---- Legal --------------------------------------------------------
      GoRoute(path: RoutePaths.privacy, builder: (_, _) => LegalScreen.privacy()),
      GoRoute(path: RoutePaths.terms, builder: (_, _) => LegalScreen.terms()),
      GoRoute(path: RoutePaths.refund, builder: (_, _) => LegalScreen.refund()),
      GoRoute(
          path: RoutePaths.childSafety,
          builder: (_, _) => LegalScreen.childSafety()),
    ],
    errorBuilder: (_, _) => const NotFoundScreen(),
  );
});

String _titleFor(String location) {
  switch (location) {
    case RoutePaths.likes:
      return 'Likes';
    case RoutePaths.messages:
      return 'Messages';
    case RoutePaths.explore:
      return 'Explore';
    case RoutePaths.profile:
      return 'Profile';
    default:
      return 'Love Me';
  }
}

/// Extra trailing header actions, shown *before* the bell (which AppHeader
/// now renders on every tab).
///
/// Phase 2: the old app has no header filter button on Discover — the
/// search-radius chip lives on the Discover body instead (see
/// `discover_screen.dart`'s `_aboveCard()`), so there are no extra actions
/// there anymore.
List<Widget> _headerActionsFor(BuildContext context, String loc) {
  return const [];
}

