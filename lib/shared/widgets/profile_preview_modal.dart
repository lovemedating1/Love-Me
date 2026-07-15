import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../features/discover/discover_providers.dart'
    show cardPhotosProvider;
import '../data/repositories.dart';
import '../models/profile.dart';
import 'app_chip.dart';
import 'gradient_button.dart';
import 'report_user_sheet.dart';

/// Shared full profile-detail view (old app: `8`/`WA0035`) — used by Discover's
/// "Show more", the Likes list, and the Explore country-user list. Shows every
/// available photo in [profile]'s gallery (`profile_photos`, same source
/// Discover's card carousel uses) plus every profile field, not just a
/// summary card.
///
/// Opening this records a `profile_views` row for [profile] (best-effort,
/// silent) — this is the one place in the app a user actually looks at
/// someone else's full profile, so it's the natural point to log a "view"
/// for the (not yet enforced) monthly view quota. See `ProfileViewRepository`.
class ProfilePreviewModal extends ConsumerStatefulWidget {
  const ProfilePreviewModal({
    super.key,
    required this.profile,
    this.scrollController,
  });

  final Profile profile;

  /// Handed down from the enclosing [DraggableScrollableSheet] (see [show])
  /// so this widget's inner [ListView] stays in sync with the sheet's
  /// drag-to-resize/dismiss gesture.
  final ScrollController? scrollController;

  static Future<void> show(BuildContext context, Profile profile) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => ProfilePreviewModal(
            profile: profile,
            scrollController: scrollController,
          ),
        ),
      );

  @override
  ConsumerState<ProfilePreviewModal> createState() =>
      _ProfilePreviewModalState();
}

class _ProfilePreviewModalState extends ConsumerState<ProfilePreviewModal> {
  int _photoIndex = 0;

  @override
  void initState() {
    super.initState();
    ref.read(profileViewRepositoryProvider).recordView(widget.profile.userId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.profile;
    final photosAsync = ref.watch(cardPhotosProvider(p.userId));
    final photos = photosAsync.valueOrNull ?? const [];
    final photoUrls = photos.isNotEmpty
        ? photos.map((ph) => ph.photoUrl).toList()
        : (p.photoUrl != null ? [p.photoUrl!] : <String>[]);
    final activeIndex = photoUrls.isEmpty
        ? 0
        : _photoIndex.clamp(0, photoUrls.length - 1);

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        _gallery(theme, photoUrls, activeIndex),
        const SizedBox(height: 16),
        Row(
          children: [
            Flexible(
              child: Text(
                '${p.name}, ${p.ageLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (p.isVerified) ...[
              const SizedBox(width: 6),
              const Icon(
                LucideIcons.badgeCheck,
                color: AppColors.pink,
                size: 20,
              ),
            ],
            const Spacer(),
            IconButton(
              tooltip: 'Report',
              icon: const Icon(
                LucideIcons.shieldAlert,
                color: AppColors.mutedFg,
              ),
              onPressed: () => ReportUserSheet.show(
                context,
                reportedUserId: p.userId,
                reportedName: p.name,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '📍 ${p.city}, ${p.country}',
          style: const TextStyle(color: AppColors.mutedFg),
        ),
        if (p.relationshipGoal != null) ...[
          const SizedBox(height: 8),
          Text(
            '♥ Need a ${p.relationshipGoal}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
        if ((p.occupation ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '💼 ${p.occupation}',
            style: const TextStyle(color: AppColors.mutedFg),
          ),
        ],
        if ((p.bio ?? '').isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(p.bio!, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (p.maritalStatus != null)
              AppChip(
                label: p.maritalStatus!,
                emoji: '💫',
                tone: AppChipTone.grey,
                dense: true,
              ),
            if (p.orientation != null)
              AppChip(
                label: p.orientation!,
                emoji: '✨',
                tone: AppChipTone.grey,
                dense: true,
              ),
            if (p.interestedIn != null)
              AppChip(
                label: 'Likes ${p.interestedIn}',
                tone: AppChipTone.grey,
                dense: true,
              ),
          ],
        ),
        if (p.interests.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Interests',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final interest in p.interests)
                AppChip(label: interest, tone: AppChipTone.pink, dense: true),
            ],
          ),
        ],
        if (p.hobbies.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Hobbies', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final hobby in p.hobbies)
                AppChip(label: hobby, tone: AppChipTone.grey, dense: true),
            ],
          ),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GradientButton(
                label: 'Message 💬',
                height: 48,
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(RoutePaths.chatTo(p.userId));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _gallery(ThemeData theme, List<String> photoUrls, int activeIndex) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photoUrls.isEmpty)
              Container(
                color: theme.colorScheme.secondary.withValues(alpha: 0.4),
                child: const Icon(LucideIcons.user, size: 64),
              )
            else
              CachedNetworkImage(
                imageUrl: photoUrls[activeIndex],
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: theme.colorScheme.surfaceContainerHighest),
                errorWidget: (_, _, _) => Container(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.4),
                  child: const Icon(LucideIcons.user, size: 64),
                ),
              ),
            if (photoUrls.length > 1) ...[
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  children: [
                    for (var i = 0; i < photoUrls.length; i++)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _photoIndex = i),
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
                      ),
                  ],
                ),
              ),
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(
                          () => _photoIndex =
                              (activeIndex - 1 + photoUrls.length) %
                              photoUrls.length,
                        ),
                        behavior: HitTestBehavior.translucent,
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(
                          () => _photoIndex =
                              (activeIndex + 1) % photoUrls.length,
                        ),
                        behavior: HitTestBehavior.translucent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
