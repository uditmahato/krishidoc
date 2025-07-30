import 'package:flutter/material.dart';
import 'package:krishidoc/locale/localization.dart';


class LanguageSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const LanguageSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: selected,
      onChanged: (String? newValue) {
        if (newValue != null) {
          onChanged(newValue);
        }
      },
      items: SupportedLanguages.codes.map((code) {
        return DropdownMenuItem<String>(
          value: code,
          child: Text(SupportedLanguages.getName(code)),
        );
      }).toList(),
    );
  }
}