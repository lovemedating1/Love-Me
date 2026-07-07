import 'package:equatable/equatable.dart';

enum MessageType { text, image, voice, system }

/// A single chat message.
class Message extends Equatable {
  const Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.type = MessageType.text,
    this.isRead = false,
    this.imageUrl,
    this.voiceDurationSec,
    this.reaction,
  });

  final String id;
  final String senderId; // 'me' for outgoing
  final String text;
  final DateTime sentAt;
  final MessageType type;
  final bool isRead;
  final String? imageUrl;
  final int? voiceDurationSec;
  final String? reaction; // emoji

  bool get isMine => senderId == 'me';

  Message copyWith({bool? isRead, String? reaction}) => Message(
        id: id,
        senderId: senderId,
        text: text,
        sentAt: sentAt,
        type: type,
        isRead: isRead ?? this.isRead,
        imageUrl: imageUrl,
        voiceDurationSec: voiceDurationSec,
        reaction: reaction ?? this.reaction,
      );

  @override
  List<Object?> get props => [id, isRead, reaction];
}
