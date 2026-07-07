import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../shared/data/mock_data.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/profile.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/state_views.dart';
import '../auth/auth_controller.dart';

/// 10 — ProfilePage (tab body). Own profile summary + entry to settings,
/// subscription, safety, sign out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final isPremium = ref.watch(isPremiumProvider);
    return me.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorView(
          message: 'Could not load your profile.',
          onRetry: () => ref.invalidate(currentUserProvider)),
      data: (p) => _content(context, ref, p, isPremium),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, Profile p, bool isPremium) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        _banner(context, p, isPremium),
        const SizedBox(height: 12),
        _statsRow(theme),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: () => _editSheet(context, p),
            icon: const Icon(LucideIcons.pencil),
            label: const Text('Edit Profile'),
          ),
        ),
        if (!isPremium)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _upgradeCard(context),
          ),
        const SizedBox(height: 8),
        if (p.bio != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(p.bio!, style: theme.textTheme.bodyMedium),
          ),
        if (p.gallery.isNotEmpty) _gallery(p),
        const Divider(height: 24),
        // Demo toggle so the free/premium gates are testable without a backend.
        SwitchListTile(
          secondary: const Icon(LucideIcons.crown, color: AppColors.gold),
          title: const Text('Premium (demo toggle)'),
          subtitle: const Text('Mock — flips free/premium gates'),
          value: isPremium,
          onChanged: (v) => ref.read(isPremiumProvider.notifier).state = v,
        ),
        _row(context, LucideIcons.settings, 'Settings', RoutePaths.settings),
        _row(context, LucideIcons.bell, 'Notifications', RoutePaths.notifications),
        _row(context, LucideIcons.monitor, 'Devices', RoutePaths.devices),
        _row(context, LucideIcons.shield, 'Safety Reports', RoutePaths.safetyReports),
        _row(context, LucideIcons.crown, 'Manage Subscription', RoutePaths.subscription),
        const Divider(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.destructive),
            icon: const Icon(LucideIcons.logOut),
            label: const Text('Log out'),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => context.push(RoutePaths.deleteAccount),
            child: const Text('Delete account',
                style: TextStyle(color: AppColors.destructive)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _banner(BuildContext context, Profile p, bool isPremium) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.header),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Row(
        children: [
          Stack(
            children: [
              AppAvatar(photoUrl: p.photoUrl, size: 84, isVerified: p.isVerified),
              Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white,
                  child: Icon(LucideIcons.camera, size: 14, color: AppColors.pink),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text('${p.name}, ${p.ageLabel}',
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(color: Colors.white)),
                    ),
                    if (isPremium) ...[
                      const SizedBox(width: 8),
                      const Icon(LucideIcons.crown, color: AppColors.gold),
                    ],
                  ],
                ),
                Text('${p.city}, ${p.country}',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(ThemeData theme) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _stat(theme, 'Views', MockData.viewsCount),
            _stat(theme, 'Likes', MockData.likesCount),
            _stat(theme, 'Matches', MockData.matchesCount),
          ],
        ),
      );

  Widget _stat(ThemeData theme, String label, int value) => Expanded(
        child: Column(
          children: [
            Text('$value', style: theme.textTheme.titleLarge),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      );

  Widget _upgradeCard(BuildContext context) => GestureDetector(
        onTap: () => context.push(RoutePaths.subscription),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              gradient: AppGradients.premium,
              borderRadius: BorderRadius.circular(16)),
          child: const Row(
            children: [
              Icon(LucideIcons.crown, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text('Upgrade to Premium',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              Icon(LucideIcons.chevronRight, color: Colors.white),
            ],
          ),
        ),
      );

  Widget _gallery(Profile p) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final _ in p.gallery)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(color: const Color(0x22E6287A)),
              ),
          ],
        ),
      );

  Widget _row(BuildContext context, IconData icon, String label, String route) =>
      ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(LucideIcons.chevronRight, size: 18),
        onTap: () => context.push(route),
      );

  void _editSheet(BuildContext context, Profile p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit Profile', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: TextEditingController(text: p.name),
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: p.bio),
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
