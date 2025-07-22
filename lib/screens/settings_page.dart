import 'package:flutter/material.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                const Text('Language:', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                LanguageSelector(
                  selected: settings.language,
                  onChanged: (lang) => settings.setLanguage(lang),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                const Text('Voice Output:', style: TextStyle(fontSize: 18)),
                Switch(
                  value: settings.ttsEnabled,
                  onChanged: (val) => settings.toggleTTS(),
                ),
              ],
            ),
            const SizedBox(height: 32),
            authProvider.isLoggedIn
                ? CustomButton(
                    label: 'Logout',
                    icon: Icons.logout,
                    onPressed: () async {
                      await authProvider.signOut();
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                  )
                : CustomButton(
                    label: 'Login',
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
