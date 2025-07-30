import 'package:flutter/material.dart';
import 'package:krishidoc/locale/base_language_key.dart';
import 'package:krishidoc/locale/language_ar.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/language_selector.dart';
import '../locale/app_localizations.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final BaseLanguage lang = BaseLanguage.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.settings),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${lang.language}:',
                  style: boldTextStyle(size: 18), // Using nb_utils text style
                  textDirection: lang is LanguageAr ? TextDirection.rtl : TextDirection.ltr,
                ),
                12.width, // Using nb_utils spacing utility
                LanguageSelector(
                  selected: settings.language,
                  onChanged: (langCode) => settings.setLanguage(langCode),
                ),
              ],
            ),
            32.height,
            Row(
              children: [
                Text(
                  'Voice Output:', // Not in AppStrings; kept as static or add to BaseLanguage
                  style: boldTextStyle(size: 18),
                  textDirection: lang is LanguageAr ? TextDirection.rtl : TextDirection.ltr,
                ),
                Switch(
                  value: settings.ttsEnabled,
                  onChanged: (val) => settings.toggleTTS(),
                ),
              ],
            ),
            32.height,
            authProvider.isLoggedIn
                ? CustomButton(
                    label: lang.logout,
                    icon: Icons.logout,
                    onPressed: () async {
                      await authProvider.signOut();
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                  )
                : CustomButton(
                    label: lang.login,
                    icon: Icons.login,
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                  ),
          ],
        ),
      ),
    );
  }
}