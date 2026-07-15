import 'package:equatable/equatable.dart';

/// A user the current user has blocked — mirrors the (not-yet-live)
/// `blocked_users` table proposed in `BACKEND_ATIER_HANDOFF.md` §2.
///
/// This is distinct from `matches.status = 'blocked'`
/// ([MatchRepository.block]): that only covers blocking someone you've
/// matched with, scoped to the match row. `blocked_users` is a standalone
/// block that also works from Discover (a card you were never matched with)
/// and persists even if the match is later deleted.
class BlockedUser extends Equatable {
  const BlockedUser({
    required this.id,
    required this.blockedUserId,
    required this.blockedName,
    required this.createdAt,
  });

  final String id;
  final String blockedUserId;
  final String blockedName;
  final DateTime createdAt;

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
    id: json['id'] as String,
    blockedUserId: json['blocked_user_id'] as String,
    blockedName: json['blocked_name'] as String? ?? 'Unknown user',
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  @override
  List<Object?> get props => [id, blockedUserId];
}
