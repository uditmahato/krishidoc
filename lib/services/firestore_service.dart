import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/history_model.dart';
import '../models/chat_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Save history
  Future<void> saveHistory(HistoryEntry entry) async {
    await _db.collection('users').doc(entry.userId)
      .collection('history').doc(entry.id).set(entry.toMap());
  }

  // Get history
  Future<List<HistoryEntry>> getHistory(String userId) async {
    var snapshot = await _db.collection('users').doc(userId)
      .collection('history').orderBy('timestamp', descending: true).get();
    return snapshot.docs.map((doc) => HistoryEntry.fromMap(doc.data())).toList();
  }

  // Save chat
  Future<void> saveChat(ChatMessage chat) async {
    await _db.collection('users').doc(chat.userId)
      .collection('chats').doc(chat.id).set(chat.toMap());
  }

  // Get chat history
  Future<List<ChatMessage>> getChats(String userId) async {
    var snapshot = await _db.collection('users').doc(userId)
      .collection('chats').orderBy('timestamp', descending: true).get();
    return snapshot.docs.map((doc) => ChatMessage.fromMap(doc.data())).toList();
  }
}
