// language_screen.dart
import 'package:flutter/material.dart';
import 'package:krishidoc/locale/base_language_key.dart';
import 'package:krishidoc/locale/language_ar.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/language_selector.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final BaseLanguage lang = BaseLanguage.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.language),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${lang.language}:',
              style: boldTextStyle(size: 18),
              textDirection: lang is LanguageAr ? TextDirection.rtl : TextDirection.ltr,
            ),
            12.height,
            LanguageSelector(
              selected: settings.language,
              onChanged: (langCode) {
                settings.setLanguage(langCode);
                Navigator.pop(context); // Return to previous screen after selection
              },
            ),
          ],
        ),
      ),
    );
  }
}