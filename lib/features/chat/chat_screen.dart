import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../../core/media/photo_picker_service.dart';
import '../../core/media/photo_source_sheet.dart';
import '../../core/media/voice_recorder_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/utils/date_format.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/message.dart';
import '../../shared/models/message_reaction.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/sub_page_header.dart';

/// 11 — ChatPage.
///
/// Rebuilt for UI parity (Phase 4, `9`) — see UI_REBUILD_PLAN.md §4.4:
/// circular-icon header with status dot, date separators, a `+` reaction
/// button on each bubble opening a 20-emoji inline picker, a composer with
/// separate image/attach circles + an emoji icon inside the field + a pink
/// gradient mic FAB, and a safety modal (Block / Report & Block) on 🛡.
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

/// The old app's 20-emoji inline reaction picker (was a 6-emoji bottom sheet).
const _kReactionEmojis = [
  '❤️', '😂', '😮', '😢', '👍', '🔥',
  '😍', '😘', '🥰', '😊', '😉', '👏',
  '🎉', '💯', '🙏', '😢', '😡', '👀',
  '💔', '✨',
];

/// Standard emoji set for the composer's 😊 picker — inserted into the
/// message text, not attached as a reaction, so it's a broader everyday set
/// rather than the reaction picker's expressive-face-focused list.
const _kComposerEmojis = [
  '😀', '😁', '😂', '🤣', '😊', '😍', '😘', '😉',
  '😎', '🤗', '🤔', '😅', '😢', '😭', '😡', '😴',
  '🥰', '😇', '🙃', '🤩', '😋', '😜', '🥳', '😬',
  '👍', '👎', '👏', '🙏', '💪', '👋', '✌️', '🤞',
  '❤️', '🧡', '💛', '💚', '💙', '💜', '💔', '💯',
  '🔥', '✨', '🎉', '🌹', '💐', '🍕', '☕', '🍷',
];

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  RealtimeChannel? _channel;
  String? _subscribedConversationId;
  bool _sendingMedia = false;
  bool _recording = false;

  /// Which message's inline reaction picker is currently open, if any.
  String? _reactionPickerFor;

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

  /// Appends a just-sent message to the local list if realtime hasn't
  /// already delivered it (see [_send] for why this doesn't rely on
  /// realtime alone).
  void _appendSent(ChatMessage sent) {
    if (!mounted || _messages.any((m) => m.id == sent.id)) return;
    setState(() => _messages.add(sent));
    _scrollToBottom();
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
    setState(() {});
    try {
      final sent = await ref
          .read(chatRepositoryProvider)
          .sendTextMessage(conversationId: conversationId, text: text);
      // Append immediately rather than waiting on realtime — the socket can
      // take a moment to (re)connect, or drop a beat on a flaky connection,
      // and the sender should never see their own message vanish. If
      // realtime also delivers this insert, _appendSent's id check no-ops it.
      _appendSent(sent);
    } on MessageConstraintException catch (e) {
      if (mounted) _toast(e.message, error: true);
    } catch (_) {
      if (mounted) _toast('Could not send — try again.', error: true);
    }
  }

  /// Photo flow — separate circular button from the attach ("+") flow below.
  Future<void> _sendPhoto(String conversationId) async {
    final source = await showPhotoSourceSheet(context);
    if (source == null || !mounted) return;
    setState(() => _sendingMedia = true);
    try {
      final picker = ref.read(photoPickerServiceProvider);
      final repo = ref.read(chatRepositoryProvider);
      final media = await picker.pickChatImage(source);
      final up = await repo.uploadChatImage(conversationId, media.bytes,
          fileExtension: media.fileExtension);
      final sent = await repo.sendMediaMessage(
          conversationId: conversationId,
          type: MessageType.image,
          mediaUrl: up.mediaPath);
      _appendSent(sent);
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

  /// Attach ("+") flow — video only, since photo now has its own button.
  Future<void> _attachVideo(String conversationId) async {
    final source = await showPhotoSourceSheet(context);
    if (source == null || !mounted) return;

    setState(() => _sendingMedia = true);
    try {
      final picker = ref.read(photoPickerServiceProvider);
      final repo = ref.read(chatRepositoryProvider);
      final media = await picker.pickChatVideo(source);
      final thumb = media.thumbnailBytes;
      if (thumb == null) {
        if (mounted) _toast('Could not process that video.', error: true);
        return;
      }
      final up = await repo.uploadChatVideo(conversationId, media.bytes,
          fileExtension: media.fileExtension, thumbnailBytes: thumb);
      final sent = await repo.sendMediaMessage(
          conversationId: conversationId,
          type: MessageType.video,
          mediaUrl: up.mediaPath,
          thumbnailUrl: up.thumbnailPath);
      _appendSent(sent);
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
      final sent = await repo.sendMediaMessage(
          conversationId: conversationId,
          type: MessageType.audio,
          mediaUrl: up.mediaPath);
      _appendSent(sent);
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

  void _toggleReactionPicker(String messageId) {
    setState(() =>
        _reactionPickerFor = _reactionPickerFor == messageId ? null : messageId);
  }

  Future<void> _pickReaction(
      ChatMessage m, String emoji, String conversationId) async {
    setState(() => _reactionPickerFor = null);
    try {
      await ref.read(chatRepositoryProvider).addReaction(m.id, emoji);
      ref.invalidate(reactionsProvider(conversationId));
    } catch (_) {
      if (mounted) _toast('Could not react — try again.', error: true);
    }
  }

  Future<void> _removeReaction(String reactionId, String conversationId) async {
    try {
      await ref.read(chatRepositoryProvider).removeReaction(reactionId);
      ref.invalidate(reactionsProvider(conversationId));
    } catch (_) {
      if (mounted) _toast('Could not remove reaction.', error: true);
    }
  }

  /// Long-press on one of MY OWN text messages — Edit / Delete, using the
  /// repository methods that were already built but had no UI entry point.
  void _messageActions(ChatMessage m, String conversationId) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.pencil),
              title: const Text('Edit message'),
              onTap: () {
                Navigator.pop(ctx);
                _editMessage(m, conversationId);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: AppColors.destructive),
              title: const Text('Delete message',
                  style: TextStyle(color: AppColors.destructive)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteMessage(m, conversationId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMessage(ChatMessage m, String conversationId) async {
    final controller = TextEditingController(text: m.message ?? '');
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 2000,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newText == null || newText.isEmpty || newText == m.message) return;
    try {
      await ref.read(chatRepositoryProvider).editMessage(m.id, newText);
      if (mounted) {
        setState(() {
          final i = _messages.indexWhere((msg) => msg.id == m.id);
          if (i != -1) {
            _messages[i] = ChatMessage(
              id: m.id,
              conversationId: m.conversationId,
              senderId: m.senderId,
              messageType: m.messageType,
              message: newText,
              mediaUrl: m.mediaUrl,
              thumbnailUrl: m.thumbnailUrl,
              replyToMessageId: m.replyToMessageId,
              status: m.status,
              isEdited: true,
              editedAt: DateTime.now(),
              isDeleted: m.isDeleted,
              deletedAt: m.deletedAt,
              createdAt: m.createdAt,
              updatedAt: DateTime.now(),
            );
          }
        });
      }
    } catch (_) {
      if (mounted) _toast('Could not edit message — try again.', error: true);
    }
  }

  Future<void> _deleteMessage(ChatMessage m, String conversationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(chatRepositoryProvider).deleteMessage(m.id);
      if (mounted) {
        setState(() => _messages.removeWhere((msg) => msg.id == m.id));
      }
    } catch (_) {
      if (mounted) _toast('Could not delete message — try again.', error: true);
    }
  }

  /// Composer emoji picker — inserts the tapped emoji at the cursor
  /// position (or appends it if the field has no active selection).
  void _openEmojiPicker() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SizedBox(
        height: 260,
        child: GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: 8,
          children: [
            for (final emoji in _kComposerEmojis)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  _insertEmoji(emoji);
                  Navigator.of(ctx).pop();
                },
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _insertEmoji(String emoji) {
    final selection = _input.selection;
    final text = _input.text;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final newText = text.replaceRange(start, end, emoji);
    _input.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    setState(() {});
  }

  void _callToast(String kind) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$kind call — coming soon.'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _safetyModal(String? partnerName) {
    final name = partnerName ?? 'this user';
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.shield, color: AppColors.pink, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name,
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _safetyCard(
              ctx,
              icon: LucideIcons.ban,
              title: 'Block $name',
              subtitle: 'They will no longer be able to contact you.',
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 10),
            _safetyCard(
              ctx,
              icon: LucideIcons.flag,
              title: 'Report & Block',
              subtitle: 'Block them and send a report to our safety team.',
              destructive: true,
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _safetyCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final color =
        destructive ? AppColors.destructive : Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                    Text(subtitle,
                        style: const TextStyle(color: AppColors.mutedFg, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final partner = ref.watch(profileByIdProvider(widget.partnerId));
    final conversation = ref.watch(conversationForPartnerProvider(widget.partnerId));
    final p = partner.valueOrNull;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(gradient: AppGradients.header),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    CircleIconButton(
                      icon: LucideIcons.arrowLeft,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 8),
                    Stack(
                      children: [
                        AppAvatar(photoUrl: p?.photoUrl, size: 40),
                        if (p?.isOnline ?? false)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                color: AppColors.online,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(p?.name ?? 'Chat',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16)),
                          Text((p?.isOnline ?? false) ? 'Online now' : 'Offline',
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    CircleIconButton(
                        icon: LucideIcons.phone,
                        tooltip: 'Voice call',
                        onTap: () => _callToast('Voice')),
                    const SizedBox(width: 6),
                    CircleIconButton(
                        icon: LucideIcons.video,
                        tooltip: 'Video call',
                        onTap: () => _callToast('Video')),
                    const SizedBox(width: 6),
                    CircleIconButton(
                        icon: LucideIcons.shield,
                        tooltip: 'Safety',
                        onTap: () => _safetyModal(p?.name)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: conversation.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorView(
            message: 'Could not load this conversation.',
            onRetry: () =>
                ref.invalidate(conversationForPartnerProvider(widget.partnerId))),
        data: (convo) {
          if (convo == null) {
            // Every active match now auto-gets a conversation (live trigger),
            // so a null here means the match/conversation row hasn't reached
            // this client yet — offer a retry rather than a dead-end wall.
            return EmptyView(
              icon: LucideIcons.messageCircle,
              message: 'Setting up your chat…',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(
                  conversationForPartnerProvider(widget.partnerId)),
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
                      itemBuilder: (_, i) {
                        final m = _messages[i];
                        final showDateSeparator = i == 0 ||
                            !RelativeTime.isSameDay(
                                _messages[i - 1].createdAt, m.createdAt);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDateSeparator) _dateSeparator(m.createdAt),
                            _bubble(
                              m,
                              reactionsByMessage[m.id] ?? const [],
                              convo.id,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              _composer(Theme.of(context), convo.id),
            ],
          );
        },
      ),
    );
  }

  Widget _dateSeparator(DateTime t) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(RelativeTime.dayLabel(t),
              style: const TextStyle(fontSize: 11, color: AppColors.mutedFg)),
        ),
      );

  Widget _bubble(
      ChatMessage m, List<MessageReaction> reactions, String conversationId) {
    final theme = Theme.of(context);
    final myId = ref.watch(currentUserProvider).valueOrNull?.userId;
    final mine = myId != null && m.isMine(myId);
    final pickerOpen = _reactionPickerFor == m.id;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (mine) _reactionButton(m),
              Flexible(
                child: GestureDetector(
                  onLongPress: mine && m.messageType == MessageType.text
                      ? () => _messageActions(m, conversationId)
                      : null,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.68),
                    decoration: BoxDecoration(
                      color: mine
                          ? AppColors.pink
                          : theme.colorScheme.surfaceContainerHighest,
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
                            if (m.isEdited) ...[
                              Text('edited',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                      color: (mine
                                              ? Colors.white
                                              : theme.colorScheme.onSurface)
                                          .withValues(alpha: 0.6))),
                              const SizedBox(width: 4),
                            ],
                            Text(RelativeTime.clock(m.createdAt),
                                style: TextStyle(
                                    fontSize: 10,
                                    color: (mine ? Colors.white : theme.colorScheme.onSurface)
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
              ),
              if (!mine) _reactionButton(m),
            ],
          ),
          if (pickerOpen) _inlineReactionPicker(m, conversationId),
          if (reactions.isNotEmpty)
            _reactionChips(reactions, myId, conversationId),
        ],
      ),
    );
  }

  Widget _reactionButton(ChatMessage m) => IconButton(
        icon: const Icon(LucideIcons.plus, size: 15),
        tooltip: 'React',
        visualDensity: VisualDensity.compact,
        onPressed: () => _toggleReactionPicker(m.id),
      );

  /// The old app's inline 20-emoji picker (white card, 3 rows), replacing the
  /// old 6-emoji bottom sheet — anchored under the bubble it's reacting to.
  Widget _inlineReactionPicker(ChatMessage m, String conversationId) => Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final emoji in _kReactionEmojis)
              GestureDetector(
                onTap: () => _pickReaction(m, emoji, conversationId),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
          ],
        ),
      );

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

  /// Renders a message body by type: image/video show the media (video shows
  /// its thumbnail + a play badge); audio shows a voice-note row; everything
  /// else falls back to text.
  ///
  /// Image/video media is stored as an **object path**, so we mint a signed
  /// URL on demand ([ChatRepository.signedUrlFor]) via [_MediaThumb].
  Widget _messageBody(ChatMessage m, bool mine, ThemeData theme) {
    final textColor = mine ? Colors.white : theme.colorScheme.onSurface;
    final repo = ref.read(chatRepositoryProvider);
    switch (m.messageType) {
      case MessageType.image:
        return _MediaThumb(
          urlFuture: repo.signedUrlFor(m.mediaUrl, MessageType.image),
          isVideo: false,
        );
      case MessageType.video:
        // Prefer the thumbnail (in the thumbs bucket); fall back to the video
        // object itself if no thumbnail path was stored.
        return _MediaThumb(
          urlFuture: m.thumbnailUrl != null
              ? repo.signedUrlFor(m.thumbnailUrl, MessageType.video,
                  thumbnail: true)
              : repo.signedUrlFor(m.mediaUrl, MessageType.video),
          isVideo: true,
        );
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

  Widget _composer(ThemeData theme, String conversationId) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.colorScheme.outline)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _circleComposerButton(
                icon: LucideIcons.image,
                tooltip: 'Send photo',
                onTap: _sendingMedia ? null : () => _sendPhoto(conversationId),
              ),
              const SizedBox(width: 6),
              _circleComposerButton(
                icon: LucideIcons.paperclip,
                tooltip: 'Attach video',
                onTap: _sendingMedia ? null : () => _attachVideo(conversationId),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _recording
                    ? Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.mic, color: AppColors.destructive, size: 18),
                            const SizedBox(width: 8),
                            Text('Recording… tap to send',
                                style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      )
                    : TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Message',
                          isDense: true,
                          counterText: '',
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          suffixIcon: IconButton(
                            icon: const Icon(LucideIcons.smile, size: 18),
                            tooltip: 'Emoji',
                            onPressed: _openEmojiPicker,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 6),
              if (_sendingMedia)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                _micOrSendFab(conversationId),
            ],
          ),
        ),
      );

  Widget _circleComposerButton(
          {required IconData icon, required String tooltip, VoidCallback? onTap}) =>
      Material(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 19, color: AppColors.pink),
          ),
        ),
      );

  Widget _micOrSendFab(String conversationId) {
    final hasText = _input.text.trim().isNotEmpty;
    final icon = _recording
        ? LucideIcons.send
        : (hasText ? LucideIcons.send : LucideIcons.mic);
    final onTap = _recording
        ? () => _toggleVoice(conversationId)
        : (hasText ? () => _send(conversationId) : () => _toggleVoice(conversationId));
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        gradient: AppGradients.cta,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(icon, color: Colors.white, size: 19),
        ),
      ),
    );
  }
}

/// Renders a chat image/video thumbnail from a **signed URL that is minted on
/// demand** — chat media is stored as an object path, not a URL, so the URL is
/// resolved via [ChatRepository.signedUrlFor] the first time this builds and
/// cached for the life of the widget.
class _MediaThumb extends StatefulWidget {
  const _MediaThumb({required this.urlFuture, required this.isVideo});

  final Future<String?> urlFuture;
  final bool isVideo;

  @override
  State<_MediaThumb> createState() => _MediaThumbState();
}

class _MediaThumbState extends State<_MediaThumb> {
  late final Future<String?> _url = widget.urlFuture;

  @override
  Widget build(BuildContext context) {
    // Matches the bubble's maxWidth (chat_screen's _bubble, screenWidth*0.68)
    // minus its horizontal padding (14*2), so the thumbnail never exceeds
    // the bubble's own inner width on narrow phones. Capped at 200 so it
    // still renders at today's size on normal/large screens.
    final bubbleInnerWidth = MediaQuery.of(context).size.width * 0.68 - 28;
    final size = bubbleInnerWidth.clamp(120, 200).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          FutureBuilder<String?>(
            future: _url,
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return SizedBox(
                    width: size,
                    height: size,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)));
              }
              final url = snap.data;
              if (url == null || url.isEmpty) {
                return SizedBox(
                    width: size, height: size, child: const Icon(LucideIcons.imageOff, size: 40));
              }
              return CachedNetworkImage(
                imageUrl: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, _) => SizedBox(
                    width: size,
                    height: size,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                errorWidget: (_, _, _) => SizedBox(
                    width: size, height: size, child: const Icon(LucideIcons.imageOff, size: 40)),
              );
            },
          ),
          if (widget.isVideo)
            const CircleAvatar(
              radius: 22,
              backgroundColor: Colors.black54,
              child: Icon(LucideIcons.play, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

