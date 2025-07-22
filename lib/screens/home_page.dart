import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:krishidoc/screens/classifying_page.dart';
import '../widgets/language_selector.dart';
import '../utils/constants.dart';
import '../providers/settings_provider.dart';
import 'package:provider/provider.dart';
import '../providers/disease_provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // — make all buttons the same height
  static const double _buttonHeight = 140;

  Future<void> _pickImageAndDetect(BuildContext context) async {
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
ListTile(
  leading: const Icon(Icons.camera_alt),
  title: const Text('Capture Photo'),
  onTap: () async {
    Navigator.pop(context);
    final picked = await picker.pickImage(source: ImageSource.camera);
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
                title: const Text('Select from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final picked =
                      await picker.pickImage(source: ImageSource.gallery);
                  if (picked != null) {
     // now match the camera flow:
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

    return Scaffold(
      // gentle gradient using your primary & background colors
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withOpacity(0.2),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, settings),
                const SizedBox(height: 32),
                Text(
                  AppStrings.welcome,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.welcomeSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                // fixed-height grid
                _buildButtonGrid(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SettingsProvider settings) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          AppStrings.appName,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        LanguageSelector(
          selected: settings.language,
          onChanged: (lang) => settings.setLanguage(lang),
        ),
      ],
    );
  }

  Widget _buildButtonGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAnimatedButton(
                context,
                label: AppStrings.diagnoseButton,
                icon: Icons.camera_alt_rounded,
                onTap: () => _pickImageAndDetect(context),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildAnimatedButton(
                context,
                label: AppStrings.askButton,
                icon: Icons.chat_bubble_outline,
                onTap: () => Navigator.pushNamed(context, '/llmChat'),
                color: Theme.of(context).colorScheme.secondary,
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
                label: AppStrings.history,
                icon: Icons.history,
                onTap: () => Navigator.pushNamed(context, '/history'),
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildAnimatedButton(
                context,
                label: AppStrings.settings,
                icon: Icons.settings,
                onTap: () => Navigator.pushNamed(context, '/settings'),
                color:Theme.of(context).colorScheme.tertiary,
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
      // use the default surface color
      color: theme.colorScheme.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        // subtle border using your accent color
        side: BorderSide(color: color.withOpacity(0.3), width: 1),
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
