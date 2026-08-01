# Improvement Plan (pre-Module 12)

Produced under the Product Excellence Operating System, before any code, from six product reviews: Chief Product Officer, UX Researcher, UI Designer, Interaction and Motion, Accessibility and Mobile Conventions, Cognitive Load and Trust. Full reports are archived with this plan.

## 1. Facts I verified myself

Two reviews disagreed on the seeded palette, so I measured it rather than trusting either.

```
SEED_TOKEN          = #1B5E20   (what tokens.dart declares)
scheme.primary      = #3C6939   (what every button and icon actually paints)
scheme.surface      = #F7FBF1
surfaceContainerLow = #F1F5EB   (card fill)
TOKEN_IS_PAINTED    = false
```

The audited colour has never been on screen. Card fill against scaffold is `#F1F5EB` on `#F7FBF1`, which is **1.05:1**: card edges are carried entirely by a 1dp shadow, the first thing to vanish on a cheap LCD in sunlight. Four contrast figures in my own token comments are wrong, and the headline one is overstated in the flattering direction (claimed 8.6:1, actual 7.87:1). I wrote those comments while criticising V1 for exactly this class of decorative claim.

## 2. The strategic question, and my answer

The reviews pull two ways. The CPO says stop polishing and ship content, because eleven modules have produced zero user-reachable value and the top risk on our own register has no code and no content against it. The design reviews say the foundation is broken and must be rebuilt first.

These only look opposed. The resolution:

**The CPO is right about direction and I am adopting it. The design work is the prerequisite, not the alternative.**

A handbook rendered on invisible cards, with Devanagari at English line metrics, on a home screen that overflows at default settings on a 320dp phone, is not a shippable handbook. The foundation work is small (measured in days) and every future screen inherits it. But content itself is the long pole, it is a human editorial process, and it needs agronomists that only you can engage. That is R1, and no amount of coding retires it.

So: I build the foundation and the shell; you unblock the content. Both start now.

**Sequencing decision:** advisory content moves ahead of sync, identity, and consent, per the CPO. Backend identity work is frozen until a shipped feature makes a network call. The chatbot is cut from the near-term roadmap in favour of offline knowledge-base search, which D-05 already promises as the degraded mode.

## 3. P0: measured defects, not opinions

These are bugs with reproductions, not preferences.

| # | Defect | Evidence |
|---|---|---|
| P0-1 | Home tiles overflow at default settings on common hardware | Real `RenderFlex overflowed` exceptions: 320x640 at scale 1.0 (three separate, 87px/63px/15px), 360x800 at scale 1.0, 412x915 at 1.15+. `childAspectRatio` derives height from width, so the overflow is inside a box the scroll view cannot grow. My comment claiming the ListView fixed font-scale clipping is wrong: it fixed the page, not the tile. |
| P0-2 | The shutter sits under the system navigation bar | Measured rect gives 16dp bottom clearance. Gesture inset is 24dp; a 3-button nav bar is 48dp, so 32 of the shutter's 48dp are behind it. `targetSdk 35` forces edge-to-edge with no opt-out and nothing calls `SystemChrome`. |
| P0-3 | Audited tokens are never painted | Verified above. |
| P0-4 | Zero accessibility instrumentation | One `SafeArea` in the entire repo; no `Semantics`, no `semanticLabel`, no `liveRegion`, no haptics. All three History states announce byte-identical flags, and the announced title is the raw English classifier key even in Nepali. |
| P0-5 | One certainty band | `certaintyVeryLikely` is the only certainty string; `topProbability` is computed and never read by any UI. A 0.62 and a 0.98 speak identically. The app looks calibrated while being uncalibrated. |
| P0-6 | The confident card has no action and no correction path, pinned by a test I wrote | `diagnosis_result_view_test.dart` asserts no buttons exist on it. Confident-and-wrong is the case that costs money and puts chemicals on a healthy crop, and it is the only state with no escape. |
| P0-7 | Out-of-scope blames the farmer's photo | The resolver fires it when nothing matched; quality failures never reach it because the shutter is gated first. The message sends farmers into a retake loop that cannot succeed. |
| P0-8 | Isolate spawn lands inside the shutter flash | `Isolate.run` per capture costs 50 to 150 ms plus byte copies, at the exact moment of highest anxiety, making the tap the most jank-prone point in the app. |
| P0-9 | Language is inferred from device locale | Handsets in this market ship configured in English. A Nepali-only reader meets an English app whose one escape is an unlabelled globe in the furthest-to-reach corner, and the persisted read lands after the first frame so even returning users see a wrong-language flash. |

## 4. Module 12: Foundations that everything else inherits

Scope chosen because every later screen depends on it and because it clears four P0s.

1. **Real tokens.** Explicit `ColorScheme`, no seeding. Correct the four wrong ratios. Add `KdRadius`, `KdElevation`, `KdIconSize`, `KdMotion`, and an expanded `KdSpacing` plus `KdLayout`.
2. **A contrast test that makes the palette falsifiable**, in the same spirit as the sealed result states: every semantic pair asserted, so a comment can never drift from reality again.
3. **`KdType` with a locale-aware Devanagari column.** Flutter's `tall2021` is byte-identical to `englishLike2021`, so we currently ship 22sp Devanagari at 1.27 line height with 0.5 letter spacing, which collides matras and breaks the shirorekha. Line-height floor 1.45, letter spacing 0, even leading distribution.
4. **Fix P0-1 and P0-2**: intrinsic tile height, `SafeArea` on the capture bottom bar, icons that scale with the text scaler.
5. **Accessibility instrumentation**: `Semantics` on every interactive and state-bearing surface, `liveRegion` on the coaching banner, haptics per the agreed map.
6. **Golden tests at 1.0, 1.5 and 2.0 scale in Nepali**, not English, so P0-1 can never return silently.

## 5. Queue

**Module 13, First Contact.** First-run language chooser as three large targets in their own scripts. Three-card onboarding teaching what the app checks, that the gate turns green when the photo is good, and that "not sure" is a real answer with a human one tap away. Coverage stated plainly on Home. Dead tiles that look dead instead of a snackbar that can cover the only working tile. Empty History becomes the funnel rather than the terminal state.

**Module 14, The Handbook Shell.** Browse by crop and by what the farmer can see. `KdStateCard`, `KdEmptyState`, `KdListRow`, `KdCertaintyBadge` with owned contrast. A content schema plus one fully worked entry as the template agronomists fill. This is the CPO's offline handbook, minus the content only humans can write.

**Module 15, Motion and the capture choreography.** The eight-beat sequence, hysteresis on the coaching signal, the preparation wait covered, the isolate moved off the flash, the hero from photo to result.

**Always-on:** every module ends with a Product Dashboard and a memory update.

## 6. Blocked, and by whom

- **Content (R1, top risk):** needs agronomists. Yours to unblock, and the single highest-value action available to the project.
- **Model:** needs a trained `.tflite` plus labels. Until then no diagnosis can complete.
- **Camera on hardware:** phone disconnected mid-Module 11; the code is committed and unverified.
- **Postgres:** Docker Desktop would not start.
- **Nepali and Hindi wording:** every rewrite in these reviews is a proposal pending the D-06 native agronomist gate. Certainty strings especially must go to review as complete sentences, never as fragments.

## 7. Explicitly deferred, with reasons

Bottom navigation and the home restructure (correct per Material, but it should land with the handbook that gives it destinations worth navigating to). Dark theme (state `themeMode` explicitly so its absence is a decision). Custom pictograms and illustrations (needs a designer; highest craft-per-rupee item in the review). Shimmer (refused outright: a full-width `ShaderMask` sweep at 60fps is decorative cost on this hardware).
