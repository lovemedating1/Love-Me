import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/profile.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/info_modals.dart';
import '../../shared/widgets/profile_preview_modal.dart';
import '../../shared/widgets/report_user_sheet.dart';
import '../../shared/widgets/state_views.dart';
import 'discover_filters_sheet.dart';
import 'discover_providers.dart';

/// 06 — DiscoverPage (tab body). Card stack of nearby profiles with
/// like / pass / super-like / message actions.
///
/// Rebuilt for UI parity (Phase 2, `WA0034`/`WA0050`) — see
/// UI_REBUILD_PLAN.md §2. Elements with no live data source yet (last-seen,
/// GPS accuracy, the `reports` table) are hidden rather than faked; see the
/// `// [Phase 2 data gap]` comments below.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final List<String> _dismissed = [];

  // Per-card photo carousel index, keyed by userId. Reset when a card leaves.
  final Map<String, int> _photoIndex = {};

  // Drag state for the swipe-to-pass/like gesture.
  Offset _dragOffset = Offset.zero;
  bool _dragging = false;

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.pink,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _pass(Profile p) async {
    setState(() {
      _dismissed.add(p.userId);
      _dragOffset = Offset.zero;
    });
    try {
      await ref.read(swipeRepositoryProvider).passProfile(p.userId);
    } on AlreadySwipedException {
      // Already recorded — nothing else to do.
    } catch (_) {
      if (mounted) _toast('Could not save — try again.');
    }
  }

  Future<void> _like(Profile p) async {
    setState(() {
      _dismissed.add(p.userId);
      _dragOffset = Offset.zero;
    });
    try {
      await ref.read(swipeRepositoryProvider).likeProfile(p.userId);
      if (mounted) _toast('You liked ${p.name}');
      ref.invalidate(remainingLikesTodayProvider);
      // If this like completes a mutual pair, the live trigger creates the
      // match + conversation server-side; we don't pop "It's a Match!" here —
      // the Likes screen holds the realtime `matches` subscription and shows
      // that dialog wherever the user is. Keeping it in one place avoids a
      // double popup.
    } on AlreadySwipedException {
      if (mounted) _toast('You already liked ${p.name}');
    } on DailyLikeCapExceededException {
      setState(() => _dismissed.remove(p.userId));
      if (mounted) _showLikeCapReached();
    } catch (_) {
      if (mounted) _toast('Could not save — try again.');
    }
  }

  Future<void> _superLike(Profile p) async {
    setState(() {
      _dismissed.add(p.userId);
      _dragOffset = Offset.zero;
    });
    try {
      await ref.read(swipeRepositoryProvider).likeProfile(p.userId);
      if (mounted) _toast('Super liked ${p.name} ⭐');
      ref.invalidate(remainingLikesTodayProvider);
    } on AlreadySwipedException {
      if (mounted) _toast('You already liked ${p.name}');
    } on DailyLikeCapExceededException {
      setState(() => _dismissed.remove(p.userId));
      if (mounted) _showLikeCapReached();
    } catch (_) {
      if (mounted) _toast('Could not save — try again.');
    }
  }

  /// Shown when the proposed `can_send_like` RPC rejects a like — see
  /// `BACKEND_ATIER_HANDOFF.md` §4. Not reachable until backend ships that
  /// RPC ([BE-10]); free-tier likes are unlimited client-side until then.
  void _showLikeCapReached() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily like limit reached'),
        content: const Text(
          'Free accounts get 50 likes every 24 hours. Upgrade to Premium '
          'for unlimited likes, or try again tomorrow.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(RoutePaths.subscription);
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  Future<void> _report(Profile p) async {
    await ReportUserSheet.show(
      context,
      reportedUserId: p.userId,
      reportedName: p.name,
    );
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
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: 200),
            ErrorView(
              message: 'Could not load profiles.',
              onRetry: () => ref.invalidate(discoverFeedProvider),
            ),
          ],
        ),
        data: (profiles) {
          final remaining = profiles
              .where((p) => !_dismissed.contains(p.userId))
              .toList();
          if (remaining.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _aboveCard(),
                const SizedBox(height: 160),
                EmptyView(
                  icon: LucideIcons.search,
                  message: profiles.isEmpty
                      ? 'No matches near you — widen your filters.'
                      : "You've seen everyone nearby. Check back later!",
                  actionLabel: 'Reset',
                  onAction: () => setState(() => _dismissed.clear()),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _aboveCard(),
              const SizedBox(height: 14),
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

  // ---- 2.1 Above the card ---------------------------------------------

  Widget _aboveCard() {
    final worldwide = ref.watch(worldwideSearchProvider);
    final radiusKm = ref.watch(searchRadiusKmProvider);
    final isPremium = ref.watch(isPremiumProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => DiscoverFiltersSheet.show(context),
              child: AppChip(
                label: worldwide ? 'Worldwide' : '$radiusKm km',
                emoji: '🌍',
                icon: LucideIcons.chevronDown,
                tone: AppChipTone.yellow,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => InfoModals.locationPermission(context),
              child: const Icon(
                LucideIcons.mapPin,
                size: 18,
                color: AppColors.mutedFg,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isPremium ? '1000+ profiles/month' : '50 profiles/month',
              style: const TextStyle(
                color: AppColors.mutedFg,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isPremium)
              const AppChip(
                label: 'Gold Plan',
                emoji: '👑',
                tone: AppChipTone.pink,
                dense: true,
              ),
          ],
        ),
        // [Phase 2 data gap] "stale location" needs a real geolocator-backed
        // last-fix timestamp; we don't have live location tracking yet, so
        // this banner is intentionally omitted rather than shown with a
        // fabricated age. Re-add once location is wired for real.
      ],
    );
  }

  // ---- 2.2 The profile card ---------------------------------------------

  Widget _card(Profile p) {
    final theme = Theme.of(context);
    final photosAsync = ref.watch(cardPhotosProvider(p.userId));
    final photos = photosAsync.valueOrNull ?? const [];
    final photoUrls = photos.isNotEmpty
        ? photos.map((ph) => ph.photoUrl).toList()
        : (p.photoUrl != null ? [p.photoUrl!] : <String>[]);
    final activeIndex = (_photoIndex[p.userId] ?? 0).clamp(
      0,
      photoUrls.isEmpty ? 0 : photoUrls.length - 1,
    );

    void advancePhoto() {
      if (photoUrls.length < 2) return;
      setState(
        () => _photoIndex[p.userId] = (activeIndex + 1) % photoUrls.length,
      );
    }

    void selectPhoto(int i) => setState(() => _photoIndex[p.userId] = i);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onPanStart: (_) => setState(() => _dragging = true),
          onPanUpdate: (d) => setState(() => _dragOffset += d.delta),
          onPanEnd: (_) {
            const threshold = 110.0;
            if (_dragOffset.dx > threshold) {
              _like(p);
            } else if (_dragOffset.dx < -threshold) {
              _pass(p);
            } else {
              setState(() {
                _dragging = false;
                _dragOffset = Offset.zero;
              });
            }
          },
          child: AnimatedContainer(
            duration: _dragging
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dragOffset.dx, 0, 0)
              ..rotateZ(_dragOffset.dx / 900),
            transformAlignment: Alignment.center,
            child: AspectRatio(
              // Taller than a plain 3:4 photo card — the action row now lives
              // inside the card's bottom (matching the old app), so the card
              // needs the extra height to fit it without cramping the photo.
              aspectRatio: 0.62,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (photoUrls.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: photoUrls[activeIndex],
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(LucideIcons.user, size: 64),
                        ),
                      )
                    else
                      Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(LucideIcons.user, size: 64),
                      ),
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
                    // Segmented progress bars (only when there's more than 1 photo).
                    if (photoUrls.length > 1)
                      Positioned(
                        top: 10,
                        left: 10,
                        right: 10,
                        child: Row(
                          children: [
                            for (var i = 0; i < photoUrls.length; i++)
                              Expanded(
                                child: Container(
                                  margin: EdgeInsets.only(
                                    right: i == photoUrls.length - 1 ? 0 : 4,
                                  ),
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: i <= activeIndex
                                        ? Colors.white
                                        : Colors.white30,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    // Top-left: marital status + report pills.
                    Positioned(
                      top: 22,
                      left: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (p.maritalStatus != null)
                            AppChip(
                              label: 'Marital Status: ${p.maritalStatus}',
                              emoji: '💫',
                              tone: AppChipTone.dark,
                              dense: true,
                            ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => _report(p),
                            child: const AppChip(
                              label: 'Report',
                              icon: LucideIcons.shieldAlert,
                              tone: AppChipTone.dark,
                              dense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Top-right: verified badge + last-active pill (if known).
                    Positioned(
                      top: 22,
                      right: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (p.isVerified)
                            const Icon(
                              LucideIcons.badgeCheck,
                              color: Colors.white,
                              size: 26,
                            ),
                          // [Phase 2 data gap] "last active" needs
                          // `user_presence.last_seen`, which nothing reads yet —
                          // hidden until that's wired.
                        ],
                      ),
                    ),
                    // Single "next photo" arrow, centered on the right edge —
                    // the numbered thumbnails live OUTSIDE the card (see the
                    // outer Stack sibling below), matching the old app.
                    if (photoUrls.length > 1)
                      Positioned(
                        right: 10,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: advancePhoto,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black45,
                              ),
                              child: const Icon(
                                LucideIcons.chevronRight,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
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
                              Flexible(
                                child: Text(
                                  '${p.name}, ${p.ageLabel}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (p.isOnline)
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: AppColors.online,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${p.city}, ${p.country}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          if (p.relationshipGoal != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Need a ${p.relationshipGoal} 💍',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (p.distanceKm != null)
                                AppChip(
                                  label:
                                      '${p.distanceKm!.toStringAsFixed(0)} km (${(p.distanceKm! * 0.621371).toStringAsFixed(0)} mi) away',
                                  icon: LucideIcons.mapPin,
                                  tone: AppChipTone.pink,
                                  dense: true,
                                ),
                              if (p.orientation != null)
                                AppChip(
                                  label: p.orientation!,
                                  emoji: '✨',
                                  tone: AppChipTone.yellow,
                                  dense: true,
                                ),
                              if (p.interestedIn != null)
                                AppChip(
                                  label: 'Likes ${p.interestedIn}',
                                  icon: LucideIcons.eye,
                                  tone: AppChipTone.pink,
                                  dense: true,
                                ),
                              for (final hobby in p.hobbies.take(3))
                                AppChip(
                                  label: hobby,
                                  tone: AppChipTone.grey,
                                  dense: true,
                                ),
                            ],
                          ),
                          if (p.hobbies.length > 3 ||
                              (p.bio ?? '').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => ProfilePreviewModal.show(context, p),
                              child: const AppChip(
                                label: 'Show more',
                                icon: LucideIcons.chevronDown,
                                tone: AppChipTone.yellow,
                                dense: true,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          _actionRow(p),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Numbered photo thumbnails, floating OUTSIDE the card's right edge
        // (matches the old app: they sit over the pink page background, not
        // inside the black card).
        if (photoUrls.length > 1)
          Positioned(
            right: -8,
            top: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < photoUrls.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: GestureDetector(
                      onTap: () => selectPhoto(i),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: i == activeIndex
                                    ? AppColors.pink
                                    : Colors.white,
                                width: i == activeIndex ? 2.5 : 1.5,
                              ),
                              image: DecorationImage(
                                image: CachedNetworkImageProvider(photoUrls[i]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '${i + 1}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // ---- 2.3 Action buttons -------------------------------------------------

  Widget _actionRow(Profile p) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _actionBtn(
        LucideIcons.x,
        Colors.white,
        Colors.black87,
        () => _pass(p),
        'Pass',
      ),
      _actionBtn(
        LucideIcons.star,
        AppColors.gold,
        Colors.white,
        () => _superLike(p),
        'Super',
      ),
      _actionBtn(
        LucideIcons.messageCircle,
        AppColors.success,
        Colors.white,
        () => context.push(RoutePaths.chatTo(p.userId)),
        'Message',
      ),
      _actionBtn(
        LucideIcons.heart,
        AppColors.pink,
        Colors.white,
        () => _like(p),
        'Like',
        big: true,
      ),
    ],
  );

  Widget _actionBtn(
    IconData icon,
    Color bg,
    Color fg,
    VoidCallback onTap,
    String label, {
    bool big = false,
  }) {
    final size = big ? 68.0 : 56.0;
    return Material(
      color: bg,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: fg, size: big ? 32 : 26),
        ),
      ),
    );
  }
}
