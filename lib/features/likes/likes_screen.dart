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
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/profile_preview_modal.dart';
import '../../shared/widgets/state_views.dart';

/// 07 — LikesPage (tab body). "People Who Like You" — a vertical list.
///
/// Rebuilt for UI parity (Phase 3, `WA0035`) — see UI_REBUILD_PLAN.md §3.3.
/// Per Phase 0 §0.4 (#1/#2), the old app has **no Matches tab and no blurred
/// premium grid** here, so both are removed: this is now a single list with
/// a plan banner. New matches still surface live via the realtime
/// subscription below — they just pop the "It's a Match!" dialog and drop
/// the user into chat instead of a separate tab.
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
      ref.invalidate(likedYouProvider);
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
    final other = otherId == null
        ? null
        : await ref.read(profileByIdProvider(otherId).future);
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
              const Text(
                "It's a Match!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
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
                  foregroundColor: AppColors.pink,
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (otherId != null) context.push(RoutePaths.chatTo(otherId));
                },
                child: const Text('Send Message'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Keep Swiping',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final likes = ref.watch(likedYouProvider);
    final isPremium = ref.watch(isPremiumProvider);
    return likes.when(
      loading: () => _listSkeleton(),
      error: (_, _) => ErrorView(
        message: 'Could not load likes.',
        onRetry: () => ref.invalidate(likedYouProvider),
      ),
      data: (people) => _content(context, people, isPremium),
    );
  }

  Widget _content(BuildContext context, List<Profile> people, bool isPremium) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'People Who Like You',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Viewing all ${people.length} likes',
          style: const TextStyle(color: AppColors.mutedFg),
        ),
        const SizedBox(height: 14),
        if (isPremium)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppColors.pink,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.crown, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Gold Plan',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        if (people.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: EmptyView(
              icon: LucideIcons.heart,
              message: 'No likes yet — keep swiping!',
            ),
          )
        else
          for (final p in people) _likeRow(context, p),
      ],
    );
  }

  Widget _likeRow(BuildContext context, Profile p) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => ProfilePreviewModal.show(context, p),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              AppAvatar(
                photoUrl: p.photoUrl,
                size: 52,
                isVerified: p.isVerified,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.city}, ${p.country}',
                      style: const TextStyle(
                        color: AppColors.mutedFg,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                p.ageLabel,
                style: const TextStyle(
                  color: AppColors.mutedFg,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AppColors.mutedFg,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _listSkeleton() => ListView(
    padding: const EdgeInsets.all(16),
    children: List.generate(
      6,
      (_) => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: SkeletonBox(height: 74, radius: 16),
      ),
    ),
  );
}
