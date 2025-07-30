import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:krishidoc/locale/localization.dart';

class SettingsProvider with ChangeNotifier {
  String _language = getStringAsync('selected_language', defaultValue: SupportedLanguages.english);
  bool _ttsEnabled = getBoolAsync('tts_enabled', defaultValue: false);

  String get language => _language;
  bool get ttsEnabled => _ttsEnabled;

  void setLanguage(String langCode) async {
    if (SupportedLanguages.codes.contains(langCode)) {
      await setValue('selected_language', langCode);
      _language = langCode;
      notifyListeners();
    }
  }

  void toggleTTS() async {
    _ttsEnabled = !_ttsEnabled;
    await setValue('tts_enabled', _ttsEnabled);
    notifyListeners();
  }
}