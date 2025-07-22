// import 'package:flutter_tts/flutter_tts.dart';
// import 'package:speech_to_text/speech_to_text.dart';

// class SpeechService {
//   final FlutterTts _tts = FlutterTts();
//   final SpeechToText _stt = SpeechToText();

//   // Text to Speech
//   Future<void> speak(String text, {String lang = 'en-US'}) async {
//     await _tts.setLanguage(lang);
//     await _tts.speak(text);
//   }

//   // Speech to Text
//   Future<String> listen({String lang = 'en-US'}) async {
//     bool available = await _stt.initialize();
//     if (available) {
//       await _stt.listen(localeId: lang);
//       // This is a basic example; use a StreamBuilder in UI for real-time speech results.
//       await Future.delayed(Duration(seconds: 5));
//       await _stt.stop();
//       return _stt.lastRecognizedWords;
//     }
//     return '';
//   }
// }
