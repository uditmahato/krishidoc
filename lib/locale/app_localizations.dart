import 'package:flutter/material.dart';
import 'package:krishidoc/locale/base_language_key.dart';
import 'package:krishidoc/locale/language_ar.dart';
import 'package:krishidoc/locale/language_de.dart';
import 'package:krishidoc/locale/language_en.dart';
import 'package:krishidoc/locale/language_fr.dart';
import 'package:krishidoc/locale/language_hi.dart';
import 'package:krishidoc/locale/language_np.dart';

import 'package:krishidoc/locale/localization.dart';

class AppLocalizations extends LocalizationsDelegate<BaseLanguage> {
  const AppLocalizations();
  

  @override
  Future<BaseLanguage> load(Locale locale) async {
    switch (locale.languageCode) {
      case 'en':
        return LanguageEn();
      case 'ar':
        return LanguageAr();
      case 'hi':
        return LanguageHi();
      case 'fr':
        return LanguageFr();
      case 'de':
        return LanguageDe();
      case 'ne':
        return LanguageNp();
      default:
        return LanguageEn();
    }
  }

  @override
  bool isSupported(Locale locale) => SupportedLanguages.codes.contains(locale.languageCode);

  @override
  bool shouldReload(LocalizationsDelegate<BaseLanguage> old) => false;
}