import 'package:cloud_firestore/cloud_firestore.dart'; // <-- ADD THIS

class HistoryEntry {
  final String id;
  final String userId;
  final String imageUrl;
  final String diseaseName;
  final DateTime timestamp;

  HistoryEntry({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.diseaseName,
    required this.timestamp,
  });

  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    return HistoryEntry(
      id: map['id'],
      userId: map['userId'],
      imageUrl: map['imageUrl'],
      diseaseName: map['diseaseName'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'imageUrl': imageUrl,
      'diseaseName': diseaseName,
      'timestamp': timestamp,
    };
  }
}
