import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_paths.dart';
import '../../core/theme/app_colors.dart';

/// 23 — NotFoundPage. 404 fallback for unknown routes.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('404',
                    style: theme.textTheme.displayLarge
                        ?.copyWith(color: AppColors.pink)),
                const SizedBox(height: 8),
                Text('Page not found', style: theme.textTheme.titleLarge),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go(RoutePaths.discover),
                  child: const Text('Return home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
