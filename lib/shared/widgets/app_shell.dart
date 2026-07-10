import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/route_paths.dart';
import '../data/repositories.dart';
import 'app_header.dart';
import 'bottom_nav.dart';
import 'info_modals.dart';

/// Scaffold shared by the 5 tab screens: the personalised gradient header +
/// body + bottom nav, capped at the mobile container width and centered on
/// wide viewports.
///
/// The bell now lives inside [AppHeader] itself and is present on every tab;
/// [headerActions] adds *extra* trailing actions before it (e.g. Discover's
/// filter button).
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.currentRoute,
    required this.onNavigate,
    this.title = AppConstants.appName,
    this.headerActions = const [],
  });

  final Widget child;
  final String currentRoute;
  final void Function(String route) onNavigate;

  /// Retained for API compatibility; the new header shows the user's name
  /// instead of a per-tab title.
  final String title;

  final List<Widget> headerActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppConstants.maxContainerWidth),
          child: Column(
            children: [
              AppHeader(
                actions: headerActions,
                onNotificationsTap: () =>
                    onNavigate(RoutePaths.notifications),
                onAccountPillTap: () => InfoModals.accountExpiry(context),
                onSubscriptionPillTap: () {
                  final until =
                      ref.read(currentUserProvider).valueOrNull?.premiumUntil;
                  if (until != null) {
                    InfoModals.subscriptionExpiry(context, expiresAt: until);
                  }
                },
              ),
              Expanded(child: child),
              BottomNav(currentRoute: currentRoute, onTap: onNavigate),
            ],
          ),
        ),
      ),
    );
  }
}
