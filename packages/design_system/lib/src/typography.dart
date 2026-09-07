import 'package:flutter/material.dart';

import 'tokens.dart';

/// Type scale, with a separate column for Devanagari.
///
/// Flutter ships `Typography.tall2021` for tall scripts, but in Material 3 it
/// is byte for byte identical to `englishLike2021`; the SDK's own comment says
/// M3 "does not include tall text themes". So a Nepali or Hindi build was
/// rendering Devanagari at English metrics: 22sp at line height 1.27, which
/// collides stacked matras between lines, and body text at 0.5 letter spacing,
/// which pulls apart the shirorekha, the horizontal line the script is read
/// along. Neither is a subtle refinement. Letter spacing in Devanagari is the
/// rough equivalent of spacing out the letters inside an English word.
///
/// Three rules for the Devanagari column, and they are not negotiable:
///
/// * line height at least 1.45, and 1.6 for body copy, because vowel signs
///   extend both above the shirorekha and below the baseline, so the ink of
///   one line reaches further than a Latin line of the same point size;
/// * letter spacing exactly zero, always;
/// * `TextLeadingDistribution.even`, so the extra leading is split above and
///   below rather than dumped under the baseline where it does nothing for
///   the matras that actually collide.
///
/// Known limitation, recorded rather than hidden: no font is bundled, so the
/// glyphs come from whatever the OEM ROM provides and the exact ink extents
/// vary by device. The heights below are chosen with headroom for that, but
/// bundling a Noto Sans Devanagari subset is the only way to make these
/// metrics deterministic. That is a tracked follow-up, not something this
/// module can assert.
abstract final class KdType {
  /// Scripts that need the tall column. Checked by script subtag first,
  /// because a Devanagari locale can be written with an explicit script code,
  /// then by language for the two we ship.
  static bool isTallScript(Locale locale) =>
      locale.scriptCode == 'Deva' ||
      const {'ne', 'hi', 'mr', 'sa'}.contains(locale.languageCode);

  static TextTheme forLocale(Locale locale) =>
      isTallScript(locale) ? _devanagari : _latin;

  static TextStyle _s(
    double size,
    FontWeight weight,
    double height,
    double spacing,
  ) => TextStyle(
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: spacing,
    leadingDistribution: TextLeadingDistribution.even,
    color: KdColors.inkBody,
  );

  // Sizes are shared between the two columns; only height and letter spacing
  // differ. Keeping the sizes identical means a layout that fits in English
  // has the same box in Nepali, so the extra ink is absorbed by leading rather
  // than by reflowing the screen into a different shape.
  static final TextTheme _latin = TextTheme(
    displaySmall: _s(38, FontWeight.w700, 1.16, -0.4),
    headlineMedium: _s(30, FontWeight.w700, 1.20, -0.2),
    headlineSmall: _s(24, FontWeight.w700, 1.25, -0.1),
    titleLarge: _s(22, FontWeight.w700, 1.28, 0),
    titleMedium: _s(18, FontWeight.w600, 1.33, 0.1),
    titleSmall: _s(16, FontWeight.w600, 1.38, 0.1),
    bodyLarge: _s(17, FontWeight.w400, 1.48, 0.1),
    bodyMedium: _s(15, FontWeight.w400, 1.48, 0.1),
    bodySmall: _s(14, FontWeight.w400, 1.45, 0.2),
    labelLarge: _s(16, FontWeight.w600, 1.25, 0.1),
    labelMedium: _s(14, FontWeight.w600, 1.30, 0.2),
    labelSmall: _s(12, FontWeight.w600, 1.35, 0.3),
  );

  static final TextTheme _devanagari = TextTheme(
    displaySmall: _s(38, FontWeight.w700, 1.45, 0),
    headlineMedium: _s(30, FontWeight.w700, 1.45, 0),
    headlineSmall: _s(24, FontWeight.w700, 1.48, 0),
    titleLarge: _s(22, FontWeight.w700, 1.50, 0),
    titleMedium: _s(18, FontWeight.w600, 1.52, 0),
    titleSmall: _s(16, FontWeight.w600, 1.55, 0),
    bodyLarge: _s(17, FontWeight.w400, 1.60, 0),
    bodyMedium: _s(15, FontWeight.w400, 1.60, 0),
    bodySmall: _s(14, FontWeight.w400, 1.60, 0),
    labelLarge: _s(16, FontWeight.w600, 1.45, 0),
    labelMedium: _s(14, FontWeight.w600, 1.45, 0),
    labelSmall: _s(12, FontWeight.w600, 1.50, 0),
  );

  /// Minimum line height the Devanagari column may use anywhere. Asserted in
  /// tests so a future edit cannot quietly reintroduce Latin metrics.
  static const double devanagariMinHeight = 1.45;
}
