import 'package:flutter/material.dart';
import '../utils/localization.dart';

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
      items: SupportedLanguages.codes
          .map((code) => DropdownMenuItem(
                value: code,
                child: Text(SupportedLanguages.names[code]!),
              ))
          .toList(),
      // Wrap onChanged to handle nullable
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
      underline: Container(height: 2, color: Theme.of(context).primaryColor),
    );
  }
}
