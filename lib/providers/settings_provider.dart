import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:krishidoc/locale/localization.dart';

class SettingsProvider with ChangeNotifier {
  String _language = getStringAsync('selected_language', defaultValue: SupportedLanguages.english);
  bool _ttsEnabled = getBoolAsync('tts_enabled', defaultValue: false);

  String get language => _language;
  bool get ttsEnabled => _ttsEnabled;

  void setLanguage(String langCode) {
    if (SupportedLanguages.codes.contains(langCode) && _language != langCode) {
      _language = langCode;
      setValue('selected_language', langCode);
      print('SettingsProvider: Language set to $langCode');
      notifyListeners();
    }
  }

  void toggleTTS() {
    _ttsEnabled = !_ttsEnabled;
    setValue('tts_enabled', _ttsEnabled);
    print('SettingsProvider: TTS enabled: $_ttsEnabled');
    notifyListeners();
  }
}