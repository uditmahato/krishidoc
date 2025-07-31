import 'package:flutter/material.dart';
import 'package:krishidoc/locale/localization.dart';
import 'package:nb_utils/nb_utils.dart';

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
