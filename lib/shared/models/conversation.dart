import 'package:equatable/equatable.dart';

/// Mirrors the live `conversations` table (migration 005_chat.sql).
///
/// One row per match — RLS grants SELECT/UPDATE only, no INSERT: there is no
/// trigger yet to auto-create a conversation when a match forms, so this
/// table is populated out-of-band (service-role) until that trigger ships.
/// See app doctumant/migration_003.md §1/§9.
class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.matchId,
    this.lastMessageId,
    this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String matchId;
  final String? lastMessageId;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String,
        matchId: json['match_id'] as String,
        lastMessageId: json['last_message_id'] as String?,
        lastMessageAt: json['last_message_at'] == null
            ? null
            : DateTime.parse(json['last_message_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  @override
  List<Object?> get props => [id, matchId, lastMessageId, lastMessageAt];
}
