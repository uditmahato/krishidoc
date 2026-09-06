# KrishiDoc — Complete UI/UX Redesign Brief for Claude Design

This is a standalone product and interface brief. It describes the application that exists in the repository today, the behavior that must remain intact, and the design work required to make it feel like a polished, trustworthy, professional agricultural product.

Copy the section beginning at **MASTER PROMPT** into Claude Design. The remaining appendices can be supplied as supporting context when needed.

---

# MASTER PROMPT

You are redesigning **KrishiDoc**, an Android-first agricultural field companion for smallholder farmers in Nepal. Create a complete, production-quality mobile UI/UX system and high-fidelity screen set. Do not treat this as a landing page, a generic AI chatbot, a corporate dashboard, or a collection of disconnected cards. It must feel like one coherent, mature application designed for real farm work.

## 1. Product in one sentence

KrishiDoc helps a farmer select a crop, photograph an affected leaf, receive a cautious on-device AI **possible match**, read bounded Nepal-focused prevention and control guidance, check city-level weather, organize farm work, and keep private crop-photo records on the phone.

## 2. Product promise

The product should help a farmer answer four practical questions:

1. **What might be happening to this leaf?**
2. **What safe action can I take now, and how can I prevent or control it?**
3. **What weather is expected near my selected Nepal location?**
4. **What work, questions, photos, and previous scans have I saved?**

The interface must communicate usefulness without overstating certainty. It should feel dependable, calm, locally relevant, and easy to operate in the field.

## 3. Primary users and usage environment

Design first for Nepalese smallholder farmers and family farm operators. A secondary user is an extension worker or agronomist viewing the phone together with a farmer.

Assume the user may:

- use a low- or mid-range Android phone;
- work in direct sunlight, rain, dust, or a dim room;
- have muddy hands and need large, forgiving touch targets;
- have intermittent or expensive mobile data;
- share the phone with family members;
- read Nepali, Hindi, or English, with different levels of fluency;
- recognize icons, crops, photos, and short action phrases more easily than dense paragraphs;
- need to act quickly while standing in a field;
- be anxious about losing a crop and therefore vulnerable to overconfident AI output.

The visual experience must work at **320 x 640 dp**, normal contemporary Android sizes around **360–430 dp wide**, landscape layouts where applicable, and text scaling up to **2.0x**. Use Android conventions and Material-compatible interactions rather than iOS-only patterns.

## 4. Desired product personality

KrishiDoc should feel like:

- a trustworthy field instrument;
- a calm Nepal-focused crop companion;
- modern agricultural technology made understandable;
- warm, human, practical, and evidence-aware;
- confident in navigation but cautious in agronomy claims.

It must not feel like:

- a generic green Flutter template;
- a government form;
- a fintech dashboard;
- a luxury lifestyle app;
- a social-media feed;
- a sci-fi AI product full of sparkles and exaggerated claims;
- a page made entirely of identical rounded cards;
- an app that substitutes decoration for information hierarchy.

## 5. Redesign objective

Rebuild the visual system and screen hierarchy so the application looks intentionally designed by a senior mobile product team. Improve composition, spacing, typography, navigation, information density, iconography, state communication, and consistency while preserving all functional behavior described below.

Use a strong visual hierarchy:

- one obvious primary action per screen;
- important information visible before secondary explanation;
- clear distinction between navigation, actions, information, warnings, and saved records;
- consistent spatial rhythm instead of arbitrary gaps;
- fewer unnecessary containers and borders;
- deliberate use of full-width surfaces, grouped lists, dividers, tonal sections, and imagery;
- professional empty, loading, disabled, failure, and offline states;
- state must never be communicated by color alone.

## 6. Core information architecture

### First-run flow

1. Language selection
2. Product purpose, capabilities, privacy, and limitations
3. Main application

### Main application shell

The persistent bottom navigation has three destinations:

1. **Work** — crop context, disease scan, weather, assistant shortcut, and farm tasks
2. **Doctor** — disease scanner, crop assistant, private saved questions
3. **Records** — activity summary, disease-scan history, and crop-photo notebook

The top app bar contains the KrishiDoc identity and a language switcher.

### Secondary routes

- Disease scan preparation
- Disease camera
- Diagnosis result
- Disease-scan history
- Crop assistant
- Nepal weather
- Crop-photo notebook
- Single photo/observation detail
- General camera for saving a crop photo without classifying it
- About/product disclosure

The main route relationships are:

```text
First run: Language -> About -> Home

Home / Work -> Disease preparation -> Disease camera -> Result
             -> Weather
             -> Crop assistant
             -> Add/manage farm work

Home / Doctor -> Disease preparation -> Disease camera -> Result
               -> Crop assistant
               -> Save/manage a private crop question

Result -> Crop assistant with crop + possible-match context
       -> Start another disease scan

Home / Records -> Disease history -> Stored result
                -> Crop-photo notebook -> Photo detail/edit/delete
                -> General camera -> Saved photo detail
```

## 7. Feature truth and product boundaries

These are non-negotiable. The redesign must not imply capabilities that do not exist.

### Disease scanning

- The user photographs **one affected leaf**.
- Classification runs on the phone with a bundled TensorFlow Lite model.
- Supported crop contexts are **tomato, potato, and maize**.
- The current production model is experimental and trained on PlantVillage-style laboratory imagery.
- It has not been validated on representative Nepal field conditions.
- It has no reliable non-plant/open-set class, so a photograph that is not a supported leaf cannot safely be forced into a disease label.
- It returns **possible matches**, not a confirmed diagnosis.
- It can refuse a photo or show uncertainty.
- It must never look like a medical-style definitive diagnosis or a green success confirmation.
- The photo is processed and stored locally; it is not uploaded.

### Crop assistant

- Available in **Nepali, Hindi, and English**.
- The current Nepali and Hindi wording is implemented but still requires native-language and agronomy review before a field release; do not describe it as professionally validated translation.
- Covers tomato, potato, and maize.
- Provides structured sections for immediate action, prevention, control, and when to seek local help.
- References public Nepal Agricultural Research Council material.
- It is a deterministic, keyword-routed, bounded offline guide.
- It is **not live generative AI**, does not contact an expert, and does not diagnose.
- It does not provide pesticide product names or dosage instructions.
- Conversation context lasts only for the current in-memory screen session.

### Weather

- Live data comes from Open-Meteo and requires internet.
- The user manually chooses a Nepal city; the app does not request GPS permission.
- Presets cover one city in each province: Biratnagar, Janakpurdham, Kathmandu, Pokhara, Butwal, Birendranagar, and Dhangadhi.
- The screen shows current temperature, condition, humidity, wind, and a seven-day forecast.
- Daily rows show minimum/maximum temperature, rain probability where available, rain amount, and maximum wind.
- Forecasts are city-level estimates, not field sensors or official warnings.
- Forecasts older than three hours are marked as saved/stale.
- If refresh fails and a previous in-memory result exists, the old result remains visible with a failure notice.
- The selected city persists, but forecast data itself is not an offline-across-restarts weather database.

### Records and privacy

- Diagnoses, farm work, saved questions, crop photos, notes, selected language, selected crop, and selected weather city are stored locally.
- Crop photos are reoriented, reduced to a maximum 1024-pixel long edge, stripped of EXIF metadata including possible GPS, and JPEG-compressed before storage.
- There is no farmer account, cloud synchronization, marketplace, live expert chat, social community, satellite imagery, field sensor connection, voice assistant, or push-alert system in the current application.
- Saved questions are private reminders on the phone; they are not sent to an agronomist.

## 8. Complete screen specifications

Design every screen and every state listed below. Use realistic English content in the primary mockups, then demonstrate that the same components expand correctly for Nepali and Hindi.

### Screen A — Native launch and app identity

Purpose: create a polished first impression while Flutter initializes.

Components:

- Android adaptive launcher icon;
- round launcher icon;
- monochrome themed icon;
- native splash background matching the Flutter canvas color;
- a unified KrishiDoc symbol across native and Flutter surfaces;
- smooth visual handoff from splash to the first Flutter frame.

The current implementation has two related but different marks: Flutter draws one leaf above three field contours, while the native launcher/splash draws a two-leaf sprout above two field rows. Resolve this into one canonical geometry and provide all native/Flutter size variants. Avoid a generic white Flutter flash, an oversized logo, or an illustrated loading page.

### Screen B — Language selection

Purpose: let a new user choose the language they can read with one tap.

Components and behavior:

- dark, branded field/forest background or equivalent premium brand surface;
- KrishiDoc mark and wordmark;
- small visual cues for crop, camera, and weather;
- one clear instruction: choose the language you read;
- three large options in fixed order: **नेपाली, हिन्दी, English**;
- every language name uses its own script and appropriate typography;
- each row is at least 48 dp high, preferably around 64–72 dp;
- no preselected option;
- no skip button;
- no separate Continue button;
- tapping a language immediately applies and saves it;
- prevent double-tap submission;
- system Back from the next screen can return here to recover from a wrong tap;
- scrolling must replace overflow on short screens or landscape.
- existing Nepali and Hindi strings may be used to test layout, but they remain draft content pending native-language and agronomy review.

States:

- idle;
- pressed;
- submitting after selection: current logic blocks duplicate taps without visually disabling the rows, so create an honest visible busy/disabled treatment as part of the redesign;
- large-text and short-height layouts.

### Screen C — About, purpose, and first-run disclosure

Purpose: explain what the app does, what it does not promise, and what stays private.

Components:

- first-run brand header;
- strong purpose hero with the coverage statement;
- explicit statement that photo scanning is experimental and not a confirmed diagnosis;
- capability group for leaf photos, offline crop guide, and weather;
- privacy/offline group explaining that records, scans, and the guide work without internet while live weather requires it;
- statement that photos remain on the phone and weather sends only the manually selected place to Open-Meteo;
- pinned full-width primary button: **Take me to the app**;
- when opened outside first run, use a normal app bar and omit the pinned onboarding button.

The standalone About route exists today, but no visible Home control links to it. Adding a discoverable About/privacy entry is a proposed navigation improvement, not an already shipped entry point.

The first-run button must remain visible without requiring the user to discover that the page scrolls.

### Screen D — Main shell and app bar

Components:

- KrishiDoc mark plus wordmark/title;
- language icon/menu with checked current language;
- bottom navigation with Work, Doctor, and Records;
- selected and unselected icon variants;
- labels always visible;
- preserve state when switching tabs;
- selection haptic feedback;
- Android safe-area and edge-to-edge handling.

Professional redesign opportunity: create a clearer relationship between the compact brand header and the selected main destination. Avoid making the top bar feel like an unrelated banner.

### Screen E — Work dashboard

Purpose: give the farmer the most important next actions and current work context.

Content order and components:

1. **Working crop selector**
   - selected crop name;
   - crop icon or thumbnail treatment;
   - Change action opening a checked menu;
   - tomato, potato, and maize options;
   - selected crop persists across sessions.

2. **Primary disease scan action**
   - dominant visual priority;
   - label such as Scan a leaf for disease;
   - short description explaining the on-device AI possible-match function;
   - clear camera action;
   - experimental/AI status should be visible but should not overpower the task;
   - one tap opens disease-scan preparation.

3. **Weather summary**
   - selected city name;
   - before loading: short explanation of live weather;
   - when available: temperature and condition;
   - weather icon and clear onward affordance;
   - one tap opens the full forecast.

   The current Work card does not start a weather request itself. It shows live values only after the shared weather controller has been loaded, normally by visiting Weather during the same app process. If the redesign requires automatically refreshed dashboard weather, identify that as a behavior change.

4. **Crop assistant shortcut**
   - clearly distinct from disease scanning;
   - states that it provides prevention and control guidance in the selected language;
   - offline badge;
   - one tap opens assistant with selected crop context.

5. **Farm work section**
   - section title;
   - Add work button;
   - open tasks first;
   - completed subsection with count and up to five recent completed tasks;
   - task row with checkbox, title, and due label;
   - completed task uses strikethrough but remains readable;
   - toggling completion shows visible confirmation;
   - empty state explains how to add the next field job.

6. **Add work dialog**
   - title field, maximum 240 characters;
   - due choice chips: Any time, Today, Tomorrow;
   - Cancel and Save actions;
   - Save disabled or blocked when the title is empty;
   - saved item inherits the current crop context.

The current task UI supports add, complete, and reopen. It does not currently provide edit, delete, recurrence, notification, assignment, or calendar actions.

Explicitly design the Work crop-loading/error and task-loading/error states. Add Work and Save Question are variants of one shared entry-dialog pattern; the due-date choices appear only for Work.

### Screen F — Doctor hub

Purpose: provide two honest crop-help paths and a private place to remember questions.

Components:

- heading and one-line introduction;
- dominant disease-scan action;
- crop-assistant action with offline label;
- Save a question action;
- privacy notice: questions are saved locally and are not sent to an expert;
- Saved questions section;
- question rows reuse the task lifecycle and can be marked resolved/reopened;
- empty saved-questions state.

Also design the saved-question loading and error states.

Do not visually merge the scanner and assistant into one magical AI feature. The scanner classifies an image; the assistant retrieves bounded guidance.

### Screen G — Records dashboard

Purpose: make saved activity feel useful and organized rather than like a settings page.

Components:

- heading and offline-records explanation;
- responsive activity summary with counts for crop photos, completed work, and saved questions;
- on normal widths, three compact metrics in a row;
- on narrow widths or large text, stacked metric rows;
- Disease scans section with total count and route to full history;
- Crop photos section with View all;
- preview of up to four recent observations;
- observation row with crop, date or note, photo affordance, and chevron;
- empty crop-photo state with Take crop photo action.

Also design the nested loading and error states for observations, work/question metrics, and diagnosis counts. The current implementation can be waiting for one records source while another has already resolved.

### Screen H — Disease scan preparation

Purpose: set expectations, choose the correct crop, improve the photo, and gain informed consent before opening the camera.

Components:

- app bar title;
- strong scanner hero;
- visible experimental-model label;
- concise statement: photograph one affected leaf; results are possible matches, not a confirmed diagnosis;
- supported-crop statement;
- selected-crop panel;
- always-visible crop ChoiceChips for tomato, potato, and maize;
- photo guidance: move close enough to the leaf, use adequate light, avoid direct sunlight;
- privacy row: scan runs on the phone and photo is not uploaded;
- caution panel explaining lack of Nepal field validation and the need to confirm important treatment decisions with a crop technician;
- pinned safe-area primary action: **I understand — open camera**;
- action bar repeats the selected crop context;
- loading state while selected crop is restored;
- error state if crop context cannot load.
- forward-compatible unsupported-crop information state: it removes the bottom camera action and asks the user to choose a covered crop. This state is currently unreachable because both the launch catalog and scanner contain the same three crops, but the code contract exists for future catalogs.

The primary action must be visible and easy to reach. Do not hide consent or limitations in a tooltip, accordion, or fine print.

### Screen I — Disease camera

Purpose: help the farmer take a model-usable leaf photo without understanding photography.

Components:

- immersive dark camera UI;
- compact app bar/back affordance and mode-specific title;
- live camera preview;
- leaf-shaped or corner-based framing guide;
- the framing guide is instructional only: the current app does not detect a leaf, lesion, bounding box, crop species, or ideal framing before capture;
- framing guide changes visibly when the frame becomes acceptable;
- selected-crop chip over the preview;
- tapping the crop chip opens a titled bottom sheet with allowed crops and current selection;
- while crop context is loading, the overlay reserves a blank 48 dp target-sized space; if crop context fails, the chip is hidden. Redesign these as intentional loading/error behaviors rather than visual glitches;
- opaque live coaching banner above the shutter;
- one instruction at a time: Hold steady, Move somewhere brighter, Step out of direct sunlight, Move closer and hold steady, or Ready;
- large concrete shutter button with camera/scanner icon and text;
- shutter remains visibly disabled until the quality gate accepts the frame;
- full-screen progress overlay while capturing, preparing, classifying, saving, and routing;
- persistent inline failure message if capture or inference fails;
- dedicated camera-unavailable/permission-denied state with explanation;
- accessibility live region for coaching and progress;
- safe handling of bottom system insets.

There are two modes using the same camera foundation:

- **Disease mode:** classify, save a diagnosis record, then open Result.
- **Notebook mode:** save a dated photo without making any plant-health claim, then open Photo detail.

The current camera has no gallery import, flash/torch control, tap-to-focus, zoom control, segmentation outline, lesion box, or automatic shutter. Do not present those controls as working features.

### Screen J — Diagnosis result

Purpose: show what the model could and could not determine, preserve trust, and provide a safe next step.

Components in order:

1. app bar title;
2. a conditional, non-dismissible trust banner at the top: sample-model records show a Sample Data notice, experimental-model records show an Experimental Model notice, and other model versions show neither;
3. captured leaf photo when a path and readable file are available; the current detail image collapses when absent, reclaimed, or undecodable, so any visible placeholder is a proposed improvement;
4. exactly one result-state presentation;
5. route to treatment, prevention, and control guidance;
6. saved-offline confirmation.

Top-level route states also include loading the stored record, store/read error, and missing-record error. Never render a blank body, because that could be interpreted as a healthy result.

Design three result states even though the current release model is structurally limited to uncertain/out-of-scope output:

#### Confident renderer contract

- investigative icon, never a success checkmark;
- plain-language sentence such as “This might be late blight” rather than a laboratory score;
- visible caveat that a phone photo cannot be certain;
- primary action to view bounded guidance;
- secondary correction action: This is not what my leaf has.

The current release model cannot create new confident results. However, this renderer is already used by debug/sample previews and can display stored or legacy confident records, so it remains a current tested component contract as well as preparation for a future calibrated pack.

#### Uncertain presentation

- heading: We are not sure;
- up to three named alternatives in ranked order;
- alternatives must not look like selectable confirmed diagnoses;
- primary action to view bounded guidance;
- uncertain color, icon, heading, and structure all communicate the state.

#### Out-of-scope/refusal presentation

- explain that current coverage is limited to tomato, potato, and maize leaves or that nothing safe could be identified;
- never silently force a disease name;
- do not show a retake action for current stored production out-of-scope records, because the current presenter always treats them as a coverage gap;
- retain a route to general bounded crop guidance.

An unreadable-photo variant with a Retake action exists only in the reusable result component and debug preview. Producing it from a real stored result would require a new cause in the domain/data flow; do not present that variant as currently reachable production behavior.

When the user opens guidance from a result, pass the selected crop and top possible-match context. The assistant automatically produces a bounded answer while visibly retaining the “possible match, not a diagnosis” caveat.

Do not make model confidence percentages the visual headline. Do not use red/green diagnosis verdict styling that resembles a laboratory confirmation.

### Screen K — Disease-scan history

Purpose: reopen previous locally stored scan results.

Components:

- app bar;
- loading and error states;
- separate non-dismissible Sample Data and Experimental Model warnings when relevant; a mixed list can show both banners simultaneously;
- newest-first result list;
- each row includes state icon, localized disease/possible-match name or Could not identify, state label, date/time, and onward affordance;
- consider adding the locally available photo thumbnail to improve recognition, but provide an equally clear missing-photo variant;
- experimental/sample marker on relevant rows;
- semantic label reads state before disease name;
- tapping opens the immutable stored result by ID;
- empty state with illustration/icon, explanation, and pinned Start a disease scan button.

Do not make uncertain and out-of-scope records look like successful completed diagnoses.

### Screen L — Crop assistant

Purpose: offer structured, bounded Nepal crop guidance in a conversational form without pretending to be a live large-language-model service.

Components:

- app bar title;
- intro explaining supported question types;
- current crop-context chip;
- prominent but compact offline-guide disclosure;
- source/limitations disclosure;
- scrollable conversation area;
- farmer question bubbles aligned to the end side;
- scan-context bubble with scanner icon and possible-match caveat;
- answering/loading bubble;
- structured answer card with:
  - short summary;
  - Treatment / what to do now;
  - Prevention;
  - Control;
  - Get local help when;
  - source and limitations;
- NARC attribution and visible source URL;
- persistent bottom composer;
- one-to-three-line input;
- 500-character maximum;
- send button with tooltip and semantic label;
- empty-input and too-long validation states;
- failed-answer notice;
- automatic scroll to the newest answer;
- disable sending while an answer is being produced.

Route/controller states to design explicitly:

- selected-crop loading;
- selected-crop provider error;
- unsupported-crop Not covered state;
- context update that clears old-crop or old-language turns;
- a stale asynchronous answer being discarded after the context changes.

The answer content is not free-form chat prose. It is structured agronomic guidance. Make each section scannable in a field setting. The immediate-action section should have stronger priority than prevention and source metadata, but warnings and attribution must remain legible.

### Screen M — Nepal weather

Purpose: provide a quick, honest city forecast for farm planning.

Components:

- app bar and Refresh action;
- pull-to-refresh;
- prominent manual location selector;
- loading progress without erasing an existing forecast;
- current-weather hero with condition icon, temperature, condition name, humidity, and wind;
- seven-day section;
- daily row with day/date, condition icon/name, min–max temperature, rain probability, rain amount, and maximum wind;
- responsive row that stacks when width is narrow or text is enlarged;
- source name and observation/update time;
- disclaimer that this is a city estimate and official DHM warnings should be checked before weather-sensitive work;
- stale/saved forecast notice;
- no-internet, provider-unavailable, invalid-data, and unknown failure presentations;
- Retry action when no cached result exists;
- when a refresh fails with an existing result, keep the result visible and state that the last forecast is being shown.

Provide icon/content variants for clear, partly cloudy, fog, drizzle, rain, snow, showers, thunderstorm, and unavailable/unknown conditions.

Do not display this as field-level precision, a weather warning system, a pesticide-timing prescription, or GPS-derived local weather.

### Screen N — Crop-photo notebook

Purpose: keep dated visual field records without claiming to identify anything.

Components:

- app bar title My leaf photos;
- newest-first list;
- fixed square thumbnail to prevent layout shifts;
- crop name or date as title;
- date/time;
- optional note or neutral No note label;
- missing/corrupt photo placeholder;
- pinned full-width Take a photo action;
- loading, error, and empty states;
- empty state explains that photos stay on the phone and work without internet.

### Screen O — Single crop photo / observation

Purpose: view, annotate, or remove one locally saved photo.

Components:

- app bar;
- large image when the local file remains available and readable;
- crop and localized date/time;
- saved-on-phone status;
- optional note field, maximum 500 characters, one to three lines;
- Save note primary action;
- destructive Delete this photo action;
- delete confirmation dialog explaining that deletion cannot be undone;
- saving/loading disabled state;
- missing-record and read-error states.

The photo already exists before this screen opens. The note is genuinely optional.

Current behavior hides the detail image entirely when the file is missing or undecodable; only notebook-list thumbnails have a visible placeholder. An explicit detail fallback is recommended professional polish, but must be documented as a UI behavior change.

### Screen P — Add question dialog

Purpose: store a private question/reminder, not send a message.

Components:

- clear title;
- multiline field with What did you notice? prompt;
- 240-character maximum;
- Cancel and Save;
- block empty submission;
- after saving, show a local confirmation;
- use the selected crop as context.

Do not show an expert avatar, delivery indicator, online status, or “message sent” language.

## 9. Global component system

Create a complete reusable component library with documented variants and states.

### Brand components

- adaptive app icon;
- KrishiDoc mark;
- wordmark lockup;
- compact app-bar lockup;
- native splash treatment.

### Navigation

- top app bar;
- back app bar;
- language menu;
- three-destination bottom navigation;
- section-level text actions;
- list-row chevrons;
- modal bottom sheet.

### Buttons

- primary filled button;
- secondary outlined button;
- tertiary/text button;
- destructive text button;
- icon button;
- compact send button;
- camera shutter button;
- pinned bottom action bar;
- all states: default, pressed, focused, disabled, busy/loading.

### Form controls

- single-line text field;
- multiline text field;
- dropdown selector;
- ChoiceChip;
- ActionChip;
- checkbox task row;
- validation text;
- character-limit behavior;
- focused, filled, disabled, and error states.

### Content containers

- page section header with optional subtitle and action;
- primary purpose hero;
- compact quick-action row;
- crop context selector;
- metric group;
- observation row;
- task/question row;
- weather current-condition surface;
- weather daily row;
- answer/guidance section;
- source footer;
- photo container and thumbnail;
- dialog and bottom sheet.

### Status and trust components

- AI/experimental label;
- offline label;
- crop-context pill;
- privacy notice;
- caution/warning banner;
- stale-data notice;
- error notice;
- experimental-model notice;
- saved-on-device confirmation;
- loading panel and progress overlay;
- empty state;
- missing-image placeholder;
- diagnosis state surfaces for possible match, uncertain, and out of scope.

Every status component must use a combination of icon, text, shape/layout, and color. Never rely on color alone.

### Camera components

- live preview surface;
- crop overlay chip;
- viewfinder corners/frame;
- coaching banner;
- ready/not-ready variation;
- shutter;
- camera-unavailable state;
- capture/inference progress overlay;
- persistent capture failure.

## 10. Visual direction

Build a refined visual language around Nepalese agriculture without resorting to clip-art farms or decorative folk motifs that compete with the task.

Recommended direction:

- deep forest green for trust and primary navigation;
- warm off-white or rice-paper canvas rather than sterile gray;
- restrained leaf green for crop context;
- muted saffron/gold for attention and offline knowledge;
- desaturated sky blue for weather;
- muted earth/clay for records;
- near-black ink for outdoor legibility;
- white or near-white functional surfaces;
- subtle elevation used sparingly;
- strong photography framing and clear icons;
- one consistent icon family with rounded, readable geometry;
- coherent radii instead of mixing sharp rectangles, stadium pills, and oversized bubbles without purpose.

The existing palette can be used as a starting reference, not an unchangeable command:

- Forest: `#0E3C28`
- Primary green: `#1B5E20`
- Pressed green: `#123F24`
- Warm canvas: `#F7F5EC`
- Surface: `#FFFEFA`
- Gold: `#F2C75C`
- Sky tint: `#DDEBF1`
- Earth tint: `#F2E2D2`
- Strong ink: `#12140F`

Do not use gradients on every feature. Reserve a branded or tonal hero treatment for the highest-priority action. Avoid “card soup”: related information may share a section instead of each line receiving its own rounded rectangle.

## 11. Typography

Create a bilingual/tall-script-aware type system.

Requirements:

- Latin and Devanagari must share hierarchy but may use different line-height metrics;
- Devanagari letter spacing must be zero;
- Devanagari body line height should be approximately 1.55–1.65;
- headings must allow matras above and below the line without clipping;
- use a dependable family such as Noto Sans plus Noto Sans Devanagari, or another fully tested family with matching weights;
- body copy must remain comfortably readable in sunlight;
- never place long paragraphs in tiny caption type;
- support dynamic type up to 2.0x without clipping, overlap, or unreachable actions;
- use numerals and units consistently, leaving room for later field validation of local-unit conventions.

No font is currently bundled; adding Noto Sans Devanagari or another controlled family is a new application asset and implementation dependency, not only a style-token change.

Suggested hierarchy, adjustable after visual testing:

- display/weather temperature: 36–40;
- page headline: 28–32;
- section/purpose headline: 22–24;
- card/list title: 17–19;
- primary body: 16–17;
- supporting body: 14–15;
- labels/metadata: 12–14, never used for critical warnings.

## 12. Layout and responsive rules

- Use an 8-point rhythm with 4-point subdivisions.
- Default horizontal page gutter: approximately 16 dp.
- Minimum interactive target: 48 x 48 dp.
- Primary buttons should normally be 52–56 dp high.
- Keep key actions within comfortable thumb reach.
- Use SafeArea for status/navigation bars and Android edge-to-edge layouts.
- Long pages scroll; do not use fixed-height structures that overflow.
- Bottom-pinned actions must not cover the last scroll item.
- Section headers with actions stack vertically when text is enlarged or width is below approximately 300 dp.
- Three-column metrics collapse into rows on narrow layouts.
- Forecast identity and temperature range stack on narrow layouts.
- Labels must wrap rather than clip in Nepali/Hindi.
- Icons should scale moderately with the text setting but must not grow so much that they displace their labels.
- Do not place critical actions only in floating action buttons with long localized labels.

## 13. Accessibility requirements

- WCAG AA contrast for text and meaningful controls; aim higher for outdoor use.
- Minimum 48 dp touch targets.
- Visible focus and pressed states.
- Screen-reader labels for icon-only controls.
- Language choices are complete semantic buttons with working tap actions.
- Camera coaching and progress are live regions.
- Diagnosis semantics announce certainty/state before the disease name.
- Group related disclosure copy into coherent semantic blocks.
- Decorative icons and artwork are excluded from semantics.
- Never use color as the only status channel.
- Respect the Android remove-animations setting.
- Avoid rapid, repeated status animation in the camera.
- Design all content for 2.0x text scaling and short screens.

## 14. Motion and feedback

Use subtle, purposeful motion only:

- short selection transitions;
- calm screen transitions that do not compete with the live camera;
- progress state for capture/inference;
- gentle automatic scroll to a new assistant answer;
- no looping decorative animation;
- no celebratory animation for a disease result;
- no pulsing AI glow.

Existing haptic vocabulary to preserve:

- selection tick is currently emitted for first-run language, main-tab changes, and crop selection from the camera bottom sheet; extending it to the Work crop menu or disease-preparation chips is a proposed consistency improvement;
- medium shutter impact;
- light completion feedback after the camera capture/store flow;
- stronger refusal/failure feedback after a camera capture or inference failure;
- haptics are always paired with a visible state and respect system settings.

## 15. Content and trust language

Use plain, direct language. Prefer verbs and observable facts.

Good examples:

- Scan a leaf for disease
- Possible match — not a diagnosis
- Move somewhere brighter
- Saved on this phone
- Showing the last forecast
- Get treatment, prevention and control guidance
- Questions are saved here for you. They are not sent to an expert yet.

Avoid:

- Diagnose now
- AI-powered certainty
- Expert verified, unless a real expert verified that exact item
- Guaranteed treatment
- Your crop is safe
- Message sent to doctor
- Hyperlocal weather, when it is city-level
- Real-time AI chat, when it is a bundled offline guide

## 16. Technical constraints that affect the design

- Flutter and Material 3 implementation.
- The current product ships a light theme only. A dark or special sunlight theme may be proposed, but must be identified as additional implementation work.
- Android-first, minimum Android 8.0 / API 26.
- The current repository contains an Android platform application only; do not assume an iOS interface already exists.
- Current Android configuration uses application ID `com.krishidoc.app`, compile SDK 36, target SDK 35, Java/Kotlin 11, and NDK 27.
- Riverpod state management.
- GoRouter navigation.
- Drift/SQLite local database running off the UI thread.
- Camera plugin using a YUV preview stream.
- Image quality gate evaluates exposure and blur roughly five times per second.
- Image preparation runs in an isolate.
- TensorFlow Lite model runs in a persistent worker isolate with bounded startup, inference, and shutdown times.
- The model uses two interpreter threads, a 20-second startup bound, and a 15-second inference bound; these are failure ceilings, not desirable loading-screen durations.
- Current model input is 224 x 224 RGB and output contains 38 global PlantVillage classes; only tomato, potato, and maize classes are exposed by the app.
- The bundled model asset is 9,061,216 bytes. Its source reports 92.44% augmented laboratory validation accuracy, which KrishiDoc has not independently reproduced and which must never be presented as Nepal field accuracy.
- App localization uses ARB resources for English, Nepali, and Hindi.
- Weather uses an HTTP request with a 12-second timeout.
- Camera and internet are the only current Android permissions. Location permission is deliberately absent.
- The release APK is approximately 36 MB for arm64, so the redesign should not depend on large video or photo asset packs.
- Favor code-native/vector assets and a small number of purposeful raster assets.
- Keep camera overlays and long lists performant on lower-memory devices.

There is also an early FastAPI device-identity/idempotency backend scaffold in the repository, but the current mobile app does not use it for accounts, synchronization, assistant answers, diagnoses, or records. Do not design logged-in or cloud-sync states as current functionality.

## 17. Model coverage shown to users

The underlying model has 38 PlantVillage classes, but the product intentionally exposes only the selected crop's classes.

### Maize

- Gray leaf spot (Cercospora)
- Common rust
- Northern leaf blight
- Healthy maize leaf

### Potato

- Early blight
- Late blight
- Healthy potato leaf

### Tomato

- Bacterial spot
- Early blight
- Late blight
- Leaf mold
- Septoria leaf spot
- Two-spotted spider mites
- Target spot
- Yellow leaf curl virus
- Mosaic virus
- Healthy tomato leaf

If the global model winner belongs to another crop, the app refuses the result rather than filtering the output and manufacturing a match for the selected crop.

## 18. State matrix that must be designed

For every applicable component or screen, include:

- first use / no data;
- normal populated state;
- loading;
- refreshing while old data remains visible;
- disabled;
- pressed/focused;
- inline validation;
- recoverable failure with retry;
- non-recoverable or unavailable state;
- stale data;
- missing local photo;
- very long localized text;
- 2.0x text scale;
- offline state;
- uncertain result;
- out-of-scope result;
- destructive confirmation.

## 19. What you may improve structurally

You may redesign:

- visual identity and brand lockup;
- typography and font recommendations;
- palette while preserving accessible semantic meaning;
- spacing and density;
- exact card/surface treatment;
- icon family;
- illustration style;
- hierarchy inside each screen;
- content grouping;
- transitions and microinteractions;
- whether secondary information uses cards, lists, bands, or open sections;
- the names Work, Doctor, and Records if you propose a clearly better, locally testable alternative;
- discoverability of About, privacy, and language settings;
- home dashboard composition;
- how warnings are concise but persistent;
- how the result flows naturally into bounded guidance.

Do not change the underlying functional truth, merge unrelated records, introduce unbuilt services, hide safety disclosures, or make the model sound more capable than it is.

Any proposed navigation-label rename changes ARB localization content and regression expectations. Present it as a separately approved information-architecture/content proposal requiring updated tests and native-language review.

### Current UI problems the redesign must actively solve

- too many similar rounded white cards create a generic “component gallery” feeling;
- repeated green gradient heroes make separate features look interchangeable;
- generic Material icons do not yet create a distinctive KrishiDoc identity;
- disease scanning is duplicated on Work and Doctor without a fully resolved information-architecture rationale;
- Work combines crop context, scan, weather, assistant, and tasks with weak prioritization;
- Doctor places an offline guide and unsent private questions close together, which can confuse what is interactive guidance versus a saved reminder;
- Records feels more like a small analytics dashboard than a visual farm memory;
- truthful safety copy is sometimes visually dense and can overwhelm the primary task;
- long assistant answers need better information scanning and sectional hierarchy;
- seven similar weather rows can feel repetitive and crowded;
- first run lacks a memorable instructional visual language;
- camera controls work but do not yet have the polish and state clarity of a professional camera product;
- disease history lacks the photo-led recognition available from its stored images;
- empty and failure states are functionally present but do not all feel like members of one system;
- the current application does not bundle a Devanagari font, making exact typography depend on the phone manufacturer.

## 20. Required design deliverables

Produce:

1. a short design rationale and the chosen visual concept;
2. three information-architecture/navigation alternatives with concrete trade-offs, followed by one recommended structure;
3. a user-journey map for first use and repeat use;
4. a complete token system for color, typography, spacing, shape, elevation, motion, and icon sizing;
5. the full reusable component library with variants and states;
6. high-fidelity Android phone designs for Screens A through P;
7. compact 320 x 640 examples for the most crowded screens;
8. 2.0x text-scale examples for Language, About, Work, Disease preparation, Result, Assistant, and Weather;
9. representative Nepali and Hindi layouts, not merely English text replaced at the end;
10. clickable prototype flows for first run, disease scan, result-to-guidance, weather, task creation, and photo notebook;
11. annotations for interactions, scrolling, pinned controls, safe areas, keyboard behavior, loading, error, stale, empty, disabled, and destructive states;
12. accessibility annotations for touch size, contrast, reading order, and semantics;
13. Flutter-oriented implementation notes describing responsive behavior and component reuse;
14. an explicit list of functional behaviors preserved and any proposed product changes kept separate from the redesign.

## 21. Quality bar and acceptance criteria

The redesign is successful only if:

- a farmer can find disease scanning from Work or Doctor in one tap;
- weather and crop guidance are each one tap from Work;
- the selected crop is always understandable before capture or guidance;
- the camera explains why the shutter is disabled;
- the result cannot be mistaken for a confirmed laboratory diagnosis;
- treatment, prevention, and control guidance is easy to scan;
- questions cannot be mistaken for messages sent to an expert;
- weather cannot be mistaken for field sensing or an official warning;
- privacy and offline behavior are clear without reading a legal page;
- first-run and scan CTAs remain visible on small screens;
- nothing clips at 2.0x text scale in English, Nepali, or Hindi;
- every interactive element has a minimum 48 dp target;
- loading, empty, failure, stale, offline, missing-photo, and destructive states all look intentionally designed;
- the application feels like one premium product rather than a set of Flutter demo screens;
- the design is feasible to implement in Flutter without replacing working domain logic.

Before presenting the final design, audit every screen against this brief and call out any assumption that is not supported by the described product.

# END MASTER PROMPT

---

# Appendix A — Current technical architecture

KrishiDoc is a Dart/Flutter monorepo with these primary layers:

| Layer | Responsibility |
|---|---|
| `app` | Android Flutter application, routes, screens, localization adapters, providers, camera integration, weather, assistant, and TensorFlow Lite adapter |
| `packages/core_domain` | Framework-independent crop, diagnosis, task, observation, result-state, language, and store contracts |
| `packages/core_data` | Drift/SQLite schema and local store implementations |
| `packages/capture` | Pure-Dart image quality and privacy-safe preparation pipeline |
| `packages/inference` | Model-pack contract, probability calibration, crop scoping, decision resolver, and classifier abstractions |
| `packages/design_system` | Tokens, theme, reusable components, accessibility helpers, and sealed diagnosis presentations |
| `backend` | Early FastAPI identity/idempotency foundation that is not connected to current farmer-app data flows |

Important implementation patterns:

- production database in the app documents directory;
- diagnosis, task, and observation lists are reactive streams;
- immutable diagnosis records are addressed by ID;
- observations are editable because notes belong to the farmer;
- photos are stored as separate local files referenced from database rows;
- IDs are created on the device so records can exist offline immediately;
- navigation state is per app instance;
- locale and first-run routing are resolved before the first Flutter frame to avoid a language flash;
- model metadata and threshold-set version are recorded with every scan for traceability;
- the experimental pack is structurally restricted to possible-match-only decisions;
- future model packs can replace the classifier without rewriting the screens or domain model.

# Appendix B — Current persisted and transient state

| Data | Storage/lifetime |
|---|---|
| Selected language | Persisted locally |
| Selected crop | Persisted locally |
| Selected weather city | Persisted locally |
| Farm work and completion state | Persisted in SQLite |
| Private saved questions | Persisted in SQLite |
| Crop-photo observations and notes | Persisted in SQLite plus local image files |
| Disease scan records | Persisted in SQLite plus local image files |
| Model version and threshold-set version | Persisted per diagnosis record |
| Assistant conversation | In memory for current screen session only |
| Weather response cache | In memory for current app process only |

# Appendix C — Current route inventory

| Route | Screen |
|---|---|
| `/` | Main Work/Doctor/Records shell |
| `/welcome/language` | First-run language chooser |
| `/welcome/about` | First-run or standalone About screen |
| `/capture` | General notebook camera |
| `/diagnose` | Disease-scan preparation |
| `/diagnose/camera` | Disease camera |
| `/assistant` | Offline crop assistant; accepts crop and candidate context |
| `/weather` | Nepal weather |
| `/notebook` | Crop-photo notebook |
| `/notebook/:id` | Observation/photo detail |
| `/history` | Disease-scan history |
| `/result/:id` | Stored result |
| `/dev/result-preview` | Debug-only result-state preview; not a production destination |

# Appendix D — Current design-system primitives

The repository already defines these reusable primitives. Claude Design may refine their appearance, but the resulting system should retain equivalent contracts:

- `KdBrandMark` — code-drawn leaf and field-contour brand mark;
- `KdHeroSurface` — high-emphasis primary-purpose surface;
- `KdIconWell` — consistent icon container;
- `KdStatusPill` — compact metadata/status label;
- `KdSectionHeader` — responsive title, subtitle, and optional action;
- `DiagnosisResultView` — exhaustive possible/confident, uncertain, and out-of-scope rendering;
- shared Material themes for app bars, cards, buttons, chips, fields, navigation, dialogs, sheets, lists, checkboxes, progress, snackbars, and page transitions;
- locale-aware Latin and Devanagari typography;
- centralized spacing, radius, icon, motion, elevation, and semantic color tokens;
- centralized haptic vocabulary;
- testable WCAG contrast calculations.

# Appendix E — Non-features Claude must not accidentally visualize as shipped

- farmer accounts or login;
- cloud backup or multi-device synchronization;
- live agronomist chat;
- delivery/read receipts for saved questions;
- generative AI answers;
- pesticide product or dosage recommendations;
- GPS field detection;
- field-level sensors;
- satellite imagery;
- official DHM warnings or push alerts;
- offline weather forecasts across app restarts;
- marketplace, payments, cooperative ordering, or supply-chain traceability;
- community/social feed;
- voice input, speech playback, or IVR;
- gallery import, torch/flash, zoom, camera switching, image editing, or manual cropping;
- remote model download, model kill switch, or model update UI;
- definitive disease diagnosis;
- Nepal-field-validated accuracy claims;
- Bikram Sambat dates; the current UI uses locale-formatted Gregorian dates and times.

# Appendix F — Source files for implementation cross-checking

- `app/lib/src/router.dart`
- `app/lib/src/home_screen.dart`
- `app/lib/src/welcome/`
- `app/lib/src/diagnosis/`
- `app/lib/src/capture/`
- `app/lib/src/assistant/`
- `app/lib/src/weather/`
- `app/lib/src/notebook/`
- `app/lib/src/history_screen.dart`
- `packages/design_system/lib/src/`
- `packages/core_domain/lib/src/`
- `packages/core_data/lib/src/database/app_database.dart`
- `packages/capture/lib/src/`
- `packages/inference/lib/src/`

# Appendix G — Stable implementation and regression-test contracts

If Claude Design also generates or rewrites Flutter code, preserve these identifiers or provide an explicit migration for the automated tests:

```text
welcome.language.ne
welcome.language.hi
welcome.language.en
welcome.about.continue

home.tab.work
home.tab.ask
home.tab.records
home.work.add
home.ask.save
home.capture
home.detectDisease
home.assistant
home.weather
home.records.viewAllPhotos
home.records.diagnosisHistory

disease.scan.start
disease.crop.tomato
disease.crop.potato

capture.shutter

cropAssistant.question
cropAssistant.ask
cropAssistant.disclosure
cropAssistant.answer

weather.location
weather.refresh
weather.retry
weather.stale
weather.failure

history.empty.action
notebook.capture

observation.note
observation.save
observation.delete
```

Test-sensitive structural rules:

- `capture.shutter` is currently attached to a concrete Flutter `FilledButton`, because tests inspect its enabled/disabled state directly.
- Language selection has no AppBar, Back control, Skip action, preselection, or separate Continue action.
- The first-run About action remains pinned outside the scroll view.
- The disease-camera entry action remains pinned and safe-area aware.
- The empty-history disease-scan action remains pinned.
- The notebook capture action remains pinned.
- The assistant composer remains persistent at the bottom while the conversation scrolls independently.
- Language option semantics expose both button state and an actionable tap.
- Result rendering remains exhaustive over possible/confident, uncertain, and out-of-scope states.
- A coverage-gap result does not offer a misleading retake loop.
- Sample and experimental notices remain permanent and non-dismissible on relevant result/history surfaces.
- Treat 320 x 640, 360 x 800, 412 x 915, and 915 x 412, all three languages, and enlarged text as the required redesign validation matrix. Existing automated tests cover important combinations, but not the complete cross-product on every screen.

# Appendix H — Additional technical facts and boundaries

## Local database

The current Drift/SQLite schema is version 4 and contains:

- `Diagnoses` — crop, tri-state result, ranked predictions, model version, threshold-set version, local photo path, and UTC creation time;
- `Observations` — crop, local photo path, optional note, and UTC creation time;
- `FarmTasks` — title, work/question kind, open/completed state, crop, due date, completion date, and creation date;
- `Settings` — selected language, selected crop, and selected weather city.

Diagnoses are immutable claims: correcting one creates a new record rather than editing the old result. Observations are editable because the optional note belongs to the farmer. Current list windows are 50 diagnoses, 50 observations, and 100 work/question records, newest first.

## Photo and write safety

- model inference finishes before a diagnosis photo is retained;
- the processed image file is written before the database row that references it;
- if the row write fails, the new photo file is removed;
- a missing or operating-system-reclaimed photo does not make its stored diagnosis unusable;
- application code has no photo, note, task, diagnosis, or assistant-question upload path;
- the Flutter client includes no analytics or telemetry SDK;
- there is no explicit application-level encryption layer and the Android manifest does not explicitly disable operating-system backup, so privacy copy should promise “KrishiDoc does not upload this data,” not make unverifiable claims about every possible OS backup mechanism.

## Backend scaffold that is not connected to the farmer UI

The repository contains an early FastAPI foundation with:

- `GET /healthz`;
- `POST /v1/devices` for device registration;
- `POST /v1/auth/refresh` for token rotation;
- Ed25519 public-key validation;
- UUIDv7 device identities;
- JWT access and rotating refresh tokens;
- refresh-token reuse detection;
- request IDs, structured error envelopes, and mutation idempotency.

Its repositories and idempotency store are currently in memory, and the Flutter app never calls these endpoints. There is no current login, farmer profile, cloud record, device-sync, remote inference, remote assistant, or expert-messaging interface. Production signing is also not yet configured for Play Store distribution. These are engineering foundations, not current UI features.
