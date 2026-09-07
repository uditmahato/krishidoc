import 'package:flutter/animation.dart' show Curve, Curves;
import 'package:flutter/painting.dart' show BoxShadow, Color, Offset;

/// Colour tokens.
///
/// Functional foreground/background pairs are asserted in
/// `test/contrast_test.dart`. Decorative tones are deliberately kept out of
/// those pairings rather than being mistaken for readable text colours.
///
/// Two constraints shaped the palette and are worth stating because they are
/// not obvious:
///
/// 1. **The app is used in open sunlight.** Veiling glare compresses on-screen
///    contrast hard, so body text sits near black on near white. Form controls
///    and safety states retain strong boundaries; editorial cards may use
///    spacing, a soft edge and depth because they are not input affordances.
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
  /// Warm page background. The slight soil tint keeps the product from
  /// looking clinical while preserving strong outdoor contrast.
  static const Color canvas = Color(0xFFF7F5EC);

  /// Card and sheet fill.
  static const Color surface = Color(0xFFFFFEFA);

  /// A warmer surface for branded and editorial sections.
  static const Color surfaceWarm = Color(0xFFFFF8E8);

  /// Recessed fill: disabled controls, skeletons, inactive tracks.
  static const Color surfaceSunken = Color(0xFFE8ECE2);

  /// Functional control and safety-state boundary. It clears the 3:1
  /// non-text minimum on the surfaces where it is used.
  static const Color border = Color(0xFF7C8474);

  /// Decorative separation for cards. Unlike [border], this is not used as
  /// the only edge of a form control or safety-critical status.
  static const Color outlineSoft = Color(0xFFD6DCCF);

  // Ink.
  /// Headings; held near black for sunlight readability.
  static const Color inkStrong = Color(0xFF12140F);

  /// Body copy; held near black for sunlight readability.
  static const Color inkBody = Color(0xFF1A1C19);

  /// Secondary copy: timestamps and captions.
  static const Color inkMuted = Color(0xFF44483F);

  /// Disabled label. 5.01:1 on [surfaceSunken], which is deliberate: WCAG
  /// exempts disabled controls, but the most important control in this app
  /// (the shutter) is disabled by default, and a farmer who cannot read the
  /// coaching text must still see a button rather than a ghost. Disabled has
  /// to read as "not yet", never as "broken".
  static const Color inkDisabled = Color(0xFF5A6353);

  // Brand.
  /// Main action colour; audited on surface, canvas and white text.
  static const Color primary = Color(0xFF1B5E20);

  /// Pressed and high-emphasis variant.
  static const Color primaryPressed = Color(0xFF123F24);

  /// Tinted primary fill for quiet emphasis.
  static const Color primarySoft = Color(0xFFE1F0DE);
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Bright tonal green reserved for the product's primary crop action.
  /// Dark ink on this surface measures well above AA; the colour is therefore
  /// usable in sunlight without falling back to a dark promotional banner.
  static const Color actionLeaf = Color(0xFFB9E9B2);

  /// Quiet persistent-navigation surface. It is intentionally distinct from
  /// both the page canvas and white cards without looking like a fourth card.
  static const Color navigation = Color(0xFFEEF1E5);

  // Product identity. These colours are used as fills and illustration
  // accents; body copy never relies on the lighter accents for contrast.
  static const Color brandForest = Color(0xFF0E3C28);
  static const Color brandLeaf = Color(0xFF4A7C42);
  static const Color brandGold = Color(0xFFF2C75C);
  static const Color brandGoldSoft = Color(0xFFFFF0BE);
  static const Color brandGoldInk = Color(0xFF5C4100);
  static const Color skySoft = Color(0xFFDDEBF1);
  static const Color skyInk = Color(0xFF244D5D);
  static const Color earthSoft = Color(0xFFF2E2D2);
  static const Color earthInk = Color(0xFF69401F);

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
  static const double pageGutter = KdSpacing.lmd;
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
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double hero = 32;
  static const double pill = 999;
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
    BoxShadow(color: Color(0x120E3C28), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> floating = <BoxShadow>[
    BoxShadow(color: Color(0x240E3C28), blurRadius: 24, offset: Offset(0, 10)),
  ];
}
