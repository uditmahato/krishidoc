import 'package:flutter/material.dart';

class SettingsProvider with ChangeNotifier {
  String _language = 'en';
  bool _ttsEnabled = true;

  String get language => _language;
  bool get ttsEnabled => _ttsEnabled;

  void setLanguage(String lang) {
    _language = lang;
    notifyListeners();
  }

  void toggleTTS() {
    _ttsEnabled = !_ttsEnabled;
    notifyListeners();
  }
}
