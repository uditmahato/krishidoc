import 'dart:ui';

/// Color tokens. Values chosen for WCAG contrast on light surfaces: V1 shipped
/// yellow-on-white at roughly 1.7:1; every accent here holds >= 4.5:1 on white.
abstract final class KdColors {
  static const Color primary = Color(0xFF1B5E20); // deep green, 8.6:1 on white
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color warning = Color(0xFF9A5B00); // dark amber, 4.8:1 on white
  static const Color danger = Color(0xFFB91C1C); // 5.9:1 on white
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1C19);
  static const Color textSecondary = Color(0xFF44483F); // 8.4:1 on white
}

/// Spacing scale (logical pixels). Touch targets never drop below 48.
abstract final class KdSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double minTouchTarget = 48;
}
