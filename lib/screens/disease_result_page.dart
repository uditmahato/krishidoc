import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/disease_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/custom_button.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../locale/base_language_key.dart'; // ← Import BaseLanguage

class DiseaseResultPage extends StatelessWidget {
  const DiseaseResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    final diseaseProvider = Provider.of<DiseaseProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final BaseLanguage lang = BaseLanguage.of(
      context,
    ); // ← Get localized strings
    final disease = diseaseProvider.currentDisease;
    final imagePath = diseaseProvider.lastImagePath;

    if (diseaseProvider.isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (disease == null) {
      return Scaffold(
        body: Center(
          child: Text(lang.noHistory),
        ), // ← Use localized 'noHistory'
      );
    }

    // Get the language code, e.g., 'en', 'ne', or 'hi'
    final langCode = settings.language;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.diagnosisResult),
      ), // ← Use localized 'diagnosisResult'
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Show the image
            if (imagePath != null)
              Image.file(File(imagePath), height: 180, fit: BoxFit.cover)
            else if (disease.imageUrl.isNotEmpty)
              Image.network(disease.imageUrl, height: 180, fit: BoxFit.cover),

            const SizedBox(height: 24),
            Text(
              disease.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${lang.confidence}: ${(disease.confidence * 100).toStringAsFixed(2)}%', // ← Use localized 'confidence'
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // ─── Symptoms & Treatment Buttons ───────────────────────
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    label: lang.symptoms, // ← Use localized 'symptoms'
                    icon: Icons.info_outline,
                    onPressed: () async {
                      final prompt =
                          "${lang.symptomPrompt} ${disease.name}. ${lang.symptomInstruction}"; // ← Use localized prompts
                      await chatProvider.sendMessage(prompt, langCode);
                      _showResponse(
                        context,
                        lang.symptoms,
                        chatProvider,
                      ); // ← Pass localized title
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomButton(
                    label: lang.treatment, // ← Use localized 'treatment'
                    icon: Icons.local_hospital,
                    onPressed: () async {
                      final prompt =
                          "${lang.treatmentPrompt} ${disease.name}, ${lang.treatmentInstruction}"; // ← Use localized prompts
                      await chatProvider.sendMessage(prompt, langCode);
                      _showResponse(
                        context,
                        lang.treatment,
                        chatProvider,
                      ); // ← Pass localized title
                    },
                  ),
                ),
              ],
            ),

            const Spacer(),

            // ─── Back Button ───────────────────────────────────────
            CustomButton(
              label: lang.backToHome, // ← Use localized 'backToHome'
              icon: Icons.home,
              onPressed: () {
                diseaseProvider.clearDisease();
                Navigator.popUntil(context, (r) => r.isFirst);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showResponse(
    BuildContext context,
    String title,
    ChatProvider chatProvider,
  ) {
    final reply = chatProvider.chats.isNotEmpty
        ? chatProvider.chats.last.reply
        : 'No response.'; // Consider localizing this fallback text if needed
    final BaseLanguage lang = BaseLanguage.of(
      context,
    ); // ← Get localized strings for dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(
          '$title ${lang.ofDiagnosis}',
        ), // ← Use localized 'ofDiagnosis'
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.5,
          child: SingleChildScrollView(child: MarkdownBody(data: reply)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.ok), // ← Use localized 'ok'
          ),
        ],
      ),
    );
  }
}
