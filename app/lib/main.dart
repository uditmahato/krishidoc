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
  // Read the saved language BEFORE the first frame. Restoring it afterwards
  // meant a Nepali-only user saw an English home screen flash on every cold
  // start, and the type theme is locale dependent, so the first frame also
  // laid Devanagari out on Latin metrics before correcting itself. Twenty
  // milliseconds more splash is a straight trade for neither happening.
  final saved = AppLanguage.fromCode(
    // A launch override for the screen review cycle: reviewing Nepali and
    // Hindi screens on a device otherwise needs a system language change,
    // which is blocked on an emulator and is a poor reason to touch a real
    // phone's settings. Empty by default, so a normal build is unaffected.
    //   flutter run --dart-define=KD_LOCALE=ne
    const String.fromEnvironment('KD_LOCALE').isEmpty
        ? await services.settingsStore.read(SettingsKeys.selectedLanguage)
        : const String.fromEnvironment('KD_LOCALE'),
  );
  runApp(
    ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services)],
      child: KrishiDocApp(
        initialLocale: saved == null ? null : Locale(saved.code),
      ),
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
        theme: kdLightTheme(locale: _locale ?? const Locale('en')),
        // The theme depends on the locale, because Devanagari needs its own
        // line metrics. When no language has been chosen the device locale
        // decides, and only Localizations knows what that resolved to, so the
        // theme is restated here once the answer exists.
        builder: (context, child) => Theme(
          data: kdLightTheme(locale: Localizations.localeOf(context)),
          child: child!,
        ),
        routerConfig: _router,
        locale: _locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}
