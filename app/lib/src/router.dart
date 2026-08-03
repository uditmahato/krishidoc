import 'package:go_router/go_router.dart';

import 'capture/capture_screen.dart';
import 'diagnosis/result_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'notebook/notebook_screen.dart';
import 'notebook/observation_screen.dart';
import 'result_preview_screen.dart';
import 'welcome/welcome_about_screen.dart';
import 'welcome/welcome_language_screen.dart';

abstract final class AppRoutes {
  static const String home = '/';
  static const String capture = '/capture';
  static const String history = '/history';

  /// First contact. The chooser is unskippable by construction: it has no
  /// AppBar, no back and no skip, and it is reached by being the initial
  /// location rather than by being pushed onto something.
  static const String welcomeLanguage = '/welcome/language';

  /// What the app is for and what is not built yet. Reachable on first run
  /// with `?first=1`, and afterwards from Home and from empty History, which
  /// is why it is a real route rather than a page in an onboarding deck.
  static const String welcomeAbout = '/welcome/about';

  /// A result is addressed by the id of the record it renders, so the screen
  /// reads stored state rather than being handed a value that could disagree
  /// with what History shows.
  static const String resultBase = '/result';
  static const String result = '$resultBase/:id';

  /// The field notebook, and one entry within it. Reachable in a release
  /// build, unlike [result], because nothing here claims anything about a
  /// plant and so ADR-0052 does not reach it.
  static const String notebook = '/notebook';
  static const String observation = '$notebook/:id';

  static const String devResultPreview = '/dev/result-preview';
}

/// Router is created per app instance (never a module-level singleton) so
/// navigation state cannot leak between instances, including in tests.
///
/// [initialLocation] is the boot decision, computed by `initialLocationFor`
/// before `runApp` and handed straight to GoRouter. It is a parameter rather
/// than a redirect because a redirect would re-evaluate on every navigation
/// and would need to know when the first run had ended, which is exactly the
/// second piece of state this module refuses to store.
GoRouter createAppRouter({String initialLocation = AppRoutes.home}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.welcomeLanguage,
      builder: (context, state) => const WelcomeLanguageScreen(),
    ),
    GoRoute(
      path: AppRoutes.welcomeAbout,
      // `?first=1` rather than a second route, because it is the same screen
      // with one button added; two routes would be two things to keep in step.
      builder: (context, state) =>
          WelcomeAboutScreen(first: state.uri.queryParameters['first'] == '1'),
    ),
    GoRoute(
      path: AppRoutes.capture,
      // Notebook by default. `?diagnose=1` selects the classifying path,
      // which only a debug entry offers, because every answer it can give
      // today is a hash of the image bytes.
      builder: (context, state) => CaptureScreen(
        mode: state.uri.queryParameters['diagnose'] == '1'
            ? CaptureMode.diagnose
            : CaptureMode.notebook,
      ),
    ),
    GoRoute(
      path: AppRoutes.notebook,
      builder: (context, state) => const NotebookScreen(),
    ),
    GoRoute(
      path: AppRoutes.observation,
      builder: (context, state) =>
          ObservationScreen(observationId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: AppRoutes.history,
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: AppRoutes.result,
      builder: (context, state) =>
          ResultScreen(diagnosisId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: AppRoutes.devResultPreview,
      builder: (context, state) => const ResultPreviewScreen(),
    ),
  ],
);
