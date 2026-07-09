import 'package:equatable/equatable.dart';

/// Mirrors the live `message_reactions` table — one row per
/// (message, user, emoji).
class MessageReaction extends Equatable {
  const MessageReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  final String id;
  final String messageId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  factory MessageReaction.fromJson(Map<String, dynamic> json) =>
      MessageReaction(
        id: json['id'] as String,
        messageId: json['message_id'] as String,
        userId: json['user_id'] as String,
        emoji: json['emoji'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, messageId, userId, emoji];
}
