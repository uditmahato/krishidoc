import 'dart:async';

import 'package:core_domain/core_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'l10n/gen/app_localizations.dart';
import 'src/app_services.dart';
import 'src/locale_scope.dart';
import 'src/providers.dart';
import 'src/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.open();
  runApp(
    ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services)],
      child: const KrishiDocApp(),
    ),
  );
}

class KrishiDocApp extends ConsumerStatefulWidget {
  const KrishiDocApp({this.initialLocale, super.key});

  /// Explicit override (tests). When null, the persisted choice is restored
  /// from the settings store; absent that, the device locale applies.
  final Locale? initialLocale;

  @override
  ConsumerState<KrishiDocApp> createState() => _KrishiDocAppState();
}

class _KrishiDocAppState extends ConsumerState<KrishiDocApp> {
  Locale? _locale;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
    _router = createAppRouter();
    if (_locale == null) {
      unawaited(_restorePersistedLocale());
    }
  }

  Future<void> _restorePersistedLocale() async {
    final store = ref.read(servicesProvider).settingsStore;
    final saved = AppLanguage.fromCode(
      await store.read(SettingsKeys.selectedLanguage),
    );
    if (saved != null && mounted && _locale == null) {
      setState(() => _locale = Locale(saved.code));
    }
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  void _setLocale(Locale locale) {
    setState(() => _locale = locale);
    final store = ref.read(servicesProvider).settingsStore;
    unawaited(store.write(SettingsKeys.selectedLanguage, locale.languageCode));
  }

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
