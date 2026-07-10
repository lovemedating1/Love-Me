import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../models/profile.dart';
import 'app_chip.dart';
import 'gradient_button.dart';

/// Shared profile-preview modal (old app: `8`/`WA0035`) — used by the Likes
/// list and the Explore country-user list. Tapping a person in either place
/// opens this instead of navigating straight to chat.
class ProfilePreviewModal extends StatelessWidget {
  const ProfilePreviewModal({super.key, required this.profile});

  final Profile profile;

  static Future<void> show(BuildContext context, Profile profile) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => ProfilePreviewModal(profile: profile),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = profile;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: SizedBox(
              width: 120,
              height: 120,
              child: p.photoUrl == null
                  ? Container(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.4),
                      child: const Icon(LucideIcons.user, size: 56),
                    )
                  : CachedNetworkImage(
                      imageUrl: p.photoUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        color: theme.colorScheme.secondary.withValues(alpha: 0.4),
                        child: const Icon(LucideIcons.user, size: 56),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text('${p.name}, ${p.ageLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              if (p.isVerified) ...[
                const SizedBox(width: 6),
                const Icon(LucideIcons.badgeCheck,
                    color: AppColors.pink, size: 20),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text('📍 ${p.city}, ${p.country}',
              style: const TextStyle(color: AppColors.mutedFg)),
          if (p.relationshipGoal != null) ...[
            const SizedBox(height: 8),
            Text('♥ Need a ${p.relationshipGoal}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          if (p.hobbies.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
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
      ),
    );
  }
}
