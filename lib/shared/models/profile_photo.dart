import 'package:equatable/equatable.dart';

/// Server-side NSFW/human-photo moderation outcome — mirrors the proposed
/// `moderation_status` column on `profile_photos` (see
/// `BACKEND_ATIER_HANDOFF.md` §5, the `moderate-image` Edge Function). The
/// column doesn't exist yet ([BE-5]/[BE-8]) — [ProfilePhoto.fromJson] treats
/// a missing value as [approved] so every photo behaves exactly as before
/// this field was added (backward compatible until backend ships it).
enum PhotoModerationStatus { pending, approved, rejected }

/// Mirrors the live `profile_photos` table (migration 009_profile_photos.sql)
/// — a gallery of up to 4 photos per user. Exactly one row per user can have
/// `isPrimary = true`; that row's `photoUrl` is mirrored onto
/// `profiles.photo_url` by the `sync_primary_profile_photo` trigger.
class ProfilePhoto extends Equatable {
  const ProfilePhoto({
    required this.id,
    required this.userId,
    required this.photoUrl,
    required this.displayOrder,
    required this.isPrimary,
    required this.createdAt,
    required this.updatedAt,
    this.moderationStatus = PhotoModerationStatus.approved,
  });

  final String id;
  final String userId;
  final String photoUrl;
  final int displayOrder;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PhotoModerationStatus moderationStatus;

  factory ProfilePhoto.fromJson(Map<String, dynamic> json) => ProfilePhoto(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    photoUrl: json['photo_url'] as String,
    displayOrder: json['display_order'] as int,
    isPrimary: json['is_primary'] as bool,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    moderationStatus: _statusFromWire(json['moderation_status'] as String?),
  );

  static PhotoModerationStatus _statusFromWire(String? v) => switch (v) {
    'pending' => PhotoModerationStatus.pending,
    'rejected' => PhotoModerationStatus.rejected,
    _ => PhotoModerationStatus.approved,
  };

  @override
  List<Object?> get props => [
    id,
    userId,
    photoUrl,
    displayOrder,
    isPrimary,
    moderationStatus,
  ];
}
