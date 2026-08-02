import 'package:core_domain/core_domain.dart';
import 'package:flutter/widgets.dart';

import '../../l10n/gen/app_localizations.dart';

/// One option on the language chooser.
///
/// Carries its own [locale] as well as its [language] because the endonym is
/// rendered in its own script regardless of what the app is currently showing,
/// and the type metrics for that script are looked up by locale.
final class LanguageChoice {
  const LanguageChoice(this.language, this.locale, this.name);

  final AppLanguage language;
  final Locale locale;

  /// Resolved against the generated localizations rather than stored as a
  /// string, so the endonyms stay inside the ARB review inventory (D-54). A
  /// Dart constant here would be a second user-visible string surface outside
  /// the D-06 gate, which this repo has been burned by before.
  final String Function(AppLocalizations) name;
}

String _ne(AppLocalizations l10n) => l10n.languageNameNe;
String _hi(AppLocalizations l10n) => l10n.languageNameHi;
String _en(AppLocalizations l10n) => l10n.languageNameEn;

/// Expected-frequency order, fixed, device independent, on every install.
///
/// Declared here rather than taken from [AppLanguage]'s own declaration order
/// so that reordering is a one-line change in one file, and asserted by test
/// so the argument is had once (D-53).
///
/// Deliberately NOT reordered by device locale: handsets in this market ship
/// configured in English by the shop, so the device locale is evidence about a
/// shopkeeper rather than about a reader. Reordering by it would destroy the
/// position memory that is a non-reader's most useful cue, and would put the
/// wrong option first exactly when the hint is wrong.
const kLanguageChoices = <LanguageChoice>[
  LanguageChoice(AppLanguage.ne, Locale('ne'), _ne),
  LanguageChoice(AppLanguage.hi, Locale('hi'), _hi),
  LanguageChoice(AppLanguage.en, Locale('en'), _en),
];
