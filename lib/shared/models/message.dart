import 'package:equatable/equatable.dart';

/// Mirrors the live `messages` table (migration 005_chat.sql). Enum values
/// must match the Postgres enum labels exactly — PostgREST rejects
/// unrecognized values with a `22P02` error.
enum MessageType { text, image, video, audio, gif, sticker, location }

enum MessageStatus { sending, sent, delivered, read, failed }

/// Server-enforced rules to mirror client-side (see migration_003.md §3):
/// - [MessageType.text] requires non-empty [message], no [mediaUrl].
/// - Media types require [mediaUrl] and must NOT set [message].
/// - [MessageType.video] additionally requires [thumbnailUrl].
/// - `location` has no lat/lng columns yet — don't build against it.
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.messageType,
    this.message,
    this.mediaUrl,
    this.thumbnailUrl,
    this.replyToMessageId,
    required this.status,
    this.isEdited = false,
    this.editedAt,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final MessageType messageType;
  final String? message;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? replyToMessageId;
  final MessageStatus status;
  final bool isEdited;
  final DateTime? editedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        conversationId: json['conversation_id'] as String,
        senderId: json['sender_id'] as String,
        messageType: MessageType.values.byName(json['message_type'] as String),
        message: json['message'] as String?,
        mediaUrl: json['media_url'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String?,
        replyToMessageId: json['reply_to_message_id'] as String?,
        status: MessageStatus.values.byName(json['status'] as String),
        isEdited: json['is_edited'] as bool? ?? false,
        editedAt: json['edited_at'] == null
            ? null
            : DateTime.parse(json['edited_at'] as String),
        isDeleted: json['is_deleted'] as bool? ?? false,
        deletedAt: json['deleted_at'] == null
            ? null
            : DateTime.parse(json['deleted_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  bool isMine(String myUserId) => senderId == myUserId;

  @override
  List<Object?> get props =>
      [id, conversationId, senderId, message, isEdited, isDeleted, status];
}
