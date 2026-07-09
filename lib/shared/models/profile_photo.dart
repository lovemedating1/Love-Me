import 'package:equatable/equatable.dart';

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
  });

  final String id;
  final String userId;
  final String photoUrl;
  final int displayOrder;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProfilePhoto.fromJson(Map<String, dynamic> json) => ProfilePhoto(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        photoUrl: json['photo_url'] as String,
        displayOrder: json['display_order'] as int,
        isPrimary: json['is_primary'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  @override
  List<Object?> get props => [id, userId, photoUrl, displayOrder, isPrimary];
}
