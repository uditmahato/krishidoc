import 'dart:math' as math;
import 'dart:ui';

/// WCAG 2.1 relative luminance and contrast ratio.
///
/// This lives in the library rather than in a test helper on purpose. V1
/// shipped 1.7:1 yellow on white, and V2's first token file then carried four
/// contrast figures in comments that were all wrong, the headline one
/// overstated in the flattering direction. A number written in a comment is a
/// claim nobody can check; a function the test suite calls is a claim that
/// fails the build when it drifts.
///
/// Verified against the canonical reference pairs before use: black on white
/// is 21.00, #767676 on white is 4.54, white on #808080 is 3.95. Those three
/// are asserted in `contrast_test.dart` so a regression in this maths shows up
/// as a broken calculator rather than as a silently permissive palette.
double relativeLuminance(Color color) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// Contrast ratio between two opaque colours, from 1.0 to 21.0.
///
/// Both colours must be opaque. A translucent fill has no single ratio,
/// because what it contrasts against depends on whatever happens to be behind
/// it, which for the capture screen is a live camera frame. That is precisely
/// why the coaching banner is opaque.
double contrastRatio(Color a, Color b) {
  assert(a.a == 1.0, 'contrastRatio needs an opaque colour, got alpha ${a.a}');
  assert(b.a == 1.0, 'contrastRatio needs an opaque colour, got alpha ${b.a}');
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}
