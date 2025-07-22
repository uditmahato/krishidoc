import 'package:cloud_firestore/cloud_firestore.dart'; // <-- ADD THIS
class ChatMessage {
  final String id;
  final String userId;
  final String message;
  final String reply;
  final DateTime timestamp;
  final String language;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.message,
    required this.reply,
    required this.timestamp,
    required this.language,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      userId: map['userId'],
      message: map['message'],
      reply: map['reply'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      language: map['language'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'message': message,
      'reply': reply,
      'timestamp': timestamp,
      'language': language,
    };
  }
}
