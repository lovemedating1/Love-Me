import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/route_paths.dart';
import 'app_header.dart';
import 'bottom_nav.dart';

/// Scaffold shared by the 5 tab screens: gradient header + body + bottom nav,
/// capped at the mobile container width and centered on wide viewports.
class AppShell extends StatelessWidget {
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
  final String title;
  final List<Widget> headerActions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppConstants.maxContainerWidth),
          child: Column(
            children: [
              AppHeader(
                title: title,
                actions: headerActions.isNotEmpty
                    ? headerActions
                    : [
                        HeaderAction(
                          icon: LucideIcons.bell,
                          tooltip: 'Notifications',
                          onTap: () => onNavigate(RoutePaths.notifications),
                        ),
                      ],
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
