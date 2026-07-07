import 'package:equatable/equatable.dart';

/// Mirrors the live `likes` table (migration 003_matching.sql).
class Like extends Equatable {
  const Like({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.createdAt,
  });

  final String id;
  final String fromUserId;
  final String toUserId;
  final DateTime createdAt;

  factory Like.fromJson(Map<String, dynamic> json) => Like(
        id: json['id'] as String,
        fromUserId: json['from_user_id'] as String,
        toUserId: json['to_user_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, fromUserId, toUserId, createdAt];
}
