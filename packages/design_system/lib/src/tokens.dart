import 'package:flutter/animation.dart' show Curve, Curves;
import 'package:flutter/painting.dart' show BoxShadow, Color, Offset;

/// Colour tokens.
///
/// Every ratio noted below is asserted in `test/contrast_test.dart` against
/// the surface it is actually painted on. Nothing here is a remembered number:
/// the previous version of this file claimed 8.6:1 for the primary green when
/// the real figure is 7.87:1, and the theme then threw the token away and
/// seeded a different green anyway, so the audited colour had never once
/// reached the screen.
///
/// Two constraints shaped the palette and are worth stating because they are
/// not obvious:
///
/// 1. **The app is used in open sunlight.** Veiling glare compresses on-screen
///    contrast hard, so body text sits near black on near white rather than on
///    a tinted surface, and boundaries are drawn with a real border instead of
///    a shadow. A 1dp shadow is the first thing to disappear on a 720p LCD in
///    a field.
///
/// 2. **Colour cannot carry the three-way diagnosis state.** For a rail to
///    read as a boundary on white it needs at least 3:1 against white, which
///    caps its luminance. Three colours all inside that cap span at most about
///    3.5:1 between the extremes, so the middle one cannot clear 3:1 against
///    either neighbour. That is arithmetic, not a palette failure. State is
///    therefore carried by glyph, by text, and by layout, with colour as
///    support only. WCAG 1.4.1 asks for exactly this, and here it is forced.
abstract final class KdColors {
  // Surfaces.
  /// Page background. Slightly tinted so white cards read as raised.
  static const Color canvas = Color(0xFFF1F3EC);

  /// Card and sheet fill. Pure white maximises text contrast in sunlight.
  static const Color surface = Color(0xFFFFFFFF);

  /// Recessed fill: disabled controls, skeletons, inactive tracks.
  static const Color surfaceSunken = Color(0xFFE4E7DC);

  /// Card and divider boundary. 3.88:1 on white and 3.47:1 on canvas, so it
  /// clears the 3:1 non-text minimum on both sides of every edge it draws.
  static const Color border = Color(0xFF7C8474);

  // Ink.
  /// Headings. 18.54:1 on white.
  static const Color inkStrong = Color(0xFF12140F);

  /// Body copy. 17.16:1 on white, 15.34:1 on canvas.
  static const Color inkBody = Color(0xFF1A1C19);

  /// Secondary copy: timestamps, captions. 9.36:1 on white.
  static const Color inkMuted = Color(0xFF44483F);

  /// Disabled label. 5.01:1 on [surfaceSunken], which is deliberate: WCAG
  /// exempts disabled controls, but the most important control in this app
  /// (the shutter) is disabled by default, and a farmer who cannot read the
  /// coaching text must still see a button rather than a ghost. Disabled has
  /// to read as "not yet", never as "broken".
  static const Color inkDisabled = Color(0xFF5A6353);

  // Brand.
  /// 7.87:1 on white, 7.03:1 on canvas.
  static const Color primary = Color(0xFF1B5E20);

  /// Pressed and high-emphasis variant. 10.79:1 on white.
  static const Color primaryPressed = Color(0xFF14471A);

  /// Tinted primary fill for quiet emphasis.
  static const Color primarySoft = Color(0xFFDCEBDA);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Semantic accents.
  /// 6.33:1 on white.
  static const Color warning = Color(0xFF8A5300);

  /// 7.52:1 on white.
  static const Color danger = Color(0xFFA61B1B);

  /// Neutral informational tone. 8.98:1 on white.
  static const Color slate = Color(0xFF3F4A5A);

  // Diagnosis state triplets. See the class note: these support the state,
  // they never encode it alone.
  static const Color stateConfidentRail = Color(0xFF14471A);
  static const Color stateConfidentBand = Color(0xFFDCEBDA);
  static const Color stateConfidentInk = Color(0xFF14401A); // 9.53:1 on band

  static const Color stateUncertainRail = Color(0xFF8A5300);
  static const Color stateUncertainBand = Color(0xFFFAECD8);
  static const Color stateUncertainInk = Color(0xFF6B3F00); // 7.73:1 on band

  static const Color stateOutOfScopeRail = Color(0xFF3F4A5A);
  static const Color stateOutOfScopeBand = Color(0xFFE6E9EE);
  static const Color stateOutOfScopeInk = Color(0xFF2B3441); // 10.33:1 on band

  // Capture coaching.
  //
  // Both fills are dark and opaque because the banner floats over a live
  // camera frame, which may be a white sheet of paper or an overcast sky. A
  // light "ready" fill measured 1.35:1 against white and would vanish over a
  // bright leaf. White text holds 7.87:1 and 15.35:1 respectively, so the
  // banner is always legible; readiness itself is signalled by the shutter
  // arming, by the glyph, and by the words, which are all larger and harder
  // to miss than a fill colour.
  static const Color coachReadyFill = Color(0xFF1B5E20);
  static const Color coachBusyFill = Color(0xFF23261F);
  static const Color coachInk = Color(0xFFFFFFFF);
}

/// Spacing scale in logical pixels.
///
/// The previous scale had four values with nothing between 8 and 16 and
/// nothing above 24, so separators, badge padding and icon gaps all rounded to
/// whatever was nearest and the app lost its rhythm.
abstract final class KdSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double smd = 12;
  static const double md = 16;
  static const double lmd = 20;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double xxxl = 56;

  /// Android's minimum touch target. This is a floor for interactive
  /// elements, never a layout height: using it as one is what left the crop
  /// chip at 32dp while the code read as if it were guarded.
  static const double minTouchTarget = 48;
}

/// Semantic layout constants. Screens use these; components use [KdSpacing].
/// Nothing outside the design system should write a raw number.
abstract final class KdLayout {
  /// Horizontal page margin. Card padding is deliberately smaller so that
  /// text inside a card still lines up with text outside one.
  static const double pageGutter = KdSpacing.md;
  static const double cardPadding = KdSpacing.md;
  static const double sectionGap = KdSpacing.lg;
  static const double itemGap = KdSpacing.smd;

  /// Bottom padding on scrollable pages, so the last item clears a
  /// bottom-anchored control instead of hiding under it.
  static const double scrollBottomInset = KdSpacing.xxxl;
}

/// Corner radii. The app previously used three unrelated corner languages on
/// one screen: 12 on cards, 8 on chips, and a fully round stadium on buttons.
abstract final class KdRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// Icon sizes.
///
/// These are multiplied by the text scaler at the call site. Android's font
/// size slider scales text and not icons, so a fixed icon beside scaling text
/// inverts their ratio at exactly the settings chosen by users who depend on
/// the icon most.
abstract final class KdIconSize {
  static const double sm = 20;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 48;

  /// The one glyph on a screen that has no heading: the language chooser and
  /// the empty History state. Added with two consumers rather than
  /// speculatively, because [KdElevation] and [KdMotion] are already recorded
  /// as defined-but-unconsumed debt and a third would make that the habit.
  static const double xxl = 64;
}

/// Motion durations and curves.
///
/// Defined before the first animation exists, because a duration invented at
/// the call site is how a design system drifts. Consumers must route every
/// duration through `kdDuration` so that Android's "Remove animations"
/// accessibility setting is honoured; it is disproportionately enabled on the
/// low-end hardware this app targets.
abstract final class KdMotion {
  static const Duration press = Duration(milliseconds: 100);
  static const Duration quick = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);

  /// Minimum time a coaching message stays on screen. The gate assesses at
  /// 5Hz, which is faster than a short Devanagari phrase can be read.
  static const Duration coachHold = Duration(milliseconds: 900);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
}

/// Elevation as explicit shadows.
///
/// Kept minimal on purpose. Shadows are the least reliable depth cue in
/// sunlight, so structure is carried by [KdColors.border] and every surface
/// here is legible with the shadow removed entirely.
abstract final class KdElevation {
  static const List<BoxShadow> none = <BoxShadow>[];
  static const List<BoxShadow> raised = <BoxShadow>[
    BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> floating = <BoxShadow>[
    BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 4)),
  ];
}
