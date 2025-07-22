// lib/screens/disease_result_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/disease_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';         // ← import settings
import '../models/disease_model.dart';
import '../utils/constants.dart';
import '../widgets/custom_button.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class DiseaseResultPage extends StatelessWidget {
  const DiseaseResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    final diseaseProvider = Provider.of<DiseaseProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final settings    = Provider.of<SettingsProvider>(context, listen: false);  // ← grab language code
    final disease     = diseaseProvider.currentDisease;
    final imagePath   = diseaseProvider.lastImagePath;

    if (diseaseProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (disease == null) {
      return const Scaffold(
        body: Center(child: Text('No disease detected.')),
      );
    }

    // get the code, e.g. 'en', 'ne', or 'hi'
    final langCode = settings.language;

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnosis Result')),
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
            Text(disease.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Confidence: ${(disease.confidence * 100).toStringAsFixed(2)}%',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // ─── Symptoms & Treatment Buttons ───────────────────────
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    label: 'Symptoms',
                    icon: Icons.info_outline,
                    onPressed: () async {
                      final prompt = 
"Provide a concise list of 5–10 common and significant symptoms of ${disease.name}. List only the symptom descriptions (one per line).";
                      await chatProvider.sendMessage(prompt, langCode);
                      _showResponse(context, 'Symptoms', chatProvider);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomButton(
                    label: 'Treatment',
                    icon: Icons.local_hospital,
                    onPressed: () async {
                      final prompt =
"Provide 5–10 effective treatment plans for ${disease.name}, tailored to local farming conditions. List each plan on its own line.";
                      await chatProvider.sendMessage(prompt, langCode);
                      _showResponse(context, 'Treatment', chatProvider);
                    },
                  ),
                ),
              ],
            ),

            const Spacer(),

            // ─── Back Button ───────────────────────────────────────
            CustomButton(
              label: 'Back to Home',
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
      BuildContext context, String title, ChatProvider chatProvider) {
    final reply = chatProvider.chats.isNotEmpty
        ? chatProvider.chats.last.reply
        : 'No response.';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text('$title of Diagnosis'),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.5,
          child: SingleChildScrollView(
            child: MarkdownBody(data: reply),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
