# LoveMe Flutter — Chat Module Integration Guide

Covers the tables added in `005_chat.sql` + `006_chat_rls.sql`: **conversations, messages, message_reads, message_reactions, call_logs**. Builds on `MATCHING_INTEGRATION_GUIDE.md` — a conversation only exists for an active match.

**Verified against live data on 2026-07-06**: every constraint and RLS policy below was tested end-to-end against the real `lovemedating` database using two real signed-up test accounts (plus a third unrelated account to confirm isolation), not just read from the SQL. Everything passed as designed — no bugs found, no fixes needed.

---

## 1. What's new

| Table | Purpose |
|---|---|
| `conversations` | One per match; holds the message thread |
| `messages` | Chat messages — text, image, video, audio, gif, sticker, location |
| `message_reads` | Read receipts, one row per (message, user) |
| `message_reactions` | Emoji reactions, one row per (message, user, emoji) |
| `call_logs` | Voice/video call history |

**Important:** there is no trigger yet to auto-create a `conversations` row when a match forms. Until that trigger exists, **the client cannot create conversations either** — RLS only grants `SELECT`/`UPDATE` on `conversations`, not `INSERT`. This means chat is currently unusable end-to-end for a brand-new match; someone with service-role access needs to create the conversation row manually until the trigger migration lands. Flag this to backend before shipping a chat screen.

---

## 2. Enums

```dart
enum MessageType { text, image, video, audio, gif, sticker, location }
enum MessageStatus { sending, sent, delivered, read, failed }
enum CallType { audio, video }
enum CallStatus { ringing, answered, declined, missed, cancelled, ended }
```

Match these spellings exactly — they're Postgres enum labels, and PostgREST rejects unrecognized values with a `22P02` error.

---

## 3. Server-enforced message rules (validate client-side too, but the DB is the real gate)

| Rule | Enforced by |
|---|---|
| `text` messages must have non-empty `message` | `messages_text_requires_body` |
| `image`/`video`/`audio`/`gif`/`sticker` messages must NOT have `message` text | `messages_media_types_no_body` |
| `image`/`video`/`audio`/`gif`/`sticker` messages must have `media_url` | `messages_media_requires_url` |
| `video` messages must have `thumbnail_url` | `messages_video_requires_thumbnail` |
| `is_edited = true` requires `edited_at` set (and vice versa) | `messages_edited_at_requires_flag` |
| `is_deleted = true` requires `deleted_at` set (and vice versa) | `messages_deleted_at_requires_flag` |

**Gap to know about:** `location` messages have no dedicated lat/lng columns yet. There's currently no way to attach coordinates to a location message type — don't build a "share location" feature against this schema until that's added.

Violations raise Postgres error code `23514` (check_violation) via PostgREST. Example: sending an `image` message with both `message` and `media_url` set will be rejected.

```dart
try {
  await supabase.from('messages').insert({...});
} on PostgrestException catch (e) {
  if (e.code == '23514') {
    // constraint violation — check message_type matches its required fields
  }
}
```

---

## 4. Models

**models/conversation.dart**

```dart
class Conversation {
  final String id;
  final String matchId;
  final String? lastMessageId;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.matchId,
    this.lastMessageId,
    this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'],
        matchId: json['match_id'],
        lastMessageId: json['last_message_id'],
        lastMessageAt: json['last_message_at'] != null
            ? DateTime.parse(json['last_message_at'])
            : null,
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );
}
```

**Note:** `last_message_id`/`last_message_at` exist in the schema now but nothing populates them yet (no trigger). Don't rely on them for chat-list sorting/preview until a future migration wires that up — for now, sort conversations by querying `messages` directly or by `conversations.updated_at`.

**models/message.dart**

```dart
enum MessageType { text, image, video, audio, gif, sticker, location }
enum MessageStatus { sending, sent, delivered, read, failed }

class ChatMessage {
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

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.messageType,
    this.message,
    this.mediaUrl,
    this.thumbnailUrl,
    this.replyToMessageId,
    required this.status,
    required this.isEdited,
    this.editedAt,
    required this.isDeleted,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'],
        conversationId: json['conversation_id'],
        senderId: json['sender_id'],
        messageType: MessageType.values.byName(json['message_type']),
        message: json['message'],
        mediaUrl: json['media_url'],
        thumbnailUrl: json['thumbnail_url'],
        replyToMessageId: json['reply_to_message_id'],
        status: MessageStatus.values.byName(json['status']),
        isEdited: json['is_edited'] ?? false,
        editedAt: json['edited_at'] != null ? DateTime.parse(json['edited_at']) : null,
        isDeleted: json['is_deleted'] ?? false,
        deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at']) : null,
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );
}
```

---

## 5. Service: Chat

**services/chat_service.dart**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message.dart';

class ChatService {
  final supabase = Supabase.instance.client;

  // Load message history for a conversation (most recent first)
  Future<List<ChatMessage>> getMessages(String conversationId, {int limit = 50}) async {
    final response = await supabase
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List).map((m) => ChatMessage.fromJson(m)).toList();
  }

  // Send a text message
  Future<ChatMessage> sendTextMessage({
    required String conversationId,
    required String text,
    String? replyToMessageId,
  }) async {
    final myId = supabase.auth.currentUser!.id;
    final response = await supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': myId,
      'message_type': 'text',
      'message': text,
      'reply_to_message_id': replyToMessageId,
    }).select().single();

    return ChatMessage.fromJson(response);
  }

  // Send a media message (image/video/audio/gif/sticker)
  // media_url must come from a Storage upload first — no storage bucket exists yet either (see section 8)
  Future<ChatMessage> sendMediaMessage({
    required String conversationId,
    required MessageType type,
    required String mediaUrl,
    String? thumbnailUrl, // required for video
  }) async {
    final myId = supabase.auth.currentUser!.id;
    final response = await supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': myId,
      'message_type': type.name,
      'media_url': mediaUrl,
      'thumbnail_url': thumbnailUrl,
    }).select().single();

    return ChatMessage.fromJson(response);
  }

  // Edit a message (sender-only — RLS enforces this)
  Future<void> editMessage(String messageId, String newText) async {
    await supabase.from('messages').update({
      'message': newText,
      'is_edited': true,
      'edited_at': DateTime.now().toIso8601String(),
    }).eq('id', messageId);
  }

  // Soft-delete a message (sender-only — RLS enforces this; there is no hard DELETE policy)
  Future<void> deleteMessage(String messageId) async {
    await supabase.from('messages').update({
      'is_deleted': true,
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', messageId);
  }

  // Mark a message as read
  Future<void> markAsRead(String messageId) async {
    final myId = supabase.auth.currentUser!.id;
    try {
      await supabase.from('message_reads').insert({
        'message_id': messageId,
        'user_id': myId,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // ignore "already marked read"
    }
  }

  // Add a reaction
  Future<void> addReaction(String messageId, String emoji) async {
    final myId = supabase.auth.currentUser!.id;
    try {
      await supabase.from('message_reactions').insert({
        'message_id': messageId,
        'user_id': myId,
        'emoji': emoji,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // ignore "already reacted with this emoji"
    }
  }

  // Remove own reaction
  Future<void> removeReaction(String reactionId) async {
    await supabase.from('message_reactions').delete().eq('id', reactionId);
  }

  // Subscribe to new messages in a conversation (realtime)
  RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(ChatMessage) onNewMessage,
  ) {
    return supabase
        .channel('public:messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) => onNewMessage(ChatMessage.fromJson(payload.newRecord)),
        )
        .subscribe();
  }
}
```

---

## 6. Service: Calls

**services/call_service.dart**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class CallService {
  final supabase = Supabase.instance.client;

  // Start a call (caller only)
  Future<String> startCall({
    required String conversationId,
    required String receiverId,
    required String callType, // 'audio' or 'video'
  }) async {
    final myId = supabase.auth.currentUser!.id;
    final response = await supabase.from('call_logs').insert({
      'conversation_id': conversationId,
      'caller_id': myId,
      'receiver_id': receiverId,
      'call_type': callType,
    }).select().single();

    return response['id'] as String;
  }

  // Update call status (either participant can do this)
  Future<void> updateCallStatus(String callId, String status) async {
    await supabase.from('call_logs').update({'call_status': status}).eq('id', callId);
  }

  // End a call — must set ended_at together with ended_by (DB requires both or neither)
  Future<void> endCall(String callId, {required int durationSeconds}) async {
    final myId = supabase.auth.currentUser!.id;
    await supabase.from('call_logs').update({
      'call_status': 'ended',
      'ended_at': DateTime.now().toIso8601String(),
      'ended_by': myId,
      'duration_seconds': durationSeconds,
    }).eq('id', callId);
  }

  // Get call history for a conversation
  Future<List<Map<String, dynamic>>> getCallHistory(String conversationId) async {
    final response = await supabase
        .from('call_logs')
        .select()
        .eq('conversation_id', conversationId)
        .order('started_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }
}
```

**Important:** `ended_by` can only be set if `ended_at` is also set in the same update (constraint `call_logs_ended_by_requires_ended_at`) — always send both together, as shown above.

---

## 7. REST Endpoints Reference

```
GET    /rest/v1/conversations?match_id=eq.<uuid>
PATCH  /rest/v1/conversations?id=eq.<uuid>

GET    /rest/v1/messages?conversation_id=eq.<uuid>&is_deleted=eq.false&order=created_at.desc
POST   /rest/v1/messages          body: { conversation_id, sender_id, message_type, message|media_url }
PATCH  /rest/v1/messages?id=eq.<uuid>   body: { message, is_edited: true, edited_at }
PATCH  /rest/v1/messages?id=eq.<uuid>   body: { is_deleted: true, deleted_at }

POST   /rest/v1/message_reads      body: { message_id, user_id }
GET    /rest/v1/message_reads?message_id=eq.<uuid>

POST   /rest/v1/message_reactions  body: { message_id, user_id, emoji }
DELETE /rest/v1/message_reactions?id=eq.<uuid>

POST   /rest/v1/call_logs          body: { conversation_id, caller_id, receiver_id, call_type }
PATCH  /rest/v1/call_logs?id=eq.<uuid>   body: { call_status, ended_at, ended_by, duration_seconds }
```

---

## 8. RLS Summary (verified live, not just read from SQL)

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `conversations` | participant (via match) | — (system only, no trigger yet — **chat is blocked until this exists**) | participant | — |
| `messages` | participant | sender, and must be a participant | sender only | — (soft-delete via UPDATE instead) |
| `message_reads` | participant | own (`user_id = auth.uid()`) | — | — |
| `message_reactions` | participant | own | — | own |
| `call_logs` | caller or receiver | caller, and must be a participant | caller or receiver | — |

Tested and confirmed on live data:
- A user cannot spoof `sender_id`/`user_id`/`caller_id` as someone else — PostgREST returns `403 42501`.
- A completely unrelated third user gets an empty result set (`[]`) on SELECT and a `403` on INSERT for any of these tables — RLS filters rather than errors on read, and hard-blocks on write.
- Attempting to UPDATE a message you didn't send returns `200` with an empty body (RLS filters the row out of the update's scope) rather than an error — **check the response array is non-empty to confirm the update actually applied**, don't assume a 200 means success.

---

## 9. Still not built

- Trigger to auto-create `conversations` when a match forms (**blocks chat entirely right now** — flag to backend before building a chat screen against this)
- Trigger to populate `conversations.last_message_id` / `last_message_at`
- Location message coordinates (no lat/lng columns exist)
- Storage buckets for chat media (`chat-images`, `chat-files`, `voice-messages` per the full backend spec) — `media_url`/`thumbnail_url` are plain text columns with no upload pipeline wired up yet
- Push notification on new message (`notify_on_message` trigger + edge function, per full spec)
- Blocking a match does not cascade into blocking calls/messages yet

Check back as these land in future migrations.