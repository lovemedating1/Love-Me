import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../models/profile.dart';

/// Square profile tile for grids (Likes, Explore). Optional [blurred] hides the
/// photo for the free-tier "Liked You" premium gate.
class ProfileTile extends StatelessWidget {
  const ProfileTile({
    super.key,
    required this.profile,
    this.onTap,
    this.blurred = false,
    this.overlayIcon,
  });

  final Profile profile;
  final VoidCallback? onTap;
  final bool blurred;
  final IconData? overlayIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (profile.photoUrl != null)
                CachedNetworkImage(
                  imageUrl: profile.photoUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                      color: theme.colorScheme.surfaceContainerHighest),
                  errorWidget: (_, _, _) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(LucideIcons.user)),
                )
              else
                Container(color: theme.colorScheme.surfaceContainerHighest),
              if (blurred)
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(color: Colors.black.withValues(alpha: 0.15)),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
              ),
              if (blurred)
                const Center(
                    child: Icon(LucideIcons.lock, color: Colors.white, size: 32)),
              if (overlayIcon != null && !blurred)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(overlayIcon, color: AppColors.pink, size: 22),
                ),
              if (profile.isOnline && !blurred)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: AppColors.online,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)),
                  ),
                ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 8,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        blurred ? '•••••, ${profile.ageLabel}' : '${profile.name}, ${profile.ageLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                    ),
                    if (profile.isVerified && !blurred) ...[
                      const SizedBox(width: 4),
                      const Icon(LucideIcons.badgeCheck,
                          color: Colors.white, size: 14),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
