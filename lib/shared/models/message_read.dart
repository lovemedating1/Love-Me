import 'package:equatable/equatable.dart';

/// Mirrors the live `message_reads` table — one row per (message, user).
class MessageRead extends Equatable {
  const MessageRead({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.readAt,
  });

  final String id;
  final String messageId;
  final String userId;
  final DateTime readAt;

  factory MessageRead.fromJson(Map<String, dynamic> json) => MessageRead(
        id: json['id'] as String,
        messageId: json['message_id'] as String,
        userId: json['user_id'] as String,
        readAt: DateTime.parse(
            (json['read_at'] ?? json['created_at']) as String),
      );

  @override
  List<Object?> get props => [id, messageId, userId];
}
