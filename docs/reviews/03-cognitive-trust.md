# Cognitive Load and Trust Review (Module 12 pre-review)

VERDICT: unusually disciplined on cognitive load (29 keys, 111 English words total, one coaching instruction at a time, remembered crop). The trust half is largely unbuilt, and one gap is SEVERE rather than merely missing: the app ships exactly ONE certainty band, so every confident diagnosis claims maximum confidence whether the calibrated probability was 0.62 or 0.98. The bones are honest; the words are not yet doing the work the bones set up.

## Cognitive load (measured)
- Total reading burden is genuinely low and is the app's biggest asset. Longest string: 19 English words. Every finding is about the WRONG words, not too many.
- Home: 5 tap targets, 1 leads anywhere. Useful-choice ratio 20%. 16 words read before the first decision.
- A release build has exactly 2 reachable screens, one permanently empty. Nothing in app/lib ever calls diagnosisStore.upsert; the only writers are test files.
- Capture is the best-designed surface in the app: 6 elements, 2 decisions, max 16 words, and the one-instruction rule at capture_screen.dart:171-172 is genuinely enforced.
- **The out-of-scope string breaks that rule**: app_en.arb:14 is 19 words, two sentences, THREE instructions (closer, one leaf, good light), and it appears when the farmer is most frustrated.
- Crop picker: 3 bare ListTiles, no title, no cancel, no explanation of why crop matters.
- History row: 3 data elements, 0 tap targets; predictions/state/modelVersion/imagePath all unreachable.
- Result cards: confident 2 elements / 0 actions; uncertain 5 / 1; out-of-scope 1 / 1. **The state that authorizes spending money and applying chemicals is the emptiest card in the app.**
- **Touch target violation:** tokens.dart:21 declares minTouchTarget 48 but theme.dart:11-20 applies it only to FilledButton and OutlinedButton. The ActionChip at capture_screen.dart:246-251 is ~32dp, so the SMALLEST target on the capture screen is the crop control, on a device held in muddy hands.
- Decisions before value: 2-3. Close to optimal, do not touch.
- Icon-only state coding in History (history_screen.dart:57-64) carries all certainty semantics for a user who may not read.

## Trust gaps (ranked)
1. **One certainty band = every confident answer claims maximum confidence.** certaintyVeryLikely is the ONLY certainty string in all three ARBs; no code maps probability to band; topProbability is computed at prediction_resolver.dart:41 and never read by any UI. The app looks calibrated while being uncalibrated, which is worse than showing nothing. FIX: three bands keyed off topProbability relative to the label's own threshold, phrased as complete sentences; plus a permanent confidentCaveat footer. M / High.
2. **The confident card gives nothing to do and no way to doubt it,** and the absence is PINNED BY TEST (diagnosis_result_view_test.dart:26-27 asserts no buttons exist). Confident-and-wrong is the case that costs money and puts chemicals on a healthy crop, and it is the only state with no correction path. FIX: escalation on all three states + a "this is not my leaf's problem" action; amend the test to assert escalation is PRESENT on all three. S / High.
3. **Out-of-scope blames the photo when the real cause is coverage.** The resolver fires it when nothing matched (prediction_resolver.dart:119); photo-quality failures never reach the resolver at all because the shutter is gated. So the message is almost always the wrong explanation and sends farmers into a retake loop that cannot succeed. FIX: split the string by cause; route the rejection-floor branch to coverage copy. M / High.
4. **The app never states its coverage** although launch_crop_catalog.dart:6-8 says in its own comment that it must. Discovering the limit costs a walk to the field, a photo, and a failure. FIX: coverageNote on Home, repeated verbatim in the not-covered state. S / High.
5. **History flattens uncertainty back into certainty.** Row title is predictions.first.label for EVERY state, so an uncertain record (which the domain forced to carry >=2 predictions precisely so no single answer could be presented as the answer) shows as one disease name with a small amber icon. Every structural protection the sealed hierarchy provides is bypassed because History does not go through it. M / High.
6. **The app's entire promise answers with a four-second snackbar** that a slow reader will miss, and a dead tile looks identical to a live one. FIX: reduced emphasis + persistent inline line; soften the tagline so the first tap does not break a promise. S / High.
7. **Three error states are dead ends.** History error has no retry; camera failure sets _cameraFailed once at :56 and never resets, so returning from Settings still shows failure; startup failure is a black screen. FIX: every failure surface gets one button. M / High.
8. **The strongest trust story in the codebase is invisible.** EXIF stripped, fully offline, photos stay on device: not one word reaches the user. In a low-trust context this is the cheapest trust a product can buy and it is free money left on the table. S / High.
9. **Escalation promises a person and has no destination.** "Ask a nearby crop expert" implies the app will contact someone; a directory will feel like bait and switch. FIX: "See crop experts near you" + verified-on dates + "calling them is free advice". S / Med.
10. **Nothing ever acknowledges success.** No "saved", no "done" in 29 keys. The emotional peak of the capture flow is a hardcoded English 'Prepared N bytes'. S / Med.
11. **The ne/hi certainty strings are grammatically incomplete.** "धेरै सम्भावना" is a bare noun phrase; the Hindi "अधिक संभावना" is a comparative with no comparand. Send full clauses to the agronomist gate, never fragments, and require the reviewer to confirm a farmer can repeat the sentence back. S / Med.
12. **Dates are Gregorian and precise to the minute.** Nepali farmers reckon in Bikram Sambat; minute precision is noise. FIX: relative time for recent entries. S / Low.

## Wording rewrites (full table in agent output; key ones)
- "Very likely" -> three complete sentences: "This looks like X." / "This is probably X." / "This might be X. Check it again in two days." Nepali must use जस्तै देखिन्छ / हुन सक्छ / हो कि जस्तो छ, never a bare सम्भावना.
- New caveat: "A phone photo cannot be certain. If this crop is worth a lot to you, show it to a crop expert before you spray." Must sound like a careful neighbour, not a legal disclaimer.
- Out-of-scope splits into a quality path ("I could not read this photo. Take one leaf, closer, out of direct sun.") and a coverage path ("I do not know this one. This app can only check tomato, potato and maize leaves so far.").
- Tagline: "Check your crop's leaves and get advice, in your own language." Verb, not noun stack; Nepali should use पात जाँच्नुहोस्.
- Empty history: "You have not checked a leaf yet. Your results will stay here, even without internet." (Nepali "रोग पहिचान" as a count noun reads like a government form.)
- "Ask a nearby crop expert" -> "See crop experts near you", using कृषि प्राविधिक / जेटीए, not the abstract विशेषज्ञ.
- "Prepared N bytes" -> "Saved. You can open this later without internet."

## Delight that is not gimmick
- **Show the farmer's own leaf on the result card.** imagePath already exists and the card shows no image at all. Highest trust-per-line-of-code change available.
- **Put a reference photo of the disease beside it:** "does your leaf look like this one?" is answerable without literacy, without trusting the model, and offline. Turns the app from an oracle into an auditable second opinion. Should be a REQUIRED field on every KB entry.
- **Read it aloud.** For this audience audio is the primary access route, not an accessibility afterthought. Prioritise the three result states and the coaching lines.
- **Make the shutter's arming visible:** one scale/colour transition when canCapture flips, matched to the banner turning green. One animation, not a celebration.
- **History as a plot diary:** "You checked tomato 12 days ago." Uses only stored data; the retention answer for R10 with no backend.
- **Say the offline thing at the moment it is true**, not on a marketing screen.

## The three things onboarding must teach
1. What it can check and what it cannot: three crops by name, leaves only, from a photo. Stated as the app's limit, never the farmer's mistake.
2. How to take a photo it can read, AND that the app watches and turns green when ready, so the disabled shutter reads as coaching rather than a fault. The quality gate is the best-built thing in the app and no user knows it exists.
3. How sure the answer will be, that "not sure" is a real answer rather than a failure, and that a human is always one tap away. Pair with the privacy and offline lines.
Deliver as ONE skippable card, in the language chosen on that same screen.
