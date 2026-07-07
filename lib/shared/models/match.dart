import 'package:equatable/equatable.dart';

/// Mirrors the live `matches` table (migration 003_matching.sql).
///
/// No client insert/delete — matches are system-created (future mutual-like
/// trigger, not yet shipped). Only SELECT/UPDATE (unmatch/block) are allowed.
enum MatchStatus { active, unmatched, blocked }

MatchStatus matchStatusFromString(String value) {
  switch (value) {
    case 'unmatched':
      return MatchStatus.unmatched;
    case 'blocked':
      return MatchStatus.blocked;
    default:
      return MatchStatus.active;
  }
}

String matchStatusToString(MatchStatus status) => status.name;

class Match extends Equatable {
  const Match({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.status,
    this.blockedBy,
    required this.matchedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String user1Id;
  final String user2Id;
  final MatchStatus status;
  final String? blockedBy;
  final DateTime matchedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Given the current user's id, returns the other participant's id.
  String otherUserId(String myUserId) =>
      user1Id == myUserId ? user2Id : user1Id;

  factory Match.fromJson(Map<String, dynamic> json) => Match(
        id: json['id'] as String,
        user1Id: json['user1_id'] as String,
        user2Id: json['user2_id'] as String,
        status: matchStatusFromString(json['status'] as String),
        blockedBy: json['blocked_by'] as String?,
        matchedAt: DateTime.parse(json['matched_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  @override
  List<Object?> get props =>
      [id, user1Id, user2Id, status, blockedBy, matchedAt];
}
