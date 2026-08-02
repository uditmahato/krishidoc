import 'package:go_router/go_router.dart';

import 'capture/capture_screen.dart';
import 'diagnosis/result_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'result_preview_screen.dart';

abstract final class AppRoutes {
  static const String home = '/';
  static const String capture = '/capture';
  static const String history = '/history';

  /// A result is addressed by the id of the record it renders, so the screen
  /// reads stored state rather than being handed a value that could disagree
  /// with what History shows.
  static const String resultBase = '/result';
  static const String result = '$resultBase/:id';

  static const String devResultPreview = '/dev/result-preview';
}

/// Router is created per app instance (never a module-level singleton) so
/// navigation state cannot leak between instances, including in tests.
GoRouter createAppRouter() => GoRouter(
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.capture,
      builder: (context, state) => const CaptureScreen(),
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
