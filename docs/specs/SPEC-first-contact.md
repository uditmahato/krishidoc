# Module 13 Specification: First Contact

**Repo:** `C:/Users/chhay/Desktop/Personal/krishidoc` (branch `v2`). All paths absolute.

---

## 1. What Module 13 IS

Module 13 makes the app ask, before its first localisable sentence, which language the reader reads, and then tells that reader in plain words what this app is for and what is not built yet, on three surfaces that all say the same thing: Home, one About screen, and empty History. It deletes every tile that lies, deletes the snackbar that covered the only live tile, and makes a dead destination a compile error rather than a style choice.

---

## 2. Ordered build list

Sequenced so nothing ever links to a route that does not exist yet. Each step lands with its test.

### Step 1. Two tokens and five contrast assertions

**Files:** `packages/design_system/lib/src/tokens.dart`, `packages/design_system/test/contrast_test.dart`

- Add `KdIconSize.xxl = 64`. It is consumed twice this module (chooser glyph, empty-History glyph); do not add anything else. `KdElevation`/`KdMotion` are already recorded as defined-but-unconsumed debt (PROJECT_MEMORY:42) and a third unused token class repeats that.
- Add to `contrast_test.dart`, in the existing `expectRatio` style, only pairs the new surfaces actually paint (skip any already asserted):

| pair | minimum | measured |
|---|---|---|
| `inkDisabled` on `surfaceSunken` | 4.5 | 5.01 |
| `inkMuted` on `surfaceSunken` | 4.5 | 7.47 |
| `border` on `surfaceSunken` | 3.0 | 3.10 |
| `inkMuted` on `canvas` | 4.5 | 8.36 |
| `primary` on `canvas` | 3.0 | 7.03 |

**Test that proves it:** the assertions themselves. **Do not** add the inverted `lessThan(3.0)` assertions on `surface`/`surfaceSunken` — see cut list.

### Step 2. The boot decision, as one pure function

**Files:** `app/lib/src/welcome/first_run.dart` (new), `app/lib/src/router.dart`, `app/lib/main.dart`, `app/lib/src/locale_scope.dart`

`first_run.dart`, no Flutter import:

```dart
/// The whole first-run gate. One stored key, no second flag: two keys can
/// disagree and the disagreement would be invisible until a farmer hit it.
String initialLocationFor(String? storedLanguage) =>
    AppLanguage.fromCode(storedLanguage) == null
        ? AppRoutes.welcomeLanguage
        : AppRoutes.home;
```

A garbage stored value (`'bn'` written by a future build) returns null from `AppLanguage.fromCode` and lands on the chooser, which is the correct degraded behaviour and falls out for free.

`router.dart`: add `welcomeLanguage = '/welcome/language'` and `welcomeAbout = '/welcome/about'` to `AppRoutes`; change the factory to `createAppRouter({String initialLocation = AppRoutes.home})` passed straight to `GoRouter(initialLocation:)`.

`main.dart`:
- `KD_LOCALE` now supplies **both** the rendered locale and the routing decision, so a review build on a fresh install still lands on the screen under review. Add `KD_FIRST_RUN=1` to force the chooser. This keeps the only sanctioned visual-review path alive (PROJECT_MEMORY:105).
- Compute `initialLocation` with `initialLocationFor(stored)` and pass it to `KrishiDocApp({this.initialLocale, this.initialLocation = AppRoutes.home})`.
- **Delete `_restorePersistedLocale()` (lines 68 to 76) and the `unawaited(...)` call at lines 63 to 65.** Honest justification, not the unfounded race claim: `main()` resolves the stored value before `runApp`, so a null `initialLocale` on the production path can only mean the stored value was null, and the second read can only confirm null. It is dead code that a first-run write would now have to reason about. Its only remaining caller is `app_shell_test.dart:53-62`, rewritten in step 3.
- `_setLocale` becomes `Future<void>` and **awaits** the write:

```dart
Future<void> _setLocale(Locale locale) async {
  setState(() => _locale = locale);   // synchronous, so the repaint is instant
  try {
    await ref.read(servicesProvider).settingsStore
        .write(SettingsKeys.selectedLanguage, locale.languageCode);
  } catch (_) {
    // Never trap the farmer behind a storage error on the first screen. The
    // in-memory locale is already applied; the accepted consequence is that
    // the chooser reappears on the next cold start.
  }
}
```

`locale_scope.dart`: field type changes from `final ValueChanged<Locale> setLocale` to `final Future<void> Function(Locale locale) setLocale`. `updateShouldNotify` unchanged.

Do **not** pin `MaterialApp.locale` to `Locale('en')` on the chooser. Every visible string there styles itself; the only locale-dependent thing is the screen-reader label, and the device locale is the right answer for that.

**Test that proves it:** `app/test/first_run_test.dart`, pure, no widgets: `initialLocationFor(null)`, `('ne')`, `('bn')`, `('')`, `('NE')` over the full truth table.

### Step 3. The test helper, before any screen work

**File:** `app/test/helpers/pump_app.dart`

Add `bool firstRun = false`. Order inside `pumpApp`:

1. run the caller's `seed` (unchanged);
2. `var stored = await services.settingsStore.read(SettingsKeys.selectedLanguage);`
3. `if (stored == null && !firstRun) { stored = locale?.languageCode ?? 'en'; await services.settingsStore.write(SettingsKeys.selectedLanguage, stored); }`
4. `KrishiDocApp(initialLocale: Locale(stored ?? 'en')… , initialLocation: initialLocationFor(stored))` — when `firstRun` is true and `stored` is null, pass `initialLocale: null`.

This calls the **same** `initialLocationFor` that `main()` calls, so the helper is not a second implementation of the thing under test. Without this edit all 152 existing tests silently land on the chooser and pass or fail for reasons unrelated to what they assert.

`app_shell_test.dart:53-62` ("persisted language is restored on boot") now passes for a better reason than before: it seeds `'hi'`, the helper reads it, and the app boots Hindi through the real pre-`runApp` shape rather than through the deleted post-frame restore.

**Test that proves it:** run the full suite before and after this edit and confirm the same tests pass. Then add one case: `pumpApp(tester, firstRun: true)` lands on `WelcomeLanguageScreen`.

### Step 4. ARB keys

**Files:** `app/lib/l10n/app_en.arb`, `app_ne.arb`, `app_hi.arb`, then `flutter gen-l10n`

Full table in section 3. Deletions: `homeTagline`, `tileDiagnose`, `tileAsk`, `tileSettings`, `comingSoon`, `historyEmpty`. Keep `languageMenuTooltip`, `tileHistory`.

**Test that proves it:** `app/test/arb_guard_test.dart` reads all three ARBs and fails if any value contains `coming soon`, `चाँडै`, or `जल्द`. Stated honestly: this is a re-introduction guard, not a discovery test.

### Step 5. Language chooser

**Files:** `app/lib/src/welcome/language_choice.dart` (new), `app/lib/src/welcome/welcome_language_screen.dart` (new), `app/lib/src/router.dart`, `app/lib/src/home_screen.dart`

`language_choice.dart`:

```dart
final class LanguageChoice {
  const LanguageChoice(this.language, this.locale, this.name);
  final AppLanguage language;
  final Locale locale;
  final String Function(AppLocalizations) name;
}

/// Expected-frequency order, fixed, device independent, on every install.
/// Declared here rather than taken from AppLanguage's own order (en, ne, hi)
/// so reordering is a one-line change in one file. See D-52.
const kLanguageChoices = <LanguageChoice>[
  LanguageChoice(AppLanguage.ne, Locale('ne'), _ne),
  LanguageChoice(AppLanguage.hi, Locale('hi'), _hi),
  LanguageChoice(AppLanguage.en, Locale('en'), _en),
];
```

`welcome_language_screen.dart`, route `/welcome/language`, no AppBar, no back, no skip:

```
Scaffold(backgroundColor: KdColors.canvas)
 └ SafeArea
   └ LayoutBuilder((ctx, c) =>
       SingleChildScrollView(
         child: ConstrainedBox(
           constraints: BoxConstraints(minHeight: c.maxHeight),
           child: Padding(
             padding: EdgeInsets.symmetric(
               horizontal: KdLayout.pageGutter, vertical: KdSpacing.lg),
             child: Column(
               mainAxisAlignment: MainAxisAlignment.end,
               crossAxisAlignment: CrossAxisAlignment.stretch,
               children: [
                 Center(child: Icon(Icons.translate,
                   size: kdScaledIcon(ctx, KdIconSize.xxl),
                   color: KdColors.primary,
                   semanticLabel: l10n.a11yLanguageChooser)),
                 SizedBox(height: KdSpacing.xl),
                 ...three _LanguageTarget separated by SizedBox(KdSpacing.smd),
               ])))))
```

`mainAxisAlignment: end` inside a scroll view whose `minHeight` equals the viewport is the entire short-viewport fix: bottom-aligned when there is room, top-to-bottom scrolling when there is not, no orientation branch, no breakpoint. Make this the house style.

`_LanguageTarget`:

```dart
Semantics(
  button: true,
  label: choice.name(l10n),
  onTap: () => onChoose(choice),   // <-- load-bearing, see below
  excludeSemantics: true,
  child: Card(
    child: InkWell(
      key: languageTargetKey(choice.language),
      borderRadius: BorderRadius.circular(KdRadius.lg),
      onTap: () => onChoose(choice),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KdSpacing.lmd, vertical: KdSpacing.md),
          child: Row(children: [
            Expanded(child: Text(
              choice.name(l10n),
              style: KdType.forLocale(choice.locale).headlineSmall!
                  .copyWith(color: KdColors.inkStrong),   // NOT Theme.of
            )),
            Icon(Icons.arrow_forward,
              size: kdScaledIcon(context, KdIconSize.md),
              color: KdColors.primary),
          ]))))))
```

Two things here are defects being fixed, not preferences:

- **`Semantics(onTap:) + excludeSemantics: true`, never `Semantics(...) + ExcludeSemantics(child: InkWell(onTap:))`.** The existing `_HomeTile` (home_screen.dart:170-184) uses the second form, which produces a node carrying `isButton` and **no `SemanticsAction.tap`**, because the handler is inside the excluded subtree. TalkBack announces "button" and double-tap does nothing. On an unskippable first-run gate that is a hard lock for a blind user.
- **`KdType.forLocale(choice.locale)`, never the ambient theme.** At this moment no language is chosen, so `main.dart:97` themes with `Locale('en')` and both Devanagari endonyms would paint at `KdType._latin` metrics (`headlineSmall` height 1.28, letterSpacing 0), collapsing the shirorekha on the one screen whose job is to be readable in that script.

Interaction: one tap is the whole screen. `KdHaptics.selected()` fired synchronously (matches the recorded haptic map, 04:37), then `setState(_busy = true)` so a double tap cannot write twice, then `await LocaleScope.of(context).setLocale(choice.locale)`, then `context.push('${AppRoutes.welcomeAbout}?first=1')`. No Continue button, no Skip, no preselection, no radio, no confirmation dialog, no animation.

`push`, not `go`, and this is the mis-tap recovery: system back from About returns to the chooser with the app already repainted in the chosen script, so a wrong tap costs one back press and one tap with no reading at either step.

Also edit `home_screen.dart:37-41`: the hardcoded `'English'`/`'नेपाली'`/`'हिन्दी'` in the `PopupMenuButton` now read from `kLanguageChoices`, so the two surfaces cannot diverge.

**Tests that prove it:**
- `welcome_language_test.dart`: with app locale `en`, the resolved `TextStyle` of the नेपाली target has `height >= KdType.devanagariMinHeight` and `letterSpacing == 0`. **Run this against a `Theme.of(context).textTheme.headlineSmall` implementation first and confirm it fails.**
- Each target's `SemanticsNode` has `SemanticsFlag.isButton` **and** `SemanticsAction.tap`. **Run this against `_HomeTile` as it exists today first and confirm it fails.**
- `find.text('नेपाली')` returns exactly one hit with the app in `en`, `ne` and `hi`.
- After tapping the नेपाली target, `settingsStore.read(SettingsKeys.selectedLanguage) == 'ne'` at the moment `/welcome/about` first appears. This is what proves the write is awaited rather than merely started.
- At 320x640 scale 1.0 in `ne`, all three targets are fully inside the viewport with no scroll.

### Step 6. The About screen

**Files:** `app/lib/src/welcome/welcome_about_screen.dart` (new), `app/lib/src/router.dart`

Route `/welcome/about`, with `?first=1` distinguishing first run from a later visit. **Build this before step 7**, because Home links to it.

```
Scaffold(
  backgroundColor: KdColors.canvas,
  appBar: first ? null : AppBar(title: Text(l10n.aboutTitle)),
  body: SafeArea(
    top: first,
    child: Column(children: [
      Expanded(child: ListView(
        padding: EdgeInsets.fromLTRB(
          KdLayout.pageGutter, KdLayout.pageGutter,
          KdLayout.pageGutter, KdLayout.pageGutter),
        children: [
          _AboutBlock(Icons.eco_outlined,
            [l10n.coverageStatement, l10n.coverageLimit]),
          SizedBox(height: KdLayout.sectionGap),
          _AboutBlock(Icons.schedule_outlined,
            [l10n.aboutNotReadyBody]),
          SizedBox(height: KdLayout.sectionGap),
          _AboutBlock(Icons.phone_android_outlined,
            [l10n.aboutPrivacyOffline, l10n.aboutPrivacyOnDevice]),
        ])),
      if (first) Padding(
        padding: const EdgeInsets.all(KdLayout.pageGutter),
        child: FilledButton(
          key: aboutContinueKey,
          onPressed: () => context.go(AppRoutes.home),
          child: Text(l10n.aboutContinue))),
    ])))
```

`_AboutBlock` is a themed `Card` (white fill, 1dp `KdColors.border` at 3.47:1 on canvas, `KdRadius.lg`, zero margin, all from `cardTheme`) with `Padding(KdLayout.cardPadding)` around a `Row` of `Icon(icon, size: kdScaledIcon(context, KdIconSize.lg), color: KdColors.primary)`, `SizedBox(KdSpacing.md)`, `Expanded(Column(crossAxisAlignment: start, children: lines as Text(bodyMedium, KdColors.inkBody) separated by SizedBox(KdSpacing.sm)))`.

No block titles: the glyph carries the category and the sentences carry the meaning. That removes three keys, six D-06 review units, and three fragments from the gate.

**The button is outside the `ListView`, pinned in the `Column`.** This is the single most important structural detail on the screen: a "one button, always" guarantee whose button sits below the fold at the settings this audience uses is a lie at runtime, and a test asserting "scrolls rather than overflows" cannot catch it because a `ListView` never overflows.

Interaction: `first=1` gives one button that `context.go`s Home, clearing the chooser from the stack. Normal mode gives the AppBar back arrow and no bottom bar; do not add a second exit.

**Tests that prove it:**
- `welcome_about_test.dart`: at every cell of the matrix in section 5, `tester.getRect(find.byKey(aboutContinueKey))` is fully inside the viewport. **Run this against an implementation with the button as the last `ListView` child first and confirm it fails at 320x640 / 2.0 / ne.**
- `?first=1` renders no `AppBar` and one `FilledButton`; without it, one `AppBar` and no `aboutContinueKey`.
- Tapping continue leaves the router at `/` with the chooser no longer in the stack.

### Step 7. Home

**File:** `app/lib/src/home_screen.dart`

Delete `_TileGrid`, delete `_HomeTile`, delete the `ScaffoldMessenger` branch (lines 180-184), delete the Ask tile, delete the Settings tile, delete the centred `homeTagline` `Text`. The AppBar and its `PopupMenuButton` language control stay exactly as Module 12 left them.

New body:

```
ListView(padding: EdgeInsets.fromLTRB(
    KdLayout.pageGutter, KdLayout.pageGutter,
    KdLayout.pageGutter, KdLayout.scrollBottomInset),
  children: [
    Text(l10n.coverageStatement,
      style: theme.textTheme.bodyMedium?.copyWith(color: KdColors.inkBody),
      textAlign: TextAlign.start),          // start, so it shares the page's left edge
    SizedBox(height: KdLayout.sectionGap),
    _NotReadyRow(key: homeNotReadyKey,
      icon: Icons.photo_camera_outlined,
      title: l10n.homeNotReadyTitle,
      status: l10n.homeNotReadyStatus,
      onTap: () => context.push(AppRoutes.welcomeAbout)),
    SizedBox(height: KdLayout.itemGap),
    _DestinationRow(key: homeHistoryKey,
      icon: Icons.history_outlined,
      title: l10n.tileHistory,
      onTap: () => context.push(AppRoutes.history)),
    if (kDebugMode) ...unchanged,
  ])
```

Both rows take a **non-nullable, required** `VoidCallback onTap`. After this a dead destination is a compile error, which is the CPO's "a dead tile cannot be added by omission" made structural rather than procedural, and it is the same discipline as the sealed `DiagnosisPresentation`.

`_DestinationRow` (live): themed `Card` (white) > `InkWell(borderRadius: KdRadius.lg)` > `ConstrainedBox(minHeight: KdSpacing.minTouchTarget)` > `Padding(KdLayout.cardPadding)` > `Row(center)`: `Icon(icon, kdScaledIcon(lg), KdColors.primary)`, `SizedBox(KdSpacing.md)`, `Expanded(Text(title, titleMedium, KdColors.inkStrong))`, `Icon(Icons.chevron_right, kdScaledIcon(md), KdColors.inkMuted)`.

`_NotReadyRow` (not ready, and it says so at rest): the same widget shape with four changes, only one of which is colour:
- `Card(color: KdColors.surfaceSunken)` — same shape, switched off. The `cardTheme` border still draws at 3.10:1 on the sunken fill, so the edge survives sunlight.
- leading `Icon` in `KdColors.inkDisabled` (5.01:1) instead of `KdColors.primary`
- title in `KdColors.inkDisabled` instead of `inkStrong`
- **a second line**, `Text(status, bodySmall, KdColors.inkMuted)` (7.47:1 on sunken), which the live row does not have

`KdColors.surfaceSunken` against `KdColors.surface` is 1.25:1. Fill alone cannot do this and is not asked to: the sentence and the missing-versus-present second line are the load-bearing channels, and the fill is the fourth.

The whole card is one `InkWell` and it navigates to a real screen. It is **not** inert. An inert block at the biggest tap magnet on Home reproduces 04:10 verbatim ("the tap is not refused, it is UNOBSERVED"), and a farmer who touches a camera glyph and gets nothing at all cannot tell the app from a frozen phone. Its trailing glyph is `Icons.chevron_right`, not a camera, so what it opens is the explanation and not the camera.

Row, not grid: a row is as tall as its content by construction, so the `childAspectRatio` class of defect cannot return through a new component.

Home pre-decision reading goes from **16 English words to 28**, measured by the cognitive review's own method (03:7). That is an increase, stated as one, and it replaces `homeTagline`'s promise of "identification and advice" with sentences that are true today.

**Tests that prove it:** section 5 matrix, plus `home_no_dead_end_test.dart`: tapping `homeNotReadyKey` changes the router location to `/welcome/about`, tapping `homeHistoryKey` changes it to `/history`, and a source guard fails if `home_screen.dart` contains `showSnackBar`.

### Step 8. Empty History as the funnel

**File:** `app/lib/src/history_screen.dart`

Replace the `records.isEmpty` branch (lines 28-34). Everything else on this screen, including the loading and error branches, is out of scope.

```
Column(children: [
  Expanded(child: ListView(
    padding: EdgeInsets.fromLTRB(
      KdLayout.pageGutter, KdLayout.sectionGap,
      KdLayout.pageGutter, KdLayout.pageGutter),
    children: [
      Center(child: Icon(Icons.eco_outlined,
        size: kdScaledIcon(context, KdIconSize.xxl),
        color: KdColors.inkMuted)),                  // 8.36:1 on canvas
      SizedBox(height: KdSpacing.lg),
      Text(l10n.historyEmptyTitle, titleLarge, inkStrong, center),
      SizedBox(height: KdSpacing.smd),
      Text(l10n.historyEmptyBody, bodyLarge, inkBody, center),
    ])),
  SafeArea(top: false, child: Padding(
    padding: const EdgeInsets.all(KdLayout.pageGutter),
    child: FilledButton(
      key: historyEmptyActionKey,
      onPressed: () => context.push(AppRoutes.welcomeAbout),
      child: Text(l10n.historyEmptyAction)))),
])
```

Same rule as About: the button is outside the scroll view. `Icons.eco_outlined`, not a broken-image or empty-box glyph, because nothing is broken and nothing is missing.

The button is deliberately **not** "Take your first photo", disabled or otherwise. No model exists, `capture_screen.dart:171` terminates in a byte count, and a disabled primary here is the coming-soon tile wearing different clothes. When inference ships this becomes `label: takePhoto, onPressed: () => context.push(AppRoutes.capture)` at the same widget key: a one-line change, recorded now so it is not rediscovered.

**Test that proves it:** `history_test.dart:39-50` rewritten to assert `historyEmptyTitle` in `ne`, that `historyEmptyActionKey` is present and fully inside the viewport at 320x640 / 2.0 / ne, and that tapping it pushes `/welcome/about`.

### Step 9. Android launch window

**Files:** `app/android/app/src/main/res/values/colors.xml` (new), `res/drawable/launch_background.xml`, `res/drawable-v21/launch_background.xml`, `res/values/styles.xml`, `res/values-night/styles.xml`

Verified against the files as they exist: `drawable/launch_background.xml` is `@android:color/white`, `drawable-v21/launch_background.xml` is `?android:colorBackground`, and **`values-night/styles.xml` puts both `LaunchTheme` and `NormalTheme` on `Theme.Black.NoTitleBar`**, which is why a dark-mode device shows a black window and then flashes to `#F1F3EC` (review 06 finding 12).

- New `values/colors.xml` with `<color name="kd_canvas">#F1F3EC</color>`, matching `KdColors.canvas` exactly.
- Both `launch_background.xml` files use `android:drawable="@color/kd_canvas"`.
- Set `android:windowBackground` to `@color/kd_canvas` on **both** `LaunchTheme` and `NormalTheme` in **both** `values/styles.xml` and `values-night/styles.xml`.

Result: from the end of the launcher animation to the first Dart frame the screen is one continuous `#F1F3EC`. This is literally the first frame after install, it costs four small XML edits, it carries no design content and no D-06 load, and nothing in Module 14 or 15 touches it.

**Test that proves it:** none automatable. Verify by eye on the emulator with the OS in dark mode, and record the check in the Product Dashboard.

### Step 10. Existing-test churn (budget it, do not discover it)

- `app/test/app_shell_test.dart`: lines 8-15 (four tiles), 17-27 (asserts `tileDiagnose` ne and `homeTagline` ne, both deleted), 29-33 (asserts `tileAsk` hi, deleted), 35-51 (asserts `tileDiagnose` ne after switching). All four rewritten against `coverageStatement`, `homeNotReadyTitle`, `tileHistory`. Line 39's `find.byIcon(Icons.language)` still works: the AppBar control stays.
- `app/test/home_layout_test.dart`: lines 68-73 iterate four tile icons, two of which are deleted; lines 99 and 127-130 do the same. Replace the four finders with `find.byKey(homeNotReadyKey)` and `find.byKey(homeHistoryKey)`. The `find.ancestor(..., matching: find.byType(Card))` calls keep working because `_NotReadyRow` is a `Card` with an overridden `color`.
- `app/test/history_test.dart`: line 46 asserts the exact Nepali string of the deleted `historyEmpty` key and will fail. Rewrite per step 8. `_openHistory` at lines 11-23 still works.

### Step 11. Close-out

Product Dashboard, PROJECT_MEMORY update, ADRs D-52 to D-54 (section 7). State plainly in the Dashboard that Home is now visibly emptier and that this is the trade being made: the useful-choice ratio goes from 1 live in 5 tap targets to 2 live in 2, and no tap on Home produces a snackbar.

---

## 3. ARB keys

16 new keys; 3 are non-translatable endonyms, so **13 keys x 2 languages = 26 units** through the D-06 native agronomist gate. Batch them with nothing else. Every `ne` and `hi` value below is a **DRAFT PENDING THE D-06 GATE** and must not reach a field test ungated. No em dashes or en dashes appear anywhere.

### Non-translatable (identical in all three ARBs)

Each carries `"@key": {"description": "Do not translate. This is an endonym and must appear in its own script in every locale. See D-53."}`

| key | en / ne / hi (all identical) |
|---|---|
| `languageNameNe` | `नेपाली` |
| `languageNameHi` | `हिन्दी` |
| `languageNameEn` | `English` |

Ask the reviewer to confirm `हिन्दी` versus `हिंदी`; the existing `home_screen.dart:40` uses `हिन्दी` and the two must not diverge. Endonyms are not translations, so they carry no gate units, but the spelling check is real.

### Translated (DRAFT, pending D-06)

| key | en | ne (DRAFT) | hi (DRAFT) | notes for the gate |
|---|---|---|---|---|
| `a11yLanguageChooser` | Choose the language you read. | तपाईंले पढ्ने भाषा छान्नुहोस्। | आप जो भाषा पढ़ते हैं वह चुनें। | Screen-reader only, on the chooser glyph. Resolves in the device locale, which is correct: a screen-reader user's device language is their language. "The language you read", not "your language": the handset is often set by the shop, and reading is the capability that matters. |
| `coverageStatement` | This app is for the leaves of tomato, potato and maize. | यो एप गोलभेँडा, आलु र मकैका पातका लागि हो। | यह ऐप टमाटर, आलू और मक्का के पत्तों के लिए है। | One key, three render sites verbatim: Home, About, and later the out-of-scope result state (closes cognitive-trust finding 4). Deliberately "is for", not "can check": a capability claim would be false today. Confirm the crop names match the existing `cropTomato`/`cropPotato`/`cropMaize` register so the gate reviews one vocabulary. |
| `coverageLimit` | It cannot look at fruit, at roots, or at any other crop. | यसले फल, जरा वा अरू कुनै बाली हेर्न सक्दैन। | यह फल, जड़ या कोई दूसरी फसल नहीं देख सकता। | About only. **Ask specifically whether the negative construction reads as the app describing its own limit or as the app refusing the farmer.** |
| `homeNotReadyTitle` | Check a leaf | पात जाँच्नुहोस् | पत्ता जाँचें | Replaces `tileDiagnose` ("Identify disease" named an output the app cannot produce). A control name, so the complete-sentence rule does not apply; the sentence beneath it is `homeNotReadyStatus`. Uses the verb form the cognitive review endorsed. |
| `homeNotReadyStatus` | This is not ready yet. | यो अझै तयार भएको छैन। | यह अभी तैयार नहीं है। | Second line inside the not-ready row. Short by design: this line must not drive the row's height at 2.0 in Nepali. The reason lives on About. |
| `aboutTitle` | What this app can check | यो एपले के जाँच्न सक्छ | यह ऐप क्या जाँच सकता है | AppBar title on re-open only. A screen name, not instructional copy. |
| `aboutNotReadyBody` | Checking a leaf is not ready yet. The part that recognises diseases is still being built. | पात जाँच्ने काम अझै तयार भएको छैन। रोग चिन्ने भाग अझै बन्दै छ। | पत्ता जाँचना अभी तैयार नहीं है। रोग पहचानने वाला हिस्सा अभी बन रहा है। | The only string in the app that is temporary by design. Names a state, never a date. **Ask whether बन्दै छ / बन रहा है reads as "not finished" rather than "under repair, broken".** |
| `aboutPrivacyOffline` | This app works when your phone has no internet. | तपाईंको फोनमा इन्टरनेट नभए पनि यो एप चल्छ। | आपके फ़ोन में इंटरनेट न हो तब भी यह ऐप चलता है। | True today and structurally: no code path in the app makes a network call. Addresses the prepaid-pack rationing behaviour the UX review ranked third. |
| `aboutPrivacyOnDevice` | Your photos stay on this phone. | तपाईंका तस्बिरहरू यही फोनमै रहन्छन्। | आपकी तस्वीरें इसी फ़ोन में रहती हैं। | True today: EXIF is stripped in `packages/capture` and nothing uploads. Cheapest trust in the product and it currently reaches the user nowhere. **Supersede, never weaken, when sync lands.** |
| `aboutContinue` | Take me to the app | मलाई एपमा लैजानुहोस् | मुझे ऐप पर ले चलें | Button label, so no terminal danda. Not "Get started" or "Done": both imply something was just unlocked. |
| `historyEmptyTitle` | You have not checked a leaf yet. | तपाईंले अझै कुनै पात जाँच्नुभएको छैन। | आपने अभी तक कोई पत्ता नहीं जाँचा है। | Replaces `historyEmpty`, deleted. The Nepali original used रोग पहिचान as a count noun, which the cognitive review reports reads like a government form. |
| `historyEmptyBody` | Checking a leaf is not ready yet. When it is ready, your results will stay on this phone. | पात जाँच्ने काम अझै तयार भएको छैन। तयार भएपछि तपाईंका नतिजा यही फोनमै रहनेछन्। | पत्ता जाँचना अभी तैयार नहीं है। तैयार होने पर आपके नतीजे इसी फ़ोन में रहेंगे। | Future tense, and explicitly conditioned on the not-ready statement in its own first sentence, so it does not claim a save that no code path performs. Deliberately omits "with its photo": `imagePath` renders on no screen. |
| `historyEmptyAction` | See what this app can check | यो एपले के जाँच्न सक्छ हेर्नुहोस् | यह ऐप क्या जाँच सकता है देखें | Button label. Superseded at the same widget key by a capture label when inference ships. |

### Deleted

`homeTagline`, `tileDiagnose`, `tileAsk`, `tileSettings`, `comingSoon`, `historyEmpty` — removed from all three ARBs. Deleting the strings is what stops the tiles being re-added.

`languageMenuTooltip` and `tileHistory` are kept unchanged. `tileHistory` ("History") reads as an app word rather than a farm word, but **no review actually made that finding** and renaming it would spend two more gate units on a claim nobody measured. Put it on the gate's agenda as a question, do not ship a change.

---

## 4. Accessibility requirements per surface

### WelcomeLanguageScreen
- **Semantics:** each target is `Semantics(button: true, label: <endonym>, onTap: <handler>, excludeSemantics: true)`. The node must carry `SemanticsFlag.isButton` **and** `SemanticsAction.tap`; asserting the flag alone passes while the screen is unusable. The `Icons.translate` glyph carries `semanticLabel: l10n.a11yLanguageChooser` and is first in traversal, which is the closest thing to a pre-language prompt that exists. The trailing arrow is inside the excluded subtree.
- **Live regions:** none. Nothing changes without a user gesture.
- **Haptics:** `KdHaptics.selected()` on tap, synchronously before the await, paired with the visible repaint. Nothing else.
- **Touch targets:** minimum height 72dp against the 48dp floor, full page width. This is the one screen where a mis-tap costs the user the whole app.
- **Colour:** no state is drawn, because nothing is selected yet. No colour-only signal exists on this screen.
- Honest limitation to record, not to paper over: a TTS engine with no Devanagari voice will mangle two of the three announcements.

### WelcomeAboutScreen
- **Semantics:** one `Semantics(container: true, label: '<line1> <line2>')` per block with `ExcludeSemantics` beneath, so TalkBack reads three coherent statements rather than eight fragments and can resume between them. The glyphs are decorative and excluded. The continue button keeps its own node with its own tap action.
- **Live regions:** none.
- **Haptics:** none. Navigation is its own feedback and the recorded map excludes page transitions.
- **Touch targets:** the `FilledButton` inherits the themed 48dp minimum and grows with the text scaler. It is the only interactive element in `first` mode.
- **Colour:** text only; every ratio is inherited from Module 12 and unchanged.

### HomeScreen
- **Semantics:** both rows use `Semantics(button: true, label: ..., onTap: ..., excludeSemantics: true)`. The not-ready row's label is `'$title. $status'`, so a screen reader gets the reason in the same breath as the name. Do **not** set `enabled: false` on it: it is enabled, it navigates, and `enabled: false` would make TalkBack announce a disabled control that then works.
- **Live regions:** none. The `PopupMenuButton` language control is unchanged from Module 12.
- **Haptics:** none on either row. The ink response already plays the system click, and the recorded map explicitly excludes home tile taps.
- **Touch targets:** both rows are full width with `minHeight: KdSpacing.minTouchTarget`; both grow with the text scaler; both glyphs route through `kdScaledIcon`.
- **Colour:** not-ready is carried by fill, by ink darkness, by the presence of a second sentence, and by the words. Colour is the fourth channel, never the first.

### HistoryScreen, empty branch
- **Semantics:** the glyph is `ExcludeSemantics`. The two sentences merge into one `Semantics(container: true)`. The button is a real `FilledButton` and therefore already exposes an activate action, unlike the History rows themselves (which stay inert this module; the detail route is Module 14).
- **Live regions:** none. The state does not change without a user action.
- **Haptics:** none.
- **Touch targets:** the button inherits 48dp from `filledButtonTheme`.

---

## 5. Layout matrix that must pass

Sizes are chosen from target hardware, matching the existing `home_layout_test.dart` set. `useScreen` gives no system insets, so the test body is `height - 56` (AppBar) while the device body is `height - 24 - 56 - 48`. Design to the device number; assert against the test number.

| screen | sizes | scales | locales | cells |
|---|---|---|---|---|
| `WelcomeLanguageScreen` | 320x640, 360x800, 412x915 | 1.0, 1.3, 2.0 | ne, hi, en | 27 |
| `WelcomeLanguageScreen` landscape | 915x412 | 1.0, 2.0 | ne | 2 |
| `WelcomeAboutScreen` (`first=1`) | 320x640, 360x800, 412x915 | 1.0, 1.3, 2.0 | ne, hi, en | 27 |
| `WelcomeAboutScreen` landscape | 915x412 | 1.0, 2.0 | ne | 2 |
| `WelcomeAboutScreen` (normal mode) | 320x640 | 1.0, 1.3, 2.0 | ne | 3 |
| `HomeScreen` | 320x640, 360x800, 412x915 | 1.0, 1.3, 2.0 | ne, hi, en | 27 (existing file, finders replaced) |
| `HomeScreen` landscape | 915x412 | 1.0, 2.0 | ne | 2 |
| `HistoryScreen` empty | 320x640, 360x800 | 1.0, 1.3, 2.0 | ne, hi, en | 18 |
| `HistoryScreen` empty landscape | 915x412 | 2.0 | ne | 1 |

**109 cells.** Landscape is included because review 06 records it as broken (tiles at 433x361dp with row two entirely below the fold) and **no test in the repo has ever laid any screen out short and wide**. Let the test settle it rather than trusting anyone's arithmetic, mine included.

Assertions in every cell:
1. `tester.takeException()` is null.
2. Every named key is findable, scrolling if necessary.
3. On `WelcomeAboutScreen` with `first=1` and on empty `HistoryScreen`: the primary button's rect is **fully inside** the viewport without scrolling.
4. On `WelcomeLanguageScreen` at 320x640 scale 1.0: all three targets fully visible with no scroll.

Additional non-matrix assertions:
5. Home tile height at 360x800 grows between scale 1.0 and 2.0 in `ne` (the positive statement behind the guard, carried over from the existing file).
6. Both Home rows measure >= 48dp on both axes at 320x640 in `ne`.

**Vertical budget, stated as an estimate and not as a measurement.** On 320x640 at scale 2.0 in Nepali with a 24dp status bar and a 48dp three-button nav bar, the chooser needs roughly 490dp against 568dp available: `48` padding + `76.8` glyph (`KdIconSize.xxl` 64 with `kdScaledIcon`'s 1.6 clamp) + `32` gap + `3 x 103` targets + `2 x 12` gaps. That leaves about 78dp of slack. Devanagari advance widths come from the OEM ROM and no font is bundled, so this figure carries real uncertainty; the `SingleChildScrollView` absorbs any overrun and **the test, not this paragraph, is the proof.** Every other new surface is a `ListView` or a `SingleChildScrollView` with intrinsic-height children, so no arithmetic below is load-bearing.

---

## 6. Cut list

Each line is something a designer proposed and I am refusing, with the reason.

**Killed by a skeptic's fatal flaw:**

1. **The three-card onboarding deck.** Two of three teachings are false of this build, so the deck's own premise fails. Reduced to one About screen. Needs D-54.
2. **Card teaching the photo and the green gate.** It teaches a gesture on `/capture`, which is reachable only from a `kDebugMode` `TextButton` (home_screen.dart:98). It would also be falsified on the day it becomes true, by 04:10's requirement that the shutter keep `onPressed` non-null and 02:23's "Take it anyway" override, and would go back through the D-06 gate.
3. **Card teaching that "not sure" is a real answer and a human is one tap away.** Promises a diagnosis result state and a person. `escalateToClinic` at `result_preview_screen.dart:33` is a no-op and `docs/seams/clinics.md` describes a directory that does not exist. Violates the hard constraint outright.
4. **A permanent three-pill language bar on Home.** Occupies the slot `NavigationBar` needs, contradicts the recorded deferral (IMPROVEMENT_PLAN:80, PROJECT_MEMORY:41), and its own author conceded it moves in Module 14, destroying the position memory it was built to create.
5. **`onboardingCompleted` / `onboarding_seen_version` as a second settings key.** Two keys can disagree and the disagreement would be invisible until a farmer hit it. One nullable `selected_language` read answers the only question this module asks. It also guarantees that anyone installing at M13 is never taught the real flow when it ships.
6. **An inert, untappable not-ready panel.** A `DecoratedBox` with no recogniser does not scroll on a tap, it does nothing at all, which is 04:10 verbatim at the highest-tap-probability point on the screen.
7. **A horizontal `PageView` carousel with page dots.** `targetSdk 35` forces edge-to-edge and the system reserves 24dp per side, so on a 320dp screen 15 percent of the width answers a horizontal swipe with back navigation. Measured, not preferred.
8. **A pinned bottom action bar reserving the primary-action slot on Home.** Spends the reach zone on a control whose frequency is zero for two modules while the two live destinations sit above it, and its geometry does not survive the swap it was designed for.
9. **Any primary button placed inside a scroll view.** A "one button, always" guarantee whose button is below the fold at 1.5 and gone at 2.0 is a compile-time claim and a runtime lie.
10. **`KdBuildFailure` as a composed widget.** It uses `Icon`, which calls `Directionality.of` and asserts without an ancestor, in a widget explicitly specified to render above `Localizations`. Strictly worse than today's grey box.
11. **A tri-script screen heading.** Five to six lines at 2.0 that push two of three targets off the floor device, styled from the ambient theme so two thirds of it renders Devanagari at Latin metrics, saying nothing the glyph and three endonyms do not.

**Cut because it needs something this module cannot produce:**

12. **Commissioned crop illustrations, pictograms, and the reserved empty slots for them.** IMPROVEMENT_PLAN:80 defers them for want of a designer. Shipping a 48dp empty box is a slot, not a picture.
13. **Per-row play-aloud audio on the chooser.** The strongest possible distinguisher for a non-reader, and it needs a native plugin that cannot be device-verified this module plus recordings of copy still pending D-06. D-35 reserves human audio packs.
14. **Flags beside the languages.** A flag encodes nationality, not language. Nepali is read across the Indian border and Hindi across the Terai.
15. **"This app is free" / "It costs nothing" anywhere.** A permanent pricing commitment in three languages with no monetisation ADR behind it (D-39 records a cost envelope only). This is the owner's call, and it is far harder to withdraw from a first-run screen than to add later.
16. **`KdEmptyState`, `KdStatePanel`, `KdInlineFailure`, `KdSkeletonList`, `KdDeferred`, `KdNotReadyPanel`, `KdCoverageCard`, `KdDestinationRow` in `packages/design_system`.** IMPROVEMENT_PLAN:64 assigns the state components to Module 14, which will reshape any API designed against one caller. Module 13 adds **zero** design-system widgets; the three new widgets stay app-private with a comment naming their promotion target.
17. **A Settings screen and a `/language` route.** 01-cpo.md:25 cut the Settings tile explicitly. Two surfaces writing the same setting is one more than the module needs.
18. **Bottom `NavigationBar` and `StatefulShellRoute`.** Deferral confirmed to Module 14. One live destination does not meet M3's three-to-five rule and the handbook's own IA is a candidate for the tab set.
19. **Any FAB, extended or plain.** Its width derives from its label, Nepali runs 1.7x English on `shutterLabel`, M3 extended FABs clip rather than wrap, and it floats over the scroll view where it can cover the last row.
20. **Moving or deleting the AppBar language control.** It is 887dp from the thumb, and that is a real defect, but reach is Module 14's module and deleting the only existing escape hatch in the same module that introduces its untested replacement is the wrong order. Re-measure after the first field test.
21. **`permission_handler`, the four-branch camera failure enum, and the `AppLifecycleState.resumed` re-check.** All correct, all Module 15 or its own module: `app/integration_test/camera_test.dart` has still never run, and stacking unverifiable platform code on unverified platform code is the trap the camera plugin was held back for.
22. **`router.errorBuilder`, `FlutterError.onError`, `ErrorWidget.builder`, and the startup-failure surface.** Real gaps, correctly enumerated, and none of them is First Contact. The startup black screen is already recorded debt (PROJECT_MEMORY:34).
23. **A repo-wide CI ban on `showSnackBar` and `CircularProgressIndicator`.** The spinner ban pre-empts 04:24's recorded camera-wake choreography without an ADR, and the snackbar ban forecloses 03:28's ask for a success acknowledgement. Guard `home_screen.dart` specifically instead.
24. **Inverted contrast assertions (`expect(ratio, lessThan(3.0))`).** Making it a build failure to ever improve `surfaceSunken` is a ratchet, not falsifiability, and `surfaceSunken` is `theme.dart:104`'s `disabledBackgroundColor` for the shutter, which review 06 finding 9 wants improved. Assert the widget difference instead.
25. **A `_isSentence` assert enforcing the danda.** Asserts in a non-const-invoked constructor are debug-mode runtime checks, not analyzer checks, and every real call site passes a non-const `l10n` getter. It would also crash the failure screen in debug the moment the D-06 reviewer edits punctuation.
26. **`MediaQuery.withClampedTextScaling` anywhere.** Clamping the language control for the users who set 2.0 because they cannot see inverts the priority. `kdScaledIcon`'s 1.6 clamp is not precedent: that clamps icons beside scaling text.
27. **`AnimatedSwitcher` or any transition on the locale change**, any animation at all, `restorationScopeId`, `PopScope`, predictive back, dark theme, and orientation lock. Module 15 owns route feel; `minSdk 23` makes predictive back inert for most of this audience; `SystemChrome.setPreferredOrientations` breaks foldables and is penalised by Play.
28. **Any network involvement**: no locale lookup, no remote strings, no analytics ping on the language choice.

---

## 7. Decision records needed

Written as records, ready to be filed as `docs/adr/D-52.md` etc. and appended to `docs/adr/ADR-INDEX.md`.

**D-52. First run asks for the language, and the device locale is never a hint.**
The chooser is gated on the single existing `SettingsKeys.selectedLanguage` key: `AppLanguage.fromCode(stored) == null` routes to `/welcome/language`, anything else routes to `/`. No second flag is added, because two keys can disagree and the disagreement would be invisible until a farmer hit it; a garbage stored value degrades to the chooser for free. The three options are ordered `ne, hi, en` on every device and every install, with no preselection, no reordering by device locale, no highlighted recommendation, and no fourth "use my phone's language" option. Reasoning: handsets in this market ship configured in English by the shop (P0-9), so the device locale is evidence about a shopkeeper and not about a reader; reordering by it would destroy the position memory that is a non-reader's most useful cue, make goldens and support screenshots device dependent, and put the wrong option first whenever the hint is wrong. Consequence: existing installs that never opened the language menu see the chooser once on their next launch, which is correct because they were never asked. The order is pinned in `kLanguageChoices` and asserted by test so the argument is had once.

**D-53. Endonyms are non-translatable ARB keys, not Dart constants.**
`languageNameNe`, `languageNameHi` and `languageNameEn` carry byte-identical values in `app_en.arb`, `app_ne.arb` and `app_hi.arb`, each with an `@` description reading "Do not translate. This is an endonym and must appear in its own script in every locale." Reasoning: all three render simultaneously on the chooser in every locale, so they are not translations; but moving them into Dart would create a second, ungated user-visible string surface, which this repo has already been burned by (`'Prepared $bytes bytes'`, `'Camera preview (debug)'`), and would put them outside the D-06 review inventory, which is defined as "ne/hi ARB strings". They are rendered with `KdType.forLocale(<their own locale>)`, never the ambient theme. Consequence: the D-35 Weblate flow must respect the non-translatable marker; a test asserts `find.text('नेपाली')` returns exactly one hit with the app in `en`, `ne` and `hi`.

**D-54. The three-card onboarding deck is reduced to one About screen until the flows it would teach are reachable.**
Supersedes the Module 13 scope line in `docs/IMPROVEMENT_PLAN.md` section 5. Module 13 ships one `/welcome/about` screen carrying coverage, the not-ready statement, and the offline and on-device facts. The card teaching the photo and the green gate is deferred to the module that routes `/capture` outside `kDebugMode`; the card teaching certainty and escalation is deferred to the module that ships a model and a clinic directory. Reasoning: those two cards would teach a flow the farmer cannot enter, which is the CPO's "burns the one install attempt you get" executed more thoroughly than today's snackbars; the second also promises a diagnosis and a person, which the module's own hard constraint forbids and which `result_preview_screen.dart:33` cannot honour. The cognitive review independently recommended one card (03-cognitive-trust.md:53). Consequence: no first-run completion flag is stored, so when those flows land the module that ships them owns teaching them, and no install cohort is permanently un-taught.

**Open questions to add to PROJECT_MEMORY, not decisions:**
- Whether the app may state that it is free. Needs an owner decision and an ADR before any pricing sentence ships. Owner: Udit.
- Whether `tileHistory` ("History", "इतिहास") is a farm word or an app word. Put to the D-06 gate as a question; no review measured it, so no change ships on the claim.
- Bundling a Noto Sans Devanagari subset (180 to 260 KB against a 40 MB budget). Already recorded debt (PROJECT_MEMORY:39); Module 13 raises its urgency because the chooser's premise is that each option appears in its own script, and a ROM with a stripped font set renders two of three targets as identical tofu. It remains an owner decision.