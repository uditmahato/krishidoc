import 'package:flutter/material.dart';
import 'package:krishidoc/locale/localization.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:provider/provider.dart'; // Add provider for state management

// Provider to manage selected language
class LanguageProvider extends ChangeNotifier {
  String _selectedLanguage = 'en';

  String get selectedLanguage => _selectedLanguage;

  void setLanguage(String languageCode, BuildContext context) {
    _selectedLanguage = languageCode;
    // Update app's locale
    // Assuming you have a method to update locale in your app
    // You may need to integrate with your localization system
    notifyListeners();
  }
}

class LanguageSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const LanguageSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  // Map language codes to their text directions
  static const Map<String, TextDirection> textDirections = {
    'en': TextDirection.ltr,
    'ne': TextDirection.ltr,
    'hi': TextDirection.ltr,
    'fr': TextDirection.ltr,
    'de': TextDirection.ltr,
    'ar': TextDirection.rtl,
  };

  @override
  Widget build(BuildContext context) {
    // Ensure selected is valid, fallback to first code if invalid
    String validSelected = SupportedLanguages.codes.contains(selected)
        ? selected
        : SupportedLanguages.codes.first;

    return DropdownButton<String>(
      value: validSelected,
      onChanged: (String? newValue) {
        if (newValue != null) {
          onChanged(newValue);
        }
      },
      items: SupportedLanguages.codes.map((code) {
        return DropdownMenuItem<String>(
          value: code,
          child: Text(
            SupportedLanguages.getName(code),
            style: primaryTextStyle(),
            textDirection: textDirections[code] ?? TextDirection.ltr,
          ),
        );
      }).toList(),
      dropdownColor: context.cardColor,
      borderRadius: BorderRadius.circular(8),
      underline: Container(),
    );
  }
}

class LanguageScreen2 extends StatefulWidget {
  @override
  _LanguageScreen2State createState() => _LanguageScreen2State();
}

class _LanguageScreen2State extends State<LanguageScreen2> {
  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    String selected = languageProvider.selectedLanguage;

    return Scaffold(
      appBar: AppBar(title: Text('Language Selection')),
      body: Center(
        child: LanguageSelector(
          selected: selected,
          onChanged: (String newSelected) {
            languageProvider.setLanguage(newSelected, context);
            print('Selected language: $newSelected');
          },
        ),
      ),
    );
  }
}