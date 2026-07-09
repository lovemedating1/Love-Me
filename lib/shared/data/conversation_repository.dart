import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/conversation.dart';
import '../models/match.dart';
import '../models/profile.dart';
import 'match_repository.dart';

/// A conversation resolved for display: the live `conversations` row plus
/// the other participant's profile and a preview of the latest message.
///
/// `conversations.last_message_id`/`last_message_at` are NOT populated yet
/// (no trigger wires them up — migration_003.md §4 note), so the preview is
/// fetched by querying `messages` directly, sorted by `created_at`.
class ConversationSummary {
  const ConversationSummary({
    required this.conversation,
    required this.partner,
    this.lastMessageText,
    this.lastMessageAt,
  });

  final Conversation conversation;
  final Profile partner;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
}

/// Conversations — live against `conversations` (migration 005_chat.sql).
///
/// RLS grants SELECT/UPDATE only, no INSERT: there is no trigger yet to
/// auto-create a conversation when a match forms. A conversation only exists
/// if backend created one out-of-band (service-role). [forPartner] returns
/// `null` when none exists yet — callers (the Chat screen) must handle that
/// as a distinct "chat not available yet" state, not an error.
abstract interface class ConversationRepository {
  Future<List<ConversationSummary>> conversationsForMe();
  Future<Conversation?> forPartner(String partnerUserId);
}

class SupabaseConversationRepository implements ConversationRepository {
  const SupabaseConversationRepository({
    this.matchRepository = const SupabaseMatchRepository(),
  });

  final MatchRepository matchRepository;

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  @override
  Future<List<ConversationSummary>> conversationsForMe() async {
    final myId = _client.auth.currentUser!.id;
    final matches = await matchRepository.myMatches();
    if (matches.isEmpty) return [];

    final matchIds = matches.map((m) => m.id).toList();
    final convoRows = await _client
        .from('conversations')
        .select()
        .inFilter('match_id', matchIds);
    final conversations = (convoRows as List)
        .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
        .toList();
    if (conversations.isEmpty) return [];

    final matchByid = {for (final m in matches) m.id: m};
    final otherIds = conversations
        .map((c) => matchByid[c.matchId]?.otherUserId(myId))
        .whereType<String>()
        .toList();
    final profileRows =
        await _client.from('profiles').select().inFilter('user_id', otherIds);
    final profilesById = {
      for (final p in (profileRows as List))
        (p as Map<String, dynamic>)['user_id'] as String: Profile.fromJson(p)
    };

    final summaries = <ConversationSummary>[];
    for (final convo in conversations) {
      final match = matchByid[convo.matchId];
      final partner = match == null ? null : profilesById[match.otherUserId(myId)];
      if (partner == null) continue;

      final lastMessage = await _client
          .from('messages')
          .select('message, created_at')
          .eq('conversation_id', convo.id)
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      summaries.add(ConversationSummary(
        conversation: convo,
        partner: partner,
        lastMessageText: lastMessage?['message'] as String?,
        lastMessageAt: lastMessage?['created_at'] == null
            ? null
            : DateTime.parse(lastMessage!['created_at'] as String),
      ));
    }

    summaries.sort((a, b) {
      final aAt = a.lastMessageAt ?? a.conversation.createdAt;
      final bAt = b.lastMessageAt ?? b.conversation.createdAt;
      return bAt.compareTo(aAt);
    });
    return summaries;
  }

  @override
  Future<Conversation?> forPartner(String partnerUserId) async {
    final myId = _client.auth.currentUser!.id;
    final matches = await matchRepository.myMatches();
    final match = matches.cast<Match?>().firstWhere(
          (m) => m != null && m.otherUserId(myId) == partnerUserId,
          orElse: () => null,
        );
    if (match == null) return null;

    final row = await _client
        .from('conversations')
        .select()
        .eq('match_id', match.id)
        .maybeSingle();
    return row == null ? null : Conversation.fromJson(row);
  }
}
