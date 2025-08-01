import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:krishidoc/locale/base_language_key.dart';
import 'package:krishidoc/screens/classifying_page.dart';
import 'package:krishidoc/utils/colors.dart'; // Already imported
import '../widgets/language_selector.dart';
import '../providers/settings_provider.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // Make all buttons the same height
  static const double _buttonHeight = 140;

  Future<void> _pickImageAndDetect(BuildContext context) async {
    final picker = ImagePicker();
    final BaseLanguage lang = BaseLanguage.of(context);
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(lang.capturePhoto), // Localized "Capture Photo"
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (picked != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClassifyingPage(imagePath: picked.path),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(
                  lang.selectFromGallery,
                ), // Localized "Select from Gallery"
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (picked != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClassifyingPage(imagePath: picked.path),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final BaseLanguage lang = BaseLanguage.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryColor.withOpacity(
                0.2,
              ), // Use primaryColor from colors.dart
              background, // Use background from colors.dart
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, settings, lang),
                const SizedBox(height: 32),
                Text(
                  lang.welcome,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: primaryColor, // Use primaryColor from colors.dart
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  lang.welcomeSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        textSecondaryLightColor, // Use textSecondaryLightColor from colors.dart
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _buildButtonGrid(context, lang),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    SettingsProvider settings,
    BaseLanguage lang,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Image.asset(
            'assets/icons/krishi_logo.png',
            height: 80,
            fit: BoxFit.contain,
          ),
        ),
        Text(
          lang.appName,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: primaryColor.withOpacity(
              0.8,
            ), // Use primaryColor from colors.dart
          ),
        ),
        LanguageSelector(
          selected: settings.language,
          onChanged: (lang) => settings.setLanguage(lang),
        ),
      ],
    );
  }

  Widget _buildButtonGrid(BuildContext context, BaseLanguage lang) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAnimatedButton(
                context,
                label: lang.diagnoseButton,
                icon: Icons.camera_alt_rounded,
                onTap: () => _pickImageAndDetect(context),
                color: primaryColor, // Use primaryColor for Diagnose button
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildAnimatedButton(
                context,
                label: lang.askButton,
                icon: Icons.chat_bubble_outline,
                onTap: () => Navigator.pushNamed(context, '/llmChat'),
                color:
                    appSecondaryColor, // Use appSecondaryColor for Ask button
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildAnimatedButton(
                context,
                label: lang.history,
                icon: Icons.history,
                onTap: () => Navigator.pushNamed(context, '/history'),
                color: accent, // Use accent for History button
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildAnimatedButton(
                context,
                label: lang.settings,
                icon: Icons.settings,
                onTap: () => Navigator.pushNamed(context, '/settings'),
                color:
                    secondaryTxtColor, // Use secondaryTxtColor for Settings button
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnimatedButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _buttonHeight,
      child: Card(
        color: cardColor, // Use cardColor from colors.dart
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: borderColor,
            width: 1,
          ), // Use borderColor from colors.dart
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: color),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
