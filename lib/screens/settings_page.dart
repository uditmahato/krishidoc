import 'package:flutter/material.dart';
import 'package:krishidoc/locale/base_language_key.dart';
import 'package:krishidoc/locale/language_ar.dart';
import 'package:krishidoc/utils/colors.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/language_selector.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final BaseLanguage lang = BaseLanguage.of(context);

    return Scaffold(
      backgroundColor: background, // Use background from colors.dart
      appBar: AppBar(
        backgroundColor: primaryColor, // Use primaryColor from colors.dart
        title: Text(
          lang.settings,
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
            Row(
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
                12.width,
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
                  lang.voiceOutput, // Use localized string
                  style: boldTextStyle(size: 18).copyWith(
                    color:
                        textPrimaryLightColor, // Use textPrimaryLightColor from colors.dart
                  ),
                  textDirection: lang is LanguageAr
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                ),
                Switch(
                  value: settings.ttsEnabled,
                  activeTrackColor:
                      primaryColor, // Use primaryColor from colors.dart
                  activeColor: accent, // Use accent from colors.dart
                  onChanged: (val) => settings.toggleTTS(),
                ),
              ],
            ),
            32.height,
            authProvider.isLoggedIn
                ? CustomButton(
                    label: lang.logout,
                    icon: Icons.logout,
                    color: primaryColor, // Use primaryColor from colors.dart
                    textColor: textPrimaryDarkColor, // White text for contrast
                    onPressed: () async {
                      await authProvider.signOut();
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                  )
                : CustomButton(
                    label: lang.login,
                    icon: Icons.login,
                    color: primaryColor, // Use primaryColor from colors.dart
                    textColor: textPrimaryDarkColor, // White text for contrast
                    onPressed: () {
                      Navigator.pushNamed(context, '/signup');
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
