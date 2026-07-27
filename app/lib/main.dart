import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'l10n/gen/app_localizations.dart';
import 'src/locale_scope.dart';
import 'src/router.dart';

void main() {
  runApp(const KrishiDocApp());
}

class KrishiDocApp extends StatefulWidget {
  const KrishiDocApp({this.initialLocale, super.key});

  /// Test seam; production launch resolves the persisted choice once the
  /// settings store exists (M2) and falls back to the device locale.
  final Locale? initialLocale;

  @override
  State<KrishiDocApp> createState() => _KrishiDocAppState();
}

class _KrishiDocAppState extends State<KrishiDocApp> {
  Locale? _locale;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
    _router = createAppRouter();
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  void _setLocale(Locale locale) => setState(() => _locale = locale);

  @override
  Widget build(BuildContext context) {
    return LocaleScope(
      locale: _locale,
      setLocale: _setLocale,
      child: MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        theme: kdLightTheme(),
        routerConfig: _router,
        locale: _locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}
