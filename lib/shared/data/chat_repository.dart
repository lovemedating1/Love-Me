import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../models/message_reaction.dart';
import 'profile_photo_repository.dart' show mapStorageError;

/// Supabase Storage buckets for chat media (per the backend spec §9). All are
/// **private** — reads go through signed URLs. **Must exist in the project.**
const kChatImagesBucket = 'chat-images';
const kChatVideosBucket = 'chat-files'; // spec groups non-image media here
const kChatThumbsBucket = 'chat-file-thumbs';
const kVoiceMessagesBucket = 'voice-messages';

/// A media file uploaded to storage, ready to attach to a message.
class UploadedChatMedia {
  const UploadedChatMedia({required this.mediaUrl, this.thumbnailUrl});
  final String mediaUrl;
  final String? thumbnailUrl;
}

/// Chat — live against `messages`/`message_reads`/`message_reactions`
/// (migration 005_chat.sql / 006_chat_rls.sql) + chat-media storage buckets.
///
/// IMPORTANT: this only works for a conversation that already exists.
/// `conversations` has no INSERT policy and no trigger yet auto-creates one
/// when a match forms — see ConversationRepository and migration_003.md §1/§9.
abstract interface class ChatRepository {
  Future<List<ChatMessage>> getMessages(String conversationId, {int limit = 50});

  Future<ChatMessage> sendTextMessage({
    required String conversationId,
    required String text,
    String? replyToMessageId,
  });

  /// Uploads a chat image to `chat-images` and returns a signed URL to store
  /// as the message's `media_url`.
  Future<UploadedChatMedia> uploadChatImage(
    String conversationId,
    Uint8List bytes, {
    required String fileExtension,
  });

  /// Uploads a chat video (to `chat-files`) + its thumbnail (to
  /// `chat-file-thumbs`) and returns both signed URLs.
  Future<UploadedChatMedia> uploadChatVideo(
    String conversationId,
    Uint8List bytes, {
    required String fileExtension,
    required Uint8List thumbnailBytes,
  });

  /// Uploads a voice message (m4a) to `voice-messages`.
  Future<UploadedChatMedia> uploadVoice(
    String conversationId,
    Uint8List bytes, {
    String fileExtension = 'm4a',
  });

  Future<ChatMessage> sendMediaMessage({
    required String conversationId,
    required MessageType type,
    required String mediaUrl,
    String? thumbnailUrl,
  });

  Future<void> editMessage(String messageId, String newText);

  /// Soft-delete only — there is no hard DELETE policy on `messages`.
  Future<void> deleteMessage(String messageId);

  Future<void> markAsRead(String messageId);

  /// Marks every given message read in one round-trip. Ignores duplicates
  /// (already-read rows) rather than failing the whole batch.
  Future<void> markManyAsRead(Iterable<String> messageIds);

  /// All reactions on the given messages, so the chat can render them under
  /// each bubble. Returns an empty list when [messageIds] is empty.
  Future<List<MessageReaction>> reactionsFor(Iterable<String> messageIds);

  Future<void> addReaction(String messageId, String emoji);

  Future<void> removeReaction(String reactionId);

  sb.RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(ChatMessage) onNewMessage,
  );
}

/// Thrown when the server rejects a message insert/update because it
/// violates a message-shape constraint (Postgres code 23514) — e.g. a text
/// message with no body, or a media message missing `media_url`. See
/// migration_003.md §3 for the full constraint list.
class MessageConstraintException implements Exception {
  const MessageConstraintException(this.message);
  final String message;
}

class SupabaseChatRepository implements ChatRepository {
  const SupabaseChatRepository();

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  static const _signedUrlTtl = 60 * 60 * 24 * 7; // 7 days

  Future<String> _uploadPrivate(
    String bucket,
    String conversationId,
    Uint8List bytes,
    String ext,
    String contentType,
  ) async {
    final path = '$conversationId/${const Uuid().v4()}.$ext';
    try {
      await _client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: sb.FileOptions(contentType: contentType, upsert: true),
          );
      return _client.storage.from(bucket).createSignedUrl(path, _signedUrlTtl);
    } catch (e) {
      throw mapStorageError(e, bucket);
    }
  }

  @override
  Future<UploadedChatMedia> uploadChatImage(
    String conversationId,
    Uint8List bytes, {
    required String fileExtension,
  }) async {
    final contentType = fileExtension == 'png'
        ? 'image/png'
        : (fileExtension == 'webp' ? 'image/webp' : 'image/jpeg');
    final url = await _uploadPrivate(
        kChatImagesBucket, conversationId, bytes, fileExtension, contentType);
    return UploadedChatMedia(mediaUrl: url);
  }

  @override
  Future<UploadedChatMedia> uploadChatVideo(
    String conversationId,
    Uint8List bytes, {
    required String fileExtension,
    required Uint8List thumbnailBytes,
  }) async {
    final mediaUrl = await _uploadPrivate(kChatVideosBucket, conversationId,
        bytes, fileExtension, 'video/mp4');
    final thumbUrl = await _uploadPrivate(kChatThumbsBucket, conversationId,
        thumbnailBytes, 'jpg', 'image/jpeg');
    return UploadedChatMedia(mediaUrl: mediaUrl, thumbnailUrl: thumbUrl);
  }

  @override
  Future<UploadedChatMedia> uploadVoice(
    String conversationId,
    Uint8List bytes, {
    String fileExtension = 'm4a',
  }) async {
    final url = await _uploadPrivate(kVoiceMessagesBucket, conversationId,
        bytes, fileExtension, 'audio/mp4');
    return UploadedChatMedia(mediaUrl: url);
  }

  @override
  Future<List<ChatMessage>> getMessages(String conversationId,
      {int limit = 50}) async {
    final response = await _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .limit(limit);
    return (response as List)
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ChatMessage> sendTextMessage({
    required String conversationId,
    required String text,
    String? replyToMessageId,
  }) async {
    final myId = _client.auth.currentUser!.id;
    try {
      final response = await _client
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': myId,
            'message_type': MessageType.text.name,
            'message': text,
            if (replyToMessageId != null)
              'reply_to_message_id': replyToMessageId,
          })
          .select()
          .single();
      return ChatMessage.fromJson(response);
    } on sb.PostgrestException catch (e) {
      if (e.code == '23514') {
        throw MessageConstraintException(e.message);
      }
      rethrow;
    }
  }

  @override
  Future<ChatMessage> sendMediaMessage({
    required String conversationId,
    required MessageType type,
    required String mediaUrl,
    String? thumbnailUrl,
  }) async {
    final myId = _client.auth.currentUser!.id;
    try {
      final response = await _client
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': myId,
            'message_type': type.name,
            'media_url': mediaUrl,
            if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
          })
          .select()
          .single();
      return ChatMessage.fromJson(response);
    } on sb.PostgrestException catch (e) {
      if (e.code == '23514') {
        throw MessageConstraintException(e.message);
      }
      rethrow;
    }
  }

  @override
  Future<void> editMessage(String messageId, String newText) => _client
      .from('messages')
      .update({
        'message': newText,
        'is_edited': true,
        'edited_at': DateTime.now().toIso8601String(),
      })
      .eq('id', messageId);

  @override
  Future<void> deleteMessage(String messageId) => _client
      .from('messages')
      .update({
        'is_deleted': true,
        'deleted_at': DateTime.now().toIso8601String(),
      })
      .eq('id', messageId);

  @override
  Future<void> markAsRead(String messageId) async {
    final myId = _client.auth.currentUser!.id;
    try {
      await _client
          .from('message_reads')
          .insert({'message_id': messageId, 'user_id': myId});
    } on sb.PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // already marked read — no-op
    }
  }

  @override
  Future<void> markManyAsRead(Iterable<String> messageIds) async {
    if (messageIds.isEmpty) return;
    final myId = _client.auth.currentUser!.id;
    final rows = [
      for (final id in messageIds) {'message_id': id, 'user_id': myId}
    ];
    try {
      // Ignore rows that already exist (unique on message_id+user_id).
      await _client.from('message_reads').upsert(
            rows,
            onConflict: 'message_id,user_id',
            ignoreDuplicates: true,
          );
    } on sb.PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
  }

  @override
  Future<List<MessageReaction>> reactionsFor(Iterable<String> messageIds) async {
    if (messageIds.isEmpty) return const [];
    final rows = await _client
        .from('message_reactions')
        .select()
        .inFilter('message_id', messageIds.toList());
    return (rows as List)
        .map((r) => MessageReaction.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> addReaction(String messageId, String emoji) async {
    final myId = _client.auth.currentUser!.id;
    try {
      await _client.from('message_reactions').insert(
          {'message_id': messageId, 'user_id': myId, 'emoji': emoji});
    } on sb.PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // already reacted with this emoji
    }
  }

  @override
  Future<void> removeReaction(String reactionId) =>
      _client.from('message_reactions').delete().eq('id', reactionId);

  @override
  sb.RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(ChatMessage) onNewMessage,
  ) {
    return _client
        .channel('public:messages:$conversationId')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: sb.PostgresChangeFilter(
            type: sb.PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) => onNewMessage(ChatMessage.fromJson(payload.newRecord)),
        )
        .subscribe();
  }
}
