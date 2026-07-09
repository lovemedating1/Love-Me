import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../../core/media/photo_picker_service.dart';
import '../../core/media/photo_source_sheet.dart';
import '../../core/media/voice_recorder_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/message.dart';
import '../../shared/models/message_reaction.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/state_views.dart';

/// 11 — ChatPage. 1:1 chat: bubbles, read receipts, reactions, composer, and
/// call icons (call wiring UI-only for now — see CallRepository).
///
/// A conversation only exists once one has been created out-of-band by
/// backend (no client INSERT policy on `conversations`, no auto-create
/// trigger yet — migration_003.md §1/§9). If none exists for this partner,
/// this screen shows an explicit "chat not available yet" state rather than
/// pretending to work.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.partnerId});

  final String partnerId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  RealtimeChannel? _channel;
  String? _subscribedConversationId;
  bool _sendingMedia = false;
  bool _recording = false;

  /// Message ids we've already submitted a read-receipt for this session.
  final Set<String> _markedRead = {};

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _subscribe(String conversationId) {
    if (_subscribedConversationId == conversationId) return;
    _channel?.unsubscribe();
    _subscribedConversationId = conversationId;
    _channel = ref.read(chatRepositoryProvider).subscribeToMessages(
      conversationId,
      (m) {
        if (!mounted) return;
        if (_messages.any((existing) => existing.id == m.id)) return;
        setState(() => _messages.add(m));
        _scrollToBottom();
        _markIncomingRead(conversationId);
      },
    );
  }

  /// Marks every message from the other participant as read. Safe to call
  /// repeatedly — already-read rows are ignored server-side, and we skip ids
  /// we've already submitted this session.
  Future<void> _markIncomingRead(String conversationId) async {
    final myId = ref.read(currentUserProvider).valueOrNull?.userId;
    if (myId == null) return;
    final unread = _messages
        .where((m) => !m.isMine(myId) && !_markedRead.contains(m.id))
        .map((m) => m.id)
        .toList();
    if (unread.isEmpty) return;
    _markedRead.addAll(unread);
    try {
      await ref.read(chatRepositoryProvider).markManyAsRead(unread);
    } catch (_) {
      // Non-fatal: allow a retry on the next load/message.
      _markedRead.removeAll(unread);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.destructive : AppColors.pink,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _send(String conversationId) async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendTextMessage(conversationId: conversationId, text: text);
      // The realtime subscription also delivers this insert — _subscribe's
      // id check de-dupes it rather than appending twice.
    } on MessageConstraintException catch (e) {
      if (mounted) _toast(e.message, error: true);
    } catch (_) {
      if (mounted) _toast('Could not send — try again.', error: true);
    }
  }

  /// Attach flow — lets the user send a Photo or Video from camera/gallery.
  Future<void> _attach(String conversationId) async {
    final kind = await showModalBottomSheet<ChatMediaKind>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(context, ChatMediaKind.image),
            ),
            ListTile(
              leading: const Icon(LucideIcons.video),
              title: const Text('Video'),
              onTap: () => Navigator.pop(context, ChatMediaKind.video),
            ),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;

    final source = await showPhotoSourceSheet(context);
    if (source == null || !mounted) return;

    setState(() => _sendingMedia = true);
    try {
      final picker = ref.read(photoPickerServiceProvider);
      final repo = ref.read(chatRepositoryProvider);

      if (kind == ChatMediaKind.image) {
        final media = await picker.pickChatImage(source);
        final up = await repo.uploadChatImage(conversationId, media.bytes,
            fileExtension: media.fileExtension);
        await repo.sendMediaMessage(
            conversationId: conversationId,
            type: MessageType.image,
            mediaUrl: up.mediaUrl);
      } else {
        final media = await picker.pickChatVideo(source);
        final thumb = media.thumbnailBytes;
        if (thumb == null) {
          if (mounted) _toast('Could not process that video.', error: true);
          return;
        }
        final up = await repo.uploadChatVideo(conversationId, media.bytes,
            fileExtension: media.fileExtension, thumbnailBytes: thumb);
        await repo.sendMediaMessage(
            conversationId: conversationId,
            type: MessageType.video,
            mediaUrl: up.mediaUrl,
            thumbnailUrl: up.thumbnailUrl);
      }
    } on PhotoPickCancelled {
      // No-op.
    } on MediaUploadException catch (e) {
      if (mounted) _toast(e.message, error: true);
    } on MessageConstraintException catch (e) {
      if (mounted) _toast(e.message, error: true);
    } catch (e) {
      if (mounted) _toast('Could not send: $e', error: true);
    } finally {
      if (mounted) setState(() => _sendingMedia = false);
    }
  }

  /// Toggle voice recording: first tap starts, second tap stops + sends.
  Future<void> _toggleVoice(String conversationId) async {
    final recorder = ref.read(voiceRecorderServiceProvider);
    if (!_recording) {
      final ok = await recorder.start();
      if (!ok) {
        if (mounted) _toast('Microphone permission denied.', error: true);
        return;
      }
      if (mounted) setState(() => _recording = true);
      return;
    }

    // Stop + send.
    setState(() {
      _recording = false;
      _sendingMedia = true;
    });
    try {
      final voice = await recorder.stop();
      if (voice == null) {
        if (mounted) _toast('Nothing recorded.');
        return;
      }
      final repo = ref.read(chatRepositoryProvider);
      final up = await repo.uploadVoice(conversationId, voice.bytes,
          fileExtension: voice.fileExtension);
      await repo.sendMediaMessage(
          conversationId: conversationId,
          type: MessageType.audio,
          mediaUrl: up.mediaUrl);
    } on MediaUploadException catch (e) {
      if (mounted) _toast(e.message, error: true);
    } on MessageConstraintException catch (e) {
      if (mounted) _toast(e.message, error: true);
    } catch (e) {
      if (mounted) {
        _toast('Could not send voice message: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _sendingMedia = false);
    }
  }

  Future<void> _react(ChatMessage m, String conversationId) async {
    const reactions = ['❤️', '😂', '😮', '😢', '👍', '🔥'];
    final emoji = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final e in reactions)
                GestureDetector(
                  onTap: () => Navigator.pop(context, e),
                  child: Text(e, style: const TextStyle(fontSize: 28)),
                ),
            ],
          ),
        ),
      ),
    );
    if (emoji == null) return;
    try {
      await ref.read(chatRepositoryProvider).addReaction(m.id, emoji);
      ref.invalidate(reactionsProvider(conversationId));
    } catch (_) {
      if (mounted) _toast('Could not react — try again.', error: true);
    }
  }

  /// Reaction chips under a bubble. Emojis are grouped with a count; tapping
  /// a chip you contributed to removes your own reaction.
  Widget _reactionChips(
      List<MessageReaction> reactions, String? myId, String conversationId) {
    final byEmoji = <String, List<MessageReaction>>{};
    for (final r in reactions) {
      byEmoji.putIfAbsent(r.emoji, () => []).add(r);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 4,
        children: [
          for (final entry in byEmoji.entries)
            _reactionChip(entry.key, entry.value, myId, conversationId),
        ],
      ),
    );
  }

  Widget _reactionChip(String emoji, List<MessageReaction> rs, String? myId,
      String conversationId) {
    final theme = Theme.of(context);
    final mine = myId == null
        ? null
        : rs.where((r) => r.userId == myId).firstOrNull;
    return GestureDetector(
      onTap: mine == null ? null : () => _removeReaction(mine.id, conversationId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: mine != null
              ? Border.all(color: AppColors.pink, width: 1.2)
              : null,
        ),
        child: Text(
          rs.length > 1 ? '$emoji ${rs.length}' : emoji,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Future<void> _removeReaction(String reactionId, String conversationId) async {
    try {
      await ref.read(chatRepositoryProvider).removeReaction(reactionId);
      ref.invalidate(reactionsProvider(conversationId));
    } catch (_) {
      if (mounted) _toast('Could not remove reaction.', error: true);
    }
  }

  void _menu() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: const Icon(LucideIcons.ban),
                title: const Text('Block'),
                onTap: () => Navigator.pop(context)),
            ListTile(
                leading: const Icon(LucideIcons.flag),
                title: const Text('Report'),
                onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  void _callToast(String kind) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$kind call — coming soon.'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final partner = ref.watch(profileByIdProvider(widget.partnerId));
    final conversation = ref.watch(conversationForPartnerProvider(widget.partnerId));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: partner.maybeWhen(
          data: (p) => Row(
            children: [
              AppAvatar(
                  photoUrl: p?.photoUrl,
                  size: 36,
                  showOnline: true,
                  isOnline: p?.isOnline ?? false),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(p?.name ?? 'Chat',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text((p?.isOnline ?? false) ? 'Online now' : 'Offline',
                      style: theme.textTheme.labelSmall),
                ],
              ),
            ],
          ),
          orElse: () => const Text('Chat'),
        ),
        actions: [
          IconButton(
              icon: const Icon(LucideIcons.phone),
              tooltip: 'Voice call',
              onPressed: () => _callToast('Voice')),
          IconButton(
              icon: const Icon(LucideIcons.video),
              tooltip: 'Video call',
              onPressed: () => _callToast('Video')),
          IconButton(
              icon: const Icon(LucideIcons.ellipsisVertical), onPressed: _menu),
        ],
      ),
      body: conversation.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorView(
            message: 'Could not load this conversation.',
            onRetry: () =>
                ref.invalidate(conversationForPartnerProvider(widget.partnerId))),
        data: (convo) {
          if (convo == null) {
            return const EmptyView(
              icon: LucideIcons.messageCircleOff,
              message:
                  "Chat isn't available for this match yet — check back soon.",
            );
          }
          _subscribe(convo.id);
          final messages = ref.watch(messagesProvider(convo.id));
          // Reactions for the loaded messages, grouped by message id.
          final reactions = ref.watch(reactionsProvider(convo.id)).valueOrNull;
          final reactionsByMessage = <String, List<MessageReaction>>{};
          for (final r in reactions ?? const <MessageReaction>[]) {
            reactionsByMessage.putIfAbsent(r.messageId, () => []).add(r);
          }
          return Column(
            children: [
              Expanded(
                child: messages.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => ErrorView(
                      message: 'Could not load messages.',
                      onRetry: () => ref.invalidate(messagesProvider(convo.id))),
                  data: (loaded) {
                    if (_messages.isEmpty && loaded.isNotEmpty) {
                      // API returns most-recent-first; render oldest-first.
                      _messages.addAll(loaded.reversed);
                      // Send read receipts for anything from the other side.
                      WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _markIncomingRead(convo.id));
                    }
                    if (_messages.isEmpty) {
                      return const EmptyView(
                          icon: LucideIcons.messageCircle, message: 'Say hi 👋');
                    }
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _bubble(
                        _messages[i],
                        reactionsByMessage[_messages[i].id] ?? const [],
                        convo.id,
                      ),
                    );
                  },
                ),
              ),
              _composer(theme, convo.id),
            ],
          );
        },
      ),
    );
  }

  Widget _bubble(
      ChatMessage m, List<MessageReaction> reactions, String conversationId) {
    final theme = Theme.of(context);
    final myId = ref.watch(currentUserProvider).valueOrNull?.userId;
    final mine = myId != null && m.isMine(myId);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: () => _react(m, conversationId),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72),
              decoration: BoxDecoration(
                color:
                    mine ? AppColors.pink : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(mine ? 16 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _messageBody(m, mine, theme),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(RelativeTime.clock(m.createdAt),
                          style: TextStyle(
                              fontSize: 10,
                              color:
                                  (mine ? Colors.white : theme.colorScheme.onSurface)
                                      .withValues(alpha: 0.7))),
                      if (mine) ...[
                        const SizedBox(width: 4),
                        Icon(
                            m.status == MessageStatus.read
                                ? LucideIcons.checkCheck
                                : LucideIcons.check,
                            size: 13,
                            color: m.status == MessageStatus.read
                                ? Colors.lightBlueAccent
                                : Colors.white70),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (reactions.isNotEmpty)
            _reactionChips(reactions, myId, conversationId),
        ],
      ),
    );
  }

  /// Renders a message body by type: image/video show the media (video shows
  /// its thumbnail + a play badge); audio shows a voice-note row; everything
  /// else falls back to text.
  Widget _messageBody(ChatMessage m, bool mine, ThemeData theme) {
    final textColor = mine ? Colors.white : theme.colorScheme.onSurface;
    switch (m.messageType) {
      case MessageType.image:
        return _mediaThumb(m.mediaUrl, isVideo: false);
      case MessageType.video:
        return _mediaThumb(m.thumbnailUrl ?? m.mediaUrl, isVideo: true);
      case MessageType.audio:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.mic, size: 18, color: textColor),
            const SizedBox(width: 8),
            Text('Voice message', style: TextStyle(color: textColor)),
          ],
        );
      default:
        return Text(m.message ?? '', style: TextStyle(color: textColor));
    }
  }

  Widget _mediaThumb(String? url, {required bool isVideo}) {
    if (url == null || url.isEmpty) {
      return const Icon(LucideIcons.imageOff, size: 40);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CachedNetworkImage(
            imageUrl: url,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            placeholder: (_, _) => const SizedBox(
                width: 200,
                height: 200,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            errorWidget: (_, _, _) => const SizedBox(
                width: 200,
                height: 200,
                child: Icon(LucideIcons.imageOff, size: 40)),
          ),
          if (isVideo)
            const CircleAvatar(
              radius: 22,
              backgroundColor: Colors.black54,
              child: Icon(LucideIcons.play, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _composer(ThemeData theme, String conversationId) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.colorScheme.outline)),
          ),
          child: Row(
            children: [
              IconButton(
                  icon: const Icon(LucideIcons.paperclip),
                  onPressed:
                      _sendingMedia ? null : () => _attach(conversationId),
                  tooltip: 'Attach photo or video'),
              Expanded(
                child: _recording
                    ? Row(
                        children: [
                          const SizedBox(width: 4),
                          Icon(LucideIcons.mic, color: AppColors.destructive),
                          const SizedBox(width: 8),
                          Text('Recording… tap to send',
                              style: theme.textTheme.bodyMedium),
                        ],
                      )
                    : TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Message',
                          isDense: true,
                          counterText: '',
                        ),
                      ),
              ),
              const SizedBox(width: 4),
              if (_sendingMedia)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_recording)
                IconButton.filled(
                  icon: const Icon(LucideIcons.send),
                  onPressed: () => _toggleVoice(conversationId),
                  tooltip: 'Send voice message',
                )
              else if (_input.text.trim().isEmpty)
                IconButton(
                    icon: const Icon(LucideIcons.mic),
                    onPressed: () => _toggleVoice(conversationId),
                    tooltip: 'Record voice message')
              else
                IconButton.filled(
                  icon: const Icon(LucideIcons.send),
                  onPressed: () => _send(conversationId),
                ),
            ],
          ),
        ),
      );
}
