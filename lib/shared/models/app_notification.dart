import 'package:equatable/equatable.dart';

/// Notification feed item type.
enum NotificationType { like, superLike, match, message, missedCall, safety, system }

/// In-app activity feed item.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.relatedUserId,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? relatedUserId;

  @override
  List<Object?> get props => [id, type, isRead];
}
