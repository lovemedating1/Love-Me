import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/message.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/state_views.dart';

/// 11 — ChatPage. 1:1 chat: bubbles, read receipts, reactions, image/voice
/// message UI, composer, and call icons (UI only in the mock phase).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.partnerId});

  final String partnerId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<Message> _local = []; // messages sent this session
  bool _seeded = false;

  static const _reactions = ['❤️', '😂', '😮', '😢', '👍', '🔥'];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _local.add(Message(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        senderId: 'me',
        text: text,
        sentAt: DateTime.now(),
        isRead: false,
      ));
      _input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _react(Message m) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final e in _reactions)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      final i = _local.indexWhere((x) => x.id == m.id);
                      if (i >= 0) _local[i] = _local[i].copyWith(reaction: e);
                    });
                    Navigator.pop(context);
                  },
                  child: Text(e, style: const TextStyle(fontSize: 28)),
                ),
            ],
          ),
        ),
      ),
    );
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
            ListTile(
                leading: const Icon(LucideIcons.trash2),
                title: const Text('Clear chat'),
                onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final partner = ref.watch(profileByIdProvider(widget.partnerId));
    final history = ref.watch(messagesProvider(widget.partnerId));

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
      body: Column(
        children: [
          Expanded(
            child: history.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => ErrorView(
                  message: 'Could not load messages.',
                  onRetry: () =>
                      ref.invalidate(messagesProvider(widget.partnerId))),
              data: (loaded) {
                if (!_seeded) {
                  _local.insertAll(0, loaded);
                  _seeded = true;
                }
                if (_local.isEmpty) {
                  return const EmptyView(
                      icon: LucideIcons.messageCircle, message: 'Say hi 👋');
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _local.length,
                  itemBuilder: (_, i) => _bubble(_local[i]),
                );
              },
            ),
          ),
          _composer(theme),
        ],
      ),
    );
  }

  void _callToast(String kind) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$kind call — available after backend integration.'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Widget _bubble(Message m) {
    final theme = Theme.of(context);
    final mine = m.isMine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _react(m),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          decoration: BoxDecoration(
            color: mine ? AppColors.pink : theme.colorScheme.surfaceContainerHighest,
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
              Text(m.text,
                  style: TextStyle(
                      color: mine ? Colors.white : theme.colorScheme.onSurface)),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(RelativeTime.clock(m.sentAt),
                      style: TextStyle(
                          fontSize: 10,
                          color: (mine ? Colors.white : theme.colorScheme.onSurface)
                              .withValues(alpha: 0.7))),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    Icon(m.isRead ? LucideIcons.checkCheck : LucideIcons.check,
                        size: 13,
                        color: m.isRead ? Colors.lightBlueAccent : Colors.white70),
                  ],
                  if (m.reaction != null) ...[
                    const SizedBox(width: 6),
                    Text(m.reaction!, style: const TextStyle(fontSize: 12)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composer(ThemeData theme) => SafeArea(
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
                  icon: const Icon(LucideIcons.smile),
                  onPressed: () {},
                  tooltip: 'Emoji'),
              IconButton(
                  icon: const Icon(LucideIcons.paperclip),
                  onPressed: () {},
                  tooltip: 'Attach'),
              Expanded(
                child: TextField(
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
              _input.text.trim().isEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.mic),
                      onPressed: () {},
                      tooltip: 'Hold to record')
                  : IconButton.filled(
                      icon: const Icon(LucideIcons.send),
                      onPressed: _send,
                    ),
            ],
          ),
        ),
      );
}
