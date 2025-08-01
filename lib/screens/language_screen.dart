import 'package:flutter/material.dart';
import 'package:krishidoc/locale/base_language_key.dart';
import 'package:krishidoc/locale/language_ar.dart';
import 'package:krishidoc/utils/colors.dart';
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
      backgroundColor: background, // Use background from colors.dart
      appBar: AppBar(
        backgroundColor: primaryColor, // Use primaryColor from colors.dart
        title: Text(
          lang.language,
          style: TextStyle(
            color: textPrimaryDarkColor,
          ), // White text for contrast
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${lang.language}:',
              style: boldTextStyle(size: 18).copyWith(
                color:
                    textPrimaryLightColor, // Use textPrimaryLightColor from colors.dart
              ),
              textDirection: lang is LanguageAr
                  ? TextDirection.rtl
                  : TextDirection.ltr,
            ),
            12.height,
            LanguageSelector(
              selected: settings.language,
              onChanged: (langCode) {
                settings.setLanguage(langCode);
                Navigator.pop(
                  context,
                ); // Return to previous screen after selection
              },
            ),
          ],
        ),
      ),
    );
  }
}
