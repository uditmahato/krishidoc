# UX Researcher Review (Module 12 pre-review)

VERDICT: a beautifully engineered app a farmer cannot use for anything. Honesty has been implemented as a snackbar. Zero onboarding, zero explanation of why it wants a photo, zero statement about cost/data/offline. Most serious single issue: the app boots in the DEVICE locale (main.dart:44-49), so a Nepali-only reader on a shop-configured English phone lands on an English home screen and must find an unlabelled globe to escape.

## Confusion points (ranked)

1. **Three of four tiles are a snackbar and look identical to the one that works.** home_screen.dart:59-72 (four identical Cards), fallthrough at :107-111. The snackbar renders at the bottom and can COVER the History tile, the only working one, for its full four seconds. FIX: reduced opacity + "soon" badge + persistent explanation instead of a toast; better, drop Ask and Settings from the grid entirely. S / High.

2. **The app opens in the phone's language, not the farmer's.** main.dart:44-49 leaves locale null in production; MaterialApp resolves to device locale. Cheap handsets in Nepal/India ship set to English. The escape is an unlabelled globe whose label only appears on long-press, a gesture first-time smartphone users do not know. A Nepali reader sees "in your own language" in a script they cannot read. FIX: first-run language screen, three full-width buttons in their own scripts at 24sp+, persisted, never shown again. M / High.

3. **Nothing explains why it wants a photo, what happens to it, whether it is free, or whether it needs internet.** 30 strings total; none mention internet, data, cost, privacy, or storage. ConsentScope exists in the domain with no UI. Farmers on prepaid packs will ration or never start; others will assume the photo goes to a government office. FIX: three plain lines: works without internet, free, photo stays on your phone. S / High.

4. **"Coming soon." is not an explanation.** Users with limited smartphone experience read it as an error, or "you must buy something", or "you need internet". FIX: name the feature and what is missing, in farmer terms; promise no date. S / Med.

5. **No onboarding at all; the tagline carries the entire weight** and is two abstract nouns joined by a comma. Never says "take a photo of a sick leaf and this app will tell you what is wrong". The app has no way to teach the one gesture the whole product depends on. FIX: three image-led swipeable cards after language selection. M / High.

6. **History rows cannot be opened and show raw model labels.** history_screen.dart:72-79 no onTap; title is the English snake_case classifier key; imagePath exists and is ignored. The thumbnail is the fix that matters most for low literacy: the photo is the memory hook, not the name. M / High.

7. **Empty history is a text-only cul de sac** and is the terminal state of the entire app. While Diagnose is unavailable this is the BEST real estate in the app: put the explanation, the offline/free/private lines, and a disabled-with-reason "Take your first photo" button here. S / High.

8. **Capture shows a white rectangle telling you to hold steady.** buildPreview returns SizedBox.expand() until init (platform_camera_session.dart:105-111) while the banner says "Hold the camera steady". One to three seconds on a 1GB device. Being told to hold steady with no image is contradictory. FIX: distinct "Starting the camera" state; no coaching before there is a preview. S / Med.

9. **Disabled shutter with no override and no visible cause.** A disabled button does not even ripple, so pressing it gives literally zero feedback; the reason lives in a separate visual region. FIX: move coaching next to the shutter, and add a manual override after ~10s of continuous failure ("Take it anyway"), because a scratched lens, dusk field, or smooth leaf below edge energy 8 leaves a farmer permanently unable to press the only button on screen. M / High.

10. **Camera failure screen has no button.** "Allow camera access in your phone settings" costs a first-time user 8-10 taps in an OS they may not read, then they must exit and re-enter because there is no retry. The same message also shows when the device genuinely has no camera, where the advice is simply wrong. FIX: prime the permission first; "Open settings" deep link + "Try again"; branch the no-hardware case. M / High.

11. **Crop defaults to tomato silently, with no "my crop is not here".** A maize farmer will not read a small chip before their first photo; their photo is processed as tomato and answered confidently. FIX: state coverage on the capture screen, add "My crop is not listed" to the picker, consider forcing an explicit choice on the very first capture only. M / High.

12. **A confident result gives a name and no next step,** and the escalate button exists ONLY on the uncertain card, so a confidently wrong answer has no escape route. Also only one certainty string exists, so 0.55 and 0.99 read identically. FIX: required next-action slot on ConfidentDiagnosis; always-available "still not sure" route; fold the bare chip into a sentence. M / High.

13. **Nepali and Hindi tile labels will clip.** childAspectRatio 1.2 + titleMedium with no maxLines. Overflows at 1.3x scale, common on phones owned by older users. Test at 1.0x, 1.3x, 2.0x IN NEPALI, not English. S / Med.

14. **Two strings promise mechanisms that do not exist:** "Ask a question" (chatbot, out of scope) and "Ask a nearby crop expert" (empty callback), which raises four unanswered questions: who, how far, how much, does it need internet. S / Med.

15. **Honesty gaps:** app title stays Latin "KrishiDoc" in ne/hi including the launcher label, so a Nepali-only reader cannot read the app's own name; history error has no retry; router has no errorBuilder; "Prepared N bytes" is hardcoded English and is the literal terminal state of the capture flow for any tester. S each / Low-Med.

## Tap-count audit
The problem is not the number of taps, it is that most available taps are DEAD. Five tappable things on Home; four produce a toast. History (the only working one) sits third in reading order so both dead tiles are scanned first. Cost of discovering the app does nothing: three taps, twelve seconds of snackbar. Language switcher exists ONLY on the Home AppBar, so changing language from History or Capture is impossible without going back. Re-opening a past diagnosis: not achievable at any tap count.

## Dead ends
The whole app is one today. Plus: history rows go nowhere; history error has no retry; camera-unavailable has no retry and granting permission externally does not recover the screen; permanently unacceptable frames deadlock the shutter forever; language trap if the user lands on History first; wrong-crop silent path.

## First run, minute by minute
0:00 straight to Home, no language question, no explanation. 0:03 everything in English on a shop-configured phone; even a returning user may see one frame of the wrong language. 0:08 tagline explains nothing concrete. 0:15 taps the camera tile: grey bar, possibly covering the only working tile. 0:25 taps it again, then Ask, then Settings: same bar. 0:45 taps History, the last untried tile: centered text, no picture, no button. 1:00 presses back, has now tried everything, nowhere left to go. 1:15 hands the phone to whoever in the village is good with phones, who finds the globe, switches to Nepali, and discovers the tiles still do nothing. 1:30 leaves it open or uninstalls; no second visit because nothing gave them a reason for one.

## Field-test questions
Comprehension before touching: what do you think this does, what would you tap first, how long before they touch anything. Language: how many find the globe unprompted vs hand the phone to someone else. Trust: where does the photo go, does it cost money, does it need network, would you let it keep your photo (informs the research consent wording). Dead tiles: "what just happened, is the app broken or your phone", would you open it again tomorrow (uninstall intent is the number to beat). Capture in a real field at three times of day: time to shutter enable, how many presses of the disabled button, log real edge-energy and luminance against real leaves to calibrate the provisional thresholds. Do they move closer, move the leaf, zoom, or tap to focus (nobody tells them tapping does nothing). Results: show "Late blight. Very likely." then ask "what will you do this afternoon" - if they cannot answer, the card failed regardless of accuracy. Does three options read as thoroughness or incompetence. Would a speaker button reading the result aloud in Nepali change whether they use it, because a text-only app in any language is still text-only.
