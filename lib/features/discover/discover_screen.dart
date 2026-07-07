import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/profile.dart';
import '../../shared/widgets/state_views.dart';
import 'discover_providers.dart';

/// 06 — DiscoverPage (tab body). Card stack of nearby profiles with
/// like / pass / super-like / message actions. Mock data.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final List<String> _dismissed = [];

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.pink,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _pass(Profile p) async {
    setState(() => _dismissed.add(p.userId));
    try {
      await ref.read(swipeRepositoryProvider).passProfile(p.userId);
    } on AlreadySwipedException {
      // Already recorded — nothing else to do.
    } catch (_) {
      if (mounted) _toast('Could not save — try again.');
    }
  }

  Future<void> _like(Profile p) async {
    setState(() => _dismissed.add(p.userId));
    try {
      await ref.read(swipeRepositoryProvider).likeProfile(p.userId);
      if (mounted) _toast('You liked ${p.name}');
      // No "It's a Match!" here yet: matches are created by a mutual-like
      // trigger that hasn't shipped server-side (migration_002.md §1/§8).
      // The Likes screen's realtime subscription will surface it once it does.
    } on AlreadySwipedException {
      if (mounted) _toast('You already liked ${p.name}');
    } catch (_) {
      if (mounted) _toast('Could not save — try again.');
    }
  }

  Future<void> _superLike(Profile p) async {
    setState(() => _dismissed.add(p.userId));
    try {
      await ref.read(swipeRepositoryProvider).likeProfile(p.userId);
      if (mounted) _toast('Super liked ${p.name} ⭐');
    } on AlreadySwipedException {
      if (mounted) _toast('You already liked ${p.name}');
    } catch (_) {
      if (mounted) _toast('Could not save — try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(discoverFeedProvider);

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _dismissed.clear());
        ref.invalidate(discoverFeedProvider);
        await ref.read(discoverFeedProvider.future);
      },
      child: feed.when(
        loading: () => _loading(),
        error: (e, _) => ListView(children: [
          const SizedBox(height: 200),
          ErrorView(
            message: 'Could not load profiles.',
            onRetry: () => ref.invalidate(discoverFeedProvider),
          ),
        ]),
        data: (profiles) {
          final remaining =
              profiles.where((p) => !_dismissed.contains(p.userId)).toList();
          if (remaining.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 160),
              EmptyView(
                icon: LucideIcons.search,
                message: profiles.isEmpty
                    ? 'No matches near you — widen your filters.'
                    : "You've seen everyone nearby. Check back later!",
                actionLabel: 'Reset',
                onAction: () => setState(() => _dismissed.clear()),
              ),
            ]);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _card(remaining.first),
            ],
          );
        },
      ),
    );
  }

  Widget _loading() => ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SkeletonBox(height: 440, radius: 24),
          SizedBox(height: 16),
          SkeletonBox(height: 60, radius: 16),
        ],
      );

  Widget _card(Profile p) {
    final theme = Theme.of(context);
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (p.photoUrl != null)
                  CachedNetworkImage(
                    imageUrl: p.photoUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                        color: theme.colorScheme.surfaceContainerHighest),
                    errorWidget: (_, _, _) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(LucideIcons.user, size: 64)),
                  )
                else
                  Container(color: theme.colorScheme.surfaceContainerHighest),
                // gradient scrim
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                  ),
                ),
                if (p.distanceKm != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _chip('${p.distanceKm!.toStringAsFixed(0)} km',
                        LucideIcons.mapPin),
                  ),
                if (p.isVerified)
                  const Positioned(
                    top: 12,
                    right: 12,
                    child: Icon(LucideIcons.badgeCheck,
                        color: Colors.white, size: 26),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('${p.name}, ${p.ageLabel}',
                              style: theme.textTheme.headlineMedium
                                  ?.copyWith(color: Colors.white)),
                          const SizedBox(width: 8),
                          if (p.isOnline)
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                  color: AppColors.online,
                                  shape: BoxShape.circle),
                            ),
                        ],
                      ),
                      Text('${p.city}, ${p.country}',
                          style: const TextStyle(color: Colors.white70)),
                      if (p.bio != null) ...[
                        const SizedBox(height: 6),
                        Text(p.bio!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _actionBtn(LucideIcons.x, Colors.grey, () => _pass(p), 'Pass'),
            _actionBtn(LucideIcons.star, AppColors.gold, () => _superLike(p),
                'Super'),
            _actionBtn(LucideIcons.heart, AppColors.pink, () => _like(p),
                'Like', big: true),
            _actionBtn(LucideIcons.messageCircle, AppColors.purple,
                () => context.push(RoutePaths.chatTo(p.userId)), 'Message'),
          ],
        ),
      ],
    );
  }

  Widget _chip(String text, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      );

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap, String label,
      {bool big = false}) {
    final size = big ? 68.0 : 56.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          shape: CircleBorder(side: BorderSide(color: color, width: 2)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: color, size: big ? 32 : 26),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
