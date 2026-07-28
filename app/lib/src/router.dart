import 'package:go_router/go_router.dart';

import 'history_screen.dart';
import 'home_screen.dart';
import 'result_preview_screen.dart';

// CaptureScreen is built and tested but deliberately unrouted: it needs a
// CameraSession, and no platform implementation exists yet. Registering the
// route now would mean either a crash on entry or a misleading "allow camera
// access" message. The route lands with the camera implementation.

abstract final class AppRoutes {
  static const String home = '/';
  static const String history = '/history';
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
      path: AppRoutes.history,
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: AppRoutes.devResultPreview,
      builder: (context, state) => const ResultPreviewScreen(),
    ),
  ],
);
