# Accessibility and Mobile Conventions Review (Module 12 pre-review)

VERDICT: zero accessibility instrumentation. grep for Semantics|semanticLabel|liveRegion|HapticFeedback|SafeArea|SystemChrome across app/lib and packages/*/lib returns ONE hit (SafeArea at capture_screen.dart:265). Touch targets are the one thing that genuinely passes: measured 48x48 on every interactive element. Everything else has a measured failure behind it.

## MEASURED CRASHES (not theoretical)
**Real RenderFlex overflowed exceptions fired** from home_screen.dart:114:
- 412x915 at textScale 1.15+
- 360x800 (the most common low-end resolution in this market) at **scale 1.0**
- 320x640 at **default settings**: three separate overflow exceptions (87px, 63px, 15px)
Mechanism: childAspectRatio derives tile height from WIDTH. On 412x915 the content box is 142x112dp; fixed icon 32 + gap 8 leaves 72dp for the label; titleMedium line box is 24dp so 3 lines at 1.0 and ONE line at 2.0. "रोग पहिचान गर्नुहोस्" cannot render on one line in 142dp at 32sp. AndroidManifest includes fontScale in configChanges so the black-and-yellow stripes appear LIVE as the user drags the slider.

## THE SHUTTER IS UNDER THE SYSTEM NAV BAR
capture_screen.dart:136-164 has no SafeArea; targetSdk resolves to 35, so Android 15 draws edge-to-edge with no opt-out and main.dart never calls SystemChrome. Measured shutter rect (16,851)-(396,899) on 412x915 = **16dp bottom clearance**. Gesture inset is 24dp; 3-button nav is 48dp. So the bottom 8dp is inside the gesture exclusion zone and **32 of its 48dp sit behind a 3-button nav bar**. Flutter's Scaffold keeps padding.bottom in the body's MediaQuery but never insets the body box. FIX: SafeArea(top: false). S / High.

## Accessibility failures (measured)
1. **Diagnosis certainty is invisible to a screen reader.** Semantics dump: label = "tomato_late_blight\nMar 2, 2026 2:45 PM", flags hasSelectedState/hasEnabledState/isEnabled, NO actions entry. All three states produce BYTE-IDENTICAL flag sets. In Nepali the row still announces tomato_late_blight. M / High.
2. **History rows have no tap action**: no actions in the semantics node, the entire 380x92dp row is inert, TalkBack gives no "double-tap to activate". S / High.
3. Home grid overflow (above). M / High.
4. Shutter under nav bar (above). S / High.
5. **Coaching is not a live region and there is no haptic anywhere.** Banner produces a bare node with no liveRegion flag, so TalkBack announces NEITHER "Hold steady" NOR "Ready". Shutter flips enabled silently. grep HapticFeedback|Vibration = zero hits repo-wide. A farmer holding a plant and not looking gets no signal the frame became acceptable. S / High.
6. **Token rationale measured against a surface the app never paints.** Computed ColorScheme.fromSeed(0xFF1B5E20) tonalSpot light with material_color_utilities 0.11.1 (the exact algorithm Flutter 3.32 uses): primary **#3C6939**, surface #F7FBF1, surfaceContainerLow #F1F5EB, onSurface #191D17, onSurfaceVariant #424940. KdColors.primary is NEVER painted on a button. KdColors.surface and KdColors.danger are declared and referenced NOWHERE. Stated vs actual: primary 8.6 claimed / **7.87** actual; warning 4.8 / **5.43**; danger 5.9 / **6.47**; textSecondary 8.4 / **9.36**. No test asserts any of it. M / Med.
7. **Colour-blind users cannot separate the three History states.** Pairwise: confident vs uncertain **1.45:1**, uncertain vs out-of-scope **1.72:1**, confident vs out-of-scope **1.19:1**. Deuteranope simulation: 1.74, 1.92, **1.11:1**. Glyph shapes differ so 1.4.1 is technically met, but at 24dp a tick-in-circle vs question-in-circle on 720p outdoors is not a distinction this audience will make. Fails 1.1.1 and 1.3.1. S / High.
8. **Icons never scale with the font setting.** At textScale 2.0 the home label renders at 32sp while the icon stays exactly 32.0dp. Android's Font size slider does not scale icons; only Display size does. S / Med.
9. **The disabled shutter is invisible, and disabled is its DEFAULT state.** M3 disabled tokens give label #A3A79E on fill #DCE0D7 = **1.83:1**, fill vs page **1.28:1**. WCAG exempts disabled controls, but the most important control on the most important screen is a barely visible ghost for as long as the frame is bad, with no text explaining why. S / Med.
10. Selected crop signalled only by an unlabelled check; sheet announces the generic "Dialog" with no title string in any ARB. S / Med.
11. **Language is a globe glyph in the hardest-to-reach corner** with tooltip but NO label, no selected indicator on any menu item, no first-run picker. S/M / High for the target user.
12. No dark or high-contrast theme; values-night/styles.xml exists so a device in dark mode shows a BLACK splash then flashes to #F7FBF1. S / Med.

NOT a failure, worth recording: every interactive element measured >=48dp. DiagnosisResultView also scales cleanly, escalate button 48->60->160dp across 1.0/1.5/2.0 in both languages with ZERO overflow. **That screen is the model the home screen should copy.**

## Contrast failures (measured)
Card edge vs scaffold **1.05:1** (tile edges rely entirely on a 1dp shadow). Disabled shutter label 1.83:1, fill vs page 1.28:1. State separation 1.45 / 1.72 / **1.19**. Deuteranope 1.74 / 1.92 / **1.11**. Banner READY vs NOT-READY fill **1.99:1** (white frame) and **1.87:1** (black frame): the ready state is carried almost entirely by the glyph.

Sunlight veiling-glare model: body text 16.29 -> 6.82 (shade) -> 4.02 (bright overcast) -> **2.67 (open sun)**; green accent drops below 3:1 at ~0.22 veil. For a field app the palette wants near-black on PURE WHITE, not #191D17 on #F7FBF1, and tile boundaries need a real outline rather than a shadow.

## Mobile convention violations
- **A 2x2 tile grid is not the Android pattern for four top-level destinations.** M3 prescribes NavigationBar for 3-5. This is the government-portal / web-dashboard pattern: every destination costs tap tile, push route, read app bar, hit back arrow top-left. grep NavigationBar|BottomNavigationBar|NavigationRail|TabBar|Drawer|FloatingActionButton = **zero hits**.
- The primary action is a card, not a FAB or bottom-anchored button, in an app whose one job is "photograph a leaf".
- No SafeArea outside one bottom sheet, with edge-to-edge forced by targetSdk 35.
- Predictive back not enabled (no enableOnBackInvokedCallback, no PopScope): reads as a stale app on Android 15.
- Modal sheet has no drag handle and no title; announces as "Dialog".
- **Landscape is broken**: at 915x412 tiles become 433x361dp, the second row starts at y=521 in a 356dp body, so History and Settings are entirely below the fold. Same on an open foldable. No orientation lock, no breakpoint logic.
- Untranslated user-visible strings: 'Prepared $bytes bytes', 'Camera preview (debug)'.
- No state restoration: no restorationScopeId, no RestorationMixin. On 2GB devices Android kills the process aggressively and the user returns to a cold home screen.

## Thumb reach (412x915, right hand, pivot ~(350,915))
The primary action "Identify disease" is the **FURTHEST** of the four tiles from the thumb at 691dp, and it is in the left column, the worst column for a right hand. Every control sits in the top 56%; **the comfortable bottom 404dp (44% of the display) is blank**. The language control at (388,28) is 887dp away, the single worst point on the screen, and it is the only way a Nepali-only user escapes English.
Capture gets this RIGHT: shutter centre (206,875) is **149dp** from the pivot and spans the full width, reachable with either thumb without regripping; the crop sheet sits entirely in the easy zone. Its only defect is the 16dp bottom clearance.
RECOMMENDED: move destinations into a bottom NavigationBar (all four then land inside a 150dp radius), promote the camera to a bottom-anchored primary button or extended FAB, move language out of the top-right into Settings plus a first-run screen.
