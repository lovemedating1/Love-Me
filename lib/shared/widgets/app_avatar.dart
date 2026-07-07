import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';

/// Circular avatar with optional online dot + verified badge.
/// Port of the reference `OptimizedAvatar`.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.photoUrl,
    this.size = 48,
    this.showOnline = false,
    this.isOnline = false,
    this.isVerified = false,
  });

  final String? photoUrl;
  final double size;
  final bool showOnline;
  final bool isOnline;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: SizedBox(
              width: size,
              height: size,
              child: (photoUrl == null || photoUrl!.isEmpty)
                  ? Container(
                      color: scheme.secondary.withValues(alpha: 0.4),
                      child: Icon(LucideIcons.user,
                          size: size * 0.5, color: scheme.onSurface),
                    )
                  : CachedNetworkImage(
                      imageUrl: photoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                          color: scheme.secondary.withValues(alpha: 0.3)),
                      errorWidget: (_, _, _) => Container(
                        color: scheme.secondary.withValues(alpha: 0.4),
                        child: Icon(LucideIcons.user,
                            size: size * 0.5, color: scheme.onSurface),
                      ),
                    ),
            ),
          ),
          if (showOnline && isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: AppColors.online,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
              ),
            ),
          if (isVerified)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.badgeCheck,
                    size: size * 0.3, color: AppColors.pink),
              ),
            ),
        ],
      ),
    );
  }
}
