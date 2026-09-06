import 'package:core_domain/core_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'l10n/gen/app_localizations.dart';
import 'src/app_services.dart';
import 'src/diagnosis/photo_store.dart';
import 'src/locale_scope.dart';
import 'src/market/market.dart';
import 'src/providers.dart';
import 'src/router.dart';
import 'src/welcome/first_run.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.open();
  final photos = await FilePhotoStore.open();
  MarketSnapshotCache marketCache;
  try {
    marketCache = await FileMarketSnapshotCache.open();
  } on Object {
    // A read-only or damaged support directory must not stop the app from
    // loading live prices; only cold-start offline availability is reduced.
    marketCache = MemoryMarketSnapshotCache();
  }
  // Read the saved language BEFORE the first frame. Restoring it afterwards
  // meant a Nepali-only user saw an English home screen flash on every cold
  // start, and the type theme is locale dependent, so the first frame also
  // laid Devanagari out on Latin metrics before correcting itself. Twenty
  // milliseconds more splash is a straight trade for neither happening.
  // A launch override for the screen review cycle: reviewing Nepali and Hindi
  // screens on a device otherwise needs a system language change, which is
  // blocked on an emulator and is a poor reason to touch a real phone's
  // settings. Empty by default, so a normal build is unaffected.
  //   flutter run --dart-define=KD_LOCALE=ne
  //
  // It now supplies the routing decision as well as the rendered locale, so a
  // review build on a fresh install still lands on the screen under review
  // instead of on the chooser. KD_FIRST_RUN=1 asks for the opposite, which is
  // the only way to see the chooser twice without wiping app data.
  //   flutter run --dart-define=KD_LOCALE=ne --dart-define=KD_FIRST_RUN=1
  const localeOverride = String.fromEnvironment('KD_LOCALE');
  const forceFirstRun = String.fromEnvironment('KD_FIRST_RUN') == '1';

  // Read the saved language BEFORE the first frame. Restoring it afterwards
  // meant a Nepali-only user saw an English home screen flash on every cold
  // start, and the type theme is locale dependent, so the first frame also
  // laid Devanagari out on Latin metrics before correcting itself. Twenty
  // milliseconds more splash is a straight trade for neither happening.
  final stored = localeOverride.isEmpty
      ? await services.settingsStore.read(SettingsKeys.selectedLanguage)
      : localeOverride;
  final saved = AppLanguage.fromCode(stored);

  runApp(
    ProviderScope(
      overrides: [
        servicesProvider.overrideWithValue(services),
        photoStoreProvider.overrideWithValue(photos),
        marketSnapshotCacheProvider.overrideWithValue(marketCache),
      ],
      child: KrishiDocApp(
        initialLocale: saved == null ? null : Locale(saved.code),
        initialLocation: forceFirstRun
            ? AppRoutes.welcomeLanguage
            : initialLocationFor(stored),
      ),
    ),
  );
}

class KrishiDocApp extends ConsumerStatefulWidget {
  const KrishiDocApp({
    this.initialLocale,
    this.initialLocation = AppRoutes.home,
    super.key,
  });

  /// The language to render in. Null means none has been chosen, in which
  /// case the device locale applies to the few strings shown before the
  /// chooser is answered.
  final Locale? initialLocale;

  /// Where the app opens. Resolved before `runApp` from the same stored value
  /// as [initialLocale], so the two cannot disagree about whether this reader
  /// has answered the chooser.
  final String initialLocation;

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
    _router = createAppRouter(initialLocation: widget.initialLocation);
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  /// Applies the language, then returns once it is durable.
  ///
  /// The repaint is synchronous, so the screen changes with the tap. The
  /// await is for the caller that navigates on completion: the chooser must
  /// not be able to hand the reader to the next screen in a state where the
  /// language is on screen but not on disk.
  Future<void> _setLocale(Locale locale) async {
    setState(() => _locale = locale);
    try {
      await ref
          .read(servicesProvider)
          .settingsStore
          .write(SettingsKeys.selectedLanguage, locale.languageCode);
    } catch (_) {
      // Never trap the farmer behind a storage error on the first screen.
      // The in-memory locale is already applied, so the app is usable in the
      // language they picked; the accepted consequence is that the chooser
      // reappears on the next cold start.
    }
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
