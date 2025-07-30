import 'package:flutter/material.dart';
import 'package:krishidoc/locale/base_language_key.dart';
import 'package:krishidoc/locale/language_ar.dart';
import 'package:krishidoc/locale/language_de.dart';
import 'package:krishidoc/locale/language_en.dart';
import 'package:krishidoc/locale/language_fr.dart';
import 'package:krishidoc/locale/language_hi.dart';
import 'package:krishidoc/locale/language_np.dart';
import 'package:nb_utils/nb_utils.dart';
import '../locale/app_localizations.dart';

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
    final BaseLanguage lang = BaseLanguage.of(context);

    return DropdownButton<String>(
      value: selected,
      items: [
        DropdownMenuItem(
          value: 'en',
          child: Text(
            'English',
            style: primaryTextStyle(),
            textDirection: lang is LanguageEn ? TextDirection.rtl : TextDirection.ltr,
          ),
        ),
        DropdownMenuItem(
          value: 'np',
          child: Text(
            'नेपाली',
            style: primaryTextStyle(),
            textDirection: lang is LanguageNp ? TextDirection.rtl : TextDirection.ltr,
          ),
        ),
        DropdownMenuItem(
          value: 'de',
          child: Text(
            'Deutsch',
            style: primaryTextStyle(),
            textDirection: lang is LanguageDe ? TextDirection.rtl : TextDirection.ltr,
          ),
        ),
        DropdownMenuItem(
          value: 'fr',
          child: Text(
            'Français',
            style: primaryTextStyle(),
            textDirection: lang is LanguageFr ? TextDirection.rtl : TextDirection.ltr,
          ),
        ),
        DropdownMenuItem(
          value: 'hi',
          child: Text(
            'हिन्दी',
            style: primaryTextStyle(),
            textDirection: lang is LanguageHi ? TextDirection.rtl : TextDirection.ltr,
          ),
        ),
        DropdownMenuItem(
          value: 'ar',
          child: Text(
            'العربية',
            style: primaryTextStyle(),
            textDirection: TextDirection.rtl, // Always RTL for Arabic
          ),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
      dropdownColor: context.cardColor,
      borderRadius: BorderRadius.circular(8),
      underline: Container(),
    );
  }
}