// lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/disease_model.dart';
import '../locale/localization.dart'; // ← for SupportedLanguages

/// REST endpoints and API key constants
const String PLANT_API_URL =
    'https://plant-api-865621238313.us-central1.run.app/predict/';
const String GEMINI_API_URL =
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';
const String GOOGLE_API_KEY = 'AIzaSyCrBjF1Kodbt8eGQG-ZFM8khh72I_12kbc';

/// System prompt to steer the LLM’s behavior
const String _systemPrompt = '''
You are AgriBot, an expert plant advisor. 
You know about plant diseases, symptoms, yields, prevention, pesticides, pests, land spacing, and climate effects.
If asked anything outside these topics, reply: "I only have information on plant health and related practices."
Be precise; do not give vague answers.
''';

/// Initial assistant greeting to kick off each conversation
const String _assistantGreeting =
    'Hi! I am KrishiDoc, your virtual plant diagnosis doctor.';

class ApiService {
  /// Sends the image at [imagePath] to the plant disease classifier
  /// and returns a populated [Disease] object.
  Future<Disease?> detectDisease(String imagePath) async {
    try {
      print('[ApiService] Sending image for classification: $imagePath');

      final request = http.MultipartRequest('POST', Uri.parse(PLANT_API_URL))
        ..files.add(await http.MultipartFile.fromPath('file', imagePath));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      print(
        '[ApiService] Classifier response ${response.statusCode}: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return Disease.fromMap(data);
      } else {
        print('[ApiService] Classifier error ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('[ApiService] Exception in detectDisease: $e');
      return null;
    }
  }

  /// Sends [message] with the user’s [languageCode] to the LLM API (Gemini),
  /// prepending system instructions and an assistant greeting, then returns the reply.
  Future<String> sendChatMessage(String message, String languageCode) async {
    try {
      // Convert code ('ne') → name ('Nepali') for the prompt
      final languageName = SupportedLanguages.getName(languageCode);

      // Build the full prompt: system instructions, assistant greeting, then user query
      final fullPrompt = StringBuffer()
        ..writeln(_systemPrompt.trim())
        ..writeln()
        ..writeln(_assistantGreeting.trim())
        ..writeln()
        ..writeln('User: "$message"')
        ..writeln('Please respond in $languageName.')
        ..writeln();

      final payload = {
        'contents': [
          {
            'parts': [
              {'text': fullPrompt.toString()},
            ],
          },
        ],
      };

      final uri = Uri.parse('$GEMINI_API_URL?key=$GOOGLE_API_KEY');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      print(
        '[ApiService] LLM response ${response.statusCode}: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String? ?? 'No reply text.';
          }
        }
        return 'Unexpected LLM response format.';
      } else {
        return 'LLM error: ${response.statusCode}';
      }
    } catch (e) {
      print('[ApiService] Exception in sendChatMessage: $e');
      return 'Error communicating with LLM.';
    }
  }
}
