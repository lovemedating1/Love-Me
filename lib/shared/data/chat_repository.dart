import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../models/message_reaction.dart';
import 'profile_photo_repository.dart' show mapStorageError;

/// Supabase Storage buckets for chat media (live 2026-07-10, per the backend
/// deploy memo §1). All are **private** — reads go through short-lived signed
/// URLs minted on demand.
const kChatImagesBucket = 'chat-images';
const kChatVideosBucket = 'chat-files'; // spec groups non-image media here
const kChatThumbsBucket = 'chat-file-thumbs';
const kVoiceMessagesBucket = 'voice-messages';

/// A media file uploaded to storage, ready to attach to a message.
///
/// [mediaPath] / [thumbnailPath] are **object paths** inside the private
/// bucket (`<conversationId>/<uuid>.<ext>`), NOT URLs. They are what gets
/// stored in `messages.media_url` / `messages.thumbnail_url`, so the media
/// never expires — a fresh signed URL is minted at render time via
/// [ChatRepository.signedUrlFor] (backend deploy memo §5, open question 1:
/// "store object paths instead of 7-day signed URLs").
class UploadedChatMedia {
  const UploadedChatMedia({required this.mediaPath, this.thumbnailPath});
  final String mediaPath;
  final String? thumbnailPath;
}

/// Chat — live against `messages`/`message_reads`/`message_reactions`
/// (migration 005_chat.sql / 006_chat_rls.sql) + the 5 chat-media storage
/// buckets (live 2026-07-10).
///
/// A conversation is auto-created for every match by the live
/// `create_conversation_on_match` trigger, so any active match can send
/// media — see ConversationRepository.
abstract interface class ChatRepository {
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
  });

  Future<ChatMessage> sendTextMessage({
    required String conversationId,
    required String text,
    String? replyToMessageId,
  });

  /// Uploads a chat image to `chat-images` and returns its **object path**
  /// (to store as the message's `media_url`; render with [signedUrlFor]).
  Future<UploadedChatMedia> uploadChatImage(
    String conversationId,
    Uint8List bytes, {
    required String fileExtension,
  });

  /// Uploads a chat video (to `chat-files`) + its thumbnail (to
  /// `chat-file-thumbs`) and returns both **object paths**.
  Future<UploadedChatMedia> uploadChatVideo(
    String conversationId,
    Uint8List bytes, {
    required String fileExtension,
    required Uint8List thumbnailBytes,
  });

  /// Uploads a voice message (m4a) to `voice-messages`; returns its path.
  Future<UploadedChatMedia> uploadVoice(
    String conversationId,
    Uint8List bytes, {
    String fileExtension = 'm4a',
  });

  /// Mints a fresh, short-lived signed URL for a stored media object [path].
  /// [bucketForType] picks the right private bucket from the message type.
  /// Returns `null` if [path] is null/empty. Media paths are stored (not
  /// URLs), so this is called every time a media bubble renders.
  Future<String?> signedUrlFor(
    String? path,
    MessageType type, {
    bool thumbnail = false,
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

  /// Broadcasts "I'm typing" on a per-conversation ephemeral channel — no
  /// table, no persistence, purely a live signal (Supabase Realtime
  /// Broadcast, not Postgres Changes). Fire-and-forget; the UI debounces
  /// calls to this (see `chat_screen.dart`'s `_onComposerChanged`) so it
  /// isn't sent on every keystroke.
  Future<void> broadcastTyping(String conversationId);

  /// Subscribes to the other participant's typing broadcasts on
  /// [conversationId]. [onTyping] fires (with no payload beyond "someone is
  /// typing right now") each time a broadcast arrives; the UI is
  /// responsible for its own "stopped typing after N seconds of silence"
  /// timeout, since there's no explicit "stopped typing" event — broadcast
  /// is a fire-and-forget signal, not a stateful presence channel.
  sb.RealtimeChannel subscribeToTyping(
    String conversationId,
    void Function() onTyping,
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

  /// Signed-URL lifetime for on-render media reads. Short (1 hour) because
  /// URLs are minted fresh each time a bubble renders — we store the object
  /// path, not the URL, so there's no need for a long-lived token.
  static const _signedUrlTtl = 60 * 60; // 1 hour

  /// Uploads bytes to a private chat bucket and returns the **object path**
  /// (not a URL). Callers store this path in the message row and render it
  /// via [signedUrlFor].
  Future<String> _uploadPrivate(
    String bucket,
    String conversationId,
    Uint8List bytes,
    String ext,
    String contentType,
  ) async {
    final path = '$conversationId/${const Uuid().v4()}.$ext';
    try {
      await _client.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: sb.FileOptions(contentType: contentType, upsert: true),
          );
      return path;
    } catch (e) {
      throw mapStorageError(e, bucket);
    }
  }

  /// Which private bucket a given media path lives in, derived from the
  /// message type (thumbnails always live in `chat-file-thumbs`).
  String _bucketFor(MessageType type, {required bool thumbnail}) {
    if (thumbnail) return kChatThumbsBucket;
    return switch (type) {
      MessageType.image => kChatImagesBucket,
      MessageType.video => kChatVideosBucket,
      MessageType.audio => kVoiceMessagesBucket,
      _ => kChatImagesBucket,
    };
  }

  @override
  Future<String?> signedUrlFor(
    String? path,
    MessageType type, {
    bool thumbnail = false,
  }) async {
    if (path == null || path.isEmpty) return null;
    // Legacy rows may still hold a full signed/public URL rather than a bare
    // object path — pass those through unchanged so old messages keep working.
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final bucket = _bucketFor(type, thumbnail: thumbnail);
    try {
      return await _client.storage
          .from(bucket)
          .createSignedUrl(path, _signedUrlTtl);
    } catch (_) {
      // Non-fatal: a missing/denied object just renders the error placeholder.
      return null;
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
    final path = await _uploadPrivate(
      kChatImagesBucket,
      conversationId,
      bytes,
      fileExtension,
      contentType,
    );
    return UploadedChatMedia(mediaPath: path);
  }

  @override
  Future<UploadedChatMedia> uploadChatVideo(
    String conversationId,
    Uint8List bytes, {
    required String fileExtension,
    required Uint8List thumbnailBytes,
  }) async {
    final mediaPath = await _uploadPrivate(
      kChatVideosBucket,
      conversationId,
      bytes,
      fileExtension,
      'video/mp4',
    );
    final thumbPath = await _uploadPrivate(
      kChatThumbsBucket,
      conversationId,
      thumbnailBytes,
      'jpg',
      'image/jpeg',
    );
    return UploadedChatMedia(mediaPath: mediaPath, thumbnailPath: thumbPath);
  }

  @override
  Future<UploadedChatMedia> uploadVoice(
    String conversationId,
    Uint8List bytes, {
    String fileExtension = 'm4a',
  }) async {
    final path = await _uploadPrivate(
      kVoiceMessagesBucket,
      conversationId,
      bytes,
      fileExtension,
      'audio/mp4',
    );
    return UploadedChatMedia(mediaPath: path);
  }

  @override
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
  }) async {
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
      await _client.from('message_reads').insert({
        'message_id': messageId,
        'user_id': myId,
      });
    } on sb.PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // already marked read — no-op
    }
  }

  @override
  Future<void> markManyAsRead(Iterable<String> messageIds) async {
    if (messageIds.isEmpty) return;
    final myId = _client.auth.currentUser!.id;
    final rows = [
      for (final id in messageIds) {'message_id': id, 'user_id': myId},
    ];
    try {
      // Ignore rows that already exist (unique on message_id+user_id).
      await _client
          .from('message_reads')
          .upsert(
            rows,
            onConflict: 'message_id,user_id',
            ignoreDuplicates: true,
          );
    } on sb.PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
  }

  @override
  Future<List<MessageReaction>> reactionsFor(
    Iterable<String> messageIds,
  ) async {
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
      await _client.from('message_reactions').insert({
        'message_id': messageId,
        'user_id': myId,
        'emoji': emoji,
      });
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
          callback: (payload) =>
              onNewMessage(ChatMessage.fromJson(payload.newRecord)),
        )
        .subscribe();
  }

  /// Realtime Broadcast (not Postgres Changes) — purely ephemeral, no table,
  /// nothing persisted. One channel per conversation, shared by both
  /// [broadcastTyping] and [subscribeToTyping].
  String _typingChannelName(String conversationId) => 'typing:$conversationId';

  @override
  Future<void> broadcastTyping(String conversationId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return;
    await _client
        .channel(_typingChannelName(conversationId))
        .sendBroadcastMessage(event: 'typing', payload: {'user_id': myId});
  }

  @override
  sb.RealtimeChannel subscribeToTyping(
    String conversationId,
    void Function() onTyping,
  ) {
    final myId = _client.auth.currentUser?.id;
    return _client
        .channel(_typingChannelName(conversationId))
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            // Broadcast delivers to every subscriber on the channel,
            // including the sender — ignore our own typing echo.
            if (payload['user_id'] != myId) onTyping();
          },
        )
        .subscribe();
  }
}
