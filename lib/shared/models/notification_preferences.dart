import 'package:equatable/equatable.dart';

/// Mirrors the live `notification_preferences` table (migration_004.md) —
/// one row per user, created once right after sign-up.
class NotificationPreferences extends Equatable {
  const NotificationPreferences({
    this.pushEnabled = true,
    this.emailEnabled = true,
    this.likeNotifications = true,
    this.matchNotifications = true,
    this.messageNotifications = true,
    this.callNotifications = true,
    this.profileViewNotifications = true,
    this.marketingNotifications = true,
  });

  final bool pushEnabled;
  final bool emailEnabled;
  final bool likeNotifications;
  final bool matchNotifications;
  final bool messageNotifications;
  final bool callNotifications;
  final bool profileViewNotifications;
  final bool marketingNotifications;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        pushEnabled: json['push_enabled'] as bool? ?? true,
        emailEnabled: json['email_enabled'] as bool? ?? true,
        likeNotifications: json['like_notifications'] as bool? ?? true,
        matchNotifications: json['match_notifications'] as bool? ?? true,
        messageNotifications: json['message_notifications'] as bool? ?? true,
        callNotifications: json['call_notifications'] as bool? ?? true,
        profileViewNotifications:
            json['profile_view_notifications'] as bool? ?? true,
        marketingNotifications:
            json['marketing_notifications'] as bool? ?? true,
      );

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? likeNotifications,
    bool? matchNotifications,
    bool? messageNotifications,
    bool? callNotifications,
    bool? profileViewNotifications,
    bool? marketingNotifications,
  }) => NotificationPreferences(
    pushEnabled: pushEnabled ?? this.pushEnabled,
    emailEnabled: emailEnabled ?? this.emailEnabled,
    likeNotifications: likeNotifications ?? this.likeNotifications,
    matchNotifications: matchNotifications ?? this.matchNotifications,
    messageNotifications: messageNotifications ?? this.messageNotifications,
    callNotifications: callNotifications ?? this.callNotifications,
    profileViewNotifications:
        profileViewNotifications ?? this.profileViewNotifications,
    marketingNotifications:
        marketingNotifications ?? this.marketingNotifications,
  );

  @override
  List<Object?> get props => [
    pushEnabled,
    emailEnabled,
    likeNotifications,
    matchNotifications,
    messageNotifications,
    callNotifications,
    profileViewNotifications,
    marketingNotifications,
  ];
}
