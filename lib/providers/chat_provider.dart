import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../services/api_service.dart';

class ChatProvider with ChangeNotifier {
  final List<ChatMessage> _chats = [];
  bool _isLoading = false;

  List<ChatMessage> get chats => _chats;
  bool get isLoading => _isLoading;

  Future<void> sendMessage(String message, String language) async {
    _isLoading = true;
    notifyListeners();

    final reply = await ApiService().sendChatMessage(message, language);
    final chat = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: '', // Assign userId as needed
      message: message,
      reply: reply,
      timestamp: DateTime.now(),
      language: language,
    );
    _chats.add(chat);

    _isLoading = false;
    notifyListeners();
  }

  void clearChats() {
    _chats.clear();
    notifyListeners();
  }
}
