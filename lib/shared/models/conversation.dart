import 'package:equatable/equatable.dart';

/// A chat thread summary for the Messages list.
class Conversation extends Equatable {
  const Conversation({
    required this.partnerId,
    required this.partnerName,
    required this.lastMessage,
    required this.lastAt,
    this.partnerPhotoUrl,
    this.unreadCount = 0,
    this.isOnline = false,
    this.isMuted = false,
    this.isVerified = false,
  });

  final String partnerId;
  final String partnerName;
  final String? partnerPhotoUrl;
  final String lastMessage;
  final DateTime lastAt;
  final int unreadCount;
  final bool isOnline;
  final bool isMuted;
  final bool isVerified;

  @override
  List<Object?> get props => [partnerId, lastMessage, lastAt, unreadCount];
}
