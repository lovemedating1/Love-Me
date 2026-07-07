import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../../core/constants/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/match.dart';
import '../../shared/models/profile.dart';
import '../../shared/widgets/profile_tile.dart';
import '../../shared/widgets/state_views.dart';

/// 07 — LikesPage (tab body). Two tabs: Liked You (premium-gated blur) & Matches.
///
/// Subscribes to the `matches` table for the whole screen's lifetime so a
/// newly-created match (once the mutual-like trigger ships server-side —
/// see migration_002.md §1/§8) pops the "It's a Match!" overlay live.
class LikesScreen extends ConsumerStatefulWidget {
  const LikesScreen({super.key});

  @override
  ConsumerState<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends ConsumerState<LikesScreen> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _channel = ref.read(matchRepositoryProvider).subscribeToNewMatches((match) {
      ref.invalidate(matchesProvider);
      _showMatch(match);
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _showMatch(Match match) async {
    if (!mounted) return;
    final myId = ref.read(currentUserProvider).valueOrNull?.userId;
    final otherId = myId == null ? null : match.otherUserId(myId);
    final other =
        otherId == null ? null : await ref.read(profileByIdProvider(otherId).future);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.pink, Color(0xFFFF7AA8), AppColors.gold],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.heart, color: Colors.white, size: 56),
              const SizedBox(height: 12),
              const Text("It's a Match!",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                other == null
                    ? 'You have a new match.'
                    : 'You and ${other.name} liked each other.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.pink),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (otherId != null) context.push(RoutePaths.chatTo(otherId));
                },
                child: const Text('Send Message'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Keep Swiping',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(tabs: [Tab(text: 'Liked You'), Tab(text: 'Matches')]),
          Expanded(
            child: TabBarView(
              children: [
                _LikedYouTab(),
                _MatchesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LikedYouTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likes = ref.watch(likedYouProvider);
    final isPremium = ref.watch(isPremiumProvider);
    return likes.when(
      loading: () => const _GridSkeleton(),
      error: (_, _) => ErrorView(
          message: 'Could not load likes.',
          onRetry: () => ref.invalidate(likedYouProvider)),
      data: (people) {
        if (people.isEmpty) {
          return const EmptyView(
              icon: LucideIcons.heart,
              message: 'No likes yet — keep swiping!');
        }
        return Column(
          children: [
            if (!isPremium)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.crown, color: Color(0xFFFFB800)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('${people.length} people liked you',
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    FilledButton(
                      onPressed: () => context.push(RoutePaths.subscription),
                      child: const Text('Unlock'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _grid(people, blurred: !isPremium, onTap: (p) {
                if (!isPremium) {
                  context.push(RoutePaths.subscription);
                } else {
                  context.push(RoutePaths.chatTo(p.userId));
                }
              }),
            ),
          ],
        );
      },
    );
  }
}

class _MatchesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(matchesProvider);
    return matches.when(
      loading: () => const _GridSkeleton(),
      error: (_, _) => ErrorView(
          message: 'Could not load matches.',
          onRetry: () => ref.invalidate(matchesProvider)),
      data: (people) {
        if (people.isEmpty) {
          return const EmptyView(
              icon: LucideIcons.sparkles, message: 'No matches yet.');
        }
        return _grid(people,
            overlayIcon: LucideIcons.messageCircle,
            onTap: (p) => context.push(RoutePaths.chatTo(p.userId)));
      },
    );
  }
}

Widget _grid(List<Profile> people,
        {bool blurred = false,
        IconData? overlayIcon,
        required void Function(Profile) onTap}) =>
    GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: people.length,
      itemBuilder: (_, i) => ProfileTile(
        profile: people[i],
        blurred: blurred,
        overlayIcon: overlayIcon,
        onTap: () => onTap(people[i]),
      ),
    );

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();
  @override
  Widget build(BuildContext context) => GridView.count(
        padding: const EdgeInsets.all(12),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: List.generate(
            6, (_) => const SkeletonBox(height: double.infinity, radius: 16)),
      );
}
