# KrishiDoc V2 — Principal Product Review and Continuous Iteration

**Review date:** 4 August 2026  
**Reviewed state:** branch `v2`, commit `80eeeff`  
**Review stance:** independent product, design, agriculture, accessibility, performance, and architecture review  
**Quality gate:** a score below 9/10 requires redesign; a production blocker keeps the complete product below gate regardless of average score

This is a review of the product that exists in the repository, not a defense of earlier design decisions and not a score for planned work. The broader audit in `docs/FULL_PRODUCT_AUDIT_AND_REDESIGN.md` remains the detailed repository map. This document challenges that direction, compares alternatives, and turns the strongest revised direction into a release-gated backlog.

## Evidence and limits

- Reviewed all 180 tracked files previously inventoried, then reconfirmed the nine routed Flutter surfaces, shared design-system code, local data layer, inference package, Android shell, FastAPI application, localization, and test structure.
- The shipped product is an Android-first Flutter application with local SQLite storage, camera capture, a notebook, diagnosis history, three launch crops, three languages, and debug-only sample diagnosis.
- The backend supplies health, device registration, token refresh, request IDs, error envelopes, and idempotency. Its repositories are in memory and the Flutter client does not call it.
- There are 75 Dart implementation/test files in `app` and `packages`, 39 test files across Flutter/Dart/Python, and 224 directly declared `test`/`testWidgets` cases. This is meaningful engineering evidence but not field-usability evidence.
- Executable verification remains blocked in this environment: `uv` is unavailable and the configured Flutter executable hangs even for `flutter --version`. Scores are therefore based on static implementation evidence and existing test intent, not a fresh device run.
- Visual scores are provisional until the app is reviewed on low-end Android devices in sun, shade, gloves/wet-hand conditions, Nepali and Hindi at 200% text, TalkBack, poor network, and low storage.

## 1. Executive review

### Verdict

KrishiDoc is **a disciplined prototype of an offline crop-photo notebook**, not a production agriculture platform and not yet a trustworthy crop doctor. Its strongest qualities are honest sample labeling, tri-state diagnosis semantics, clean domain boundaries, localization parity, explicit accessibility semantics, and device-first storage. Its largest problem is not visual polish. It is the gap between the implied promise—crop help—and the actual outcome—a stored photograph with no safe agronomic action.

**Current overall experience: 5.7/10. Production gate: FAIL.**

The score would be lower if the debug diagnosis were presented as real; the code correctly prevents that. It is not higher because a hidden or disabled capability cannot create farmer value.

### What a top product review would criticize

1. **The app has no decisive daily job.** Home is a destination list, not an answer to “What should I do now?”
2. **The signature promise cannot ship.** Inference is a deterministic sample stand-in and no reviewed advisory knowledge base is wired.
3. **Two visible result actions are false affordances.** Expert escalation and correction callbacks do nothing.
4. **Agricultural context is missing.** No farm, plot, season, growth stage, symptoms, weather, or treatment history grounds a recommendation.
5. **The camera judges but does not recover well.** Quality coaching can chatter, the disabled shutter explains nothing on tap, and permission states are collapsed.
6. **The platform ambition is too broad for the evidence.** Weather, market, finance, sensors, schemes, commerce, and community should not become equal top-level modules before the crop-help loop earns trust.
7. **Production infrastructure is absent.** In-memory server state, no app API client, debug release signing, no signed model/content packs, and pre-`runApp` startup failure are release blockers.
8. **Accessibility is code-aware but not field-proven.** Semantic nodes and 48dp targets are good; read-aloud, deterministic Devanagari fonts, stable live regions, 200% toolbar behavior, and outdoor validation are missing.
9. **The brand is generic.** The stock Flutter launcher and largely stock Material composition do not communicate agricultural competence or local identity.
10. **No evidence closes the riskiest assumptions.** There is no farmer research proving comprehension, trust, action safety, repeat use, willingness to share photos, or expert escalation expectations.

### Product decision

Build a **daily decision companion**, but release it in trust rings:

1. **Trust core:** offline handbook, honest real diagnosis, reviewed actions, photo history, recovery, and a real human escalation path.
2. **Daily loop:** lightweight farms/crops, crop stages, tasks, actionable weather, and market snapshots.
3. **Connected ecosystem:** sync, extension-worker review, schemes, sensors, inventory, finance, and carefully separated commerce.

Do not market “AI crop diagnosis” until the complete model → confidence policy → localized label → reviewed action → contraindication → escalation chain passes agronomy, safety, offline, accessibility, and field-comprehension gates.

## 2. Overall scorecard

| Criterion | Score | Why it is below 9 | Gate to reach 9 |
|---|---:|---|---|
| Visual Design | 6 | Coherent tokens, but generic Material surfaces, stock launcher, little brand expression, and no validated outdoor treatment | Distinctive brand, complete state library, device review, and consistent action hierarchy |
| Usability | 6 | Simple local tasks work, but core value is incomplete and capture recovery is weak | Complete end-to-end crop-help loop with observed task success ≥90% |
| Accessibility | 7 | Strong semantics/tap targets; no audio path, font assurance, stable camera live region, or full recovery | WCAG 2.2 AA plus TalkBack and 200% field-device verification |
| Readability | 7 | Plain copy and scalable text, but untranslated model labels and long/scaling toolbar risk remain | Reviewed farmer-language copy and all-locale stress tests |
| Touch Ergonomics | 8 | 48dp discipline is strong; camera and destructive workflows still need real-hand testing | Outdoor one-handed tests, disabled-action feedback, and glove/wet-hand validation |
| Navigation | 4 | Route stack and launcher-style Home do not support a daily multi-module product | Five-destination shell with preserved tab state and contextual deep links |
| Performance | 6 | Background database and image work are sound; startup, camera churn, media growth, and no profiling remain | Budgeted startup/capture/list metrics on low-end devices |
| Consistency | 7 | Shared tokens/theme help, but states and domain components are incomplete | One audited component catalog with no local visual inventions |
| Information Density | 7 | Current screens are restrained; target daily dashboard could become card-heavy | Progressive disclosure and “one primary decision per viewport” validation |
| Learnability | 6 | Language entry is clear, but crop selection, certainty, quality rules, and next steps are under-taught | First-session success without facilitator for low-literacy users |
| Trust | 4 | Honest sample notices help, but no real evidence/advice/expert path and false result actions destroy confidence | Source, freshness, limitations, reviewed actions, and working escalation |
| Farmer Friendliness | 5 | Offline photos and local languages help; farm work, seasonal memory, weather, market, and voice are absent | Repeated field use across representative farmer segments |
| Outdoor Visibility | 6 | Contrast intent is strong; camera overlay and all states are not sun-tested | Sun/shade contrast, large text, and glare tests on representative devices |
| Offline Readiness | 7 | Core storage/capture are local; content packs, sync, weather/market freshness, and conflict UX do not exist | Complete offline journeys with visible freshness and recoverable outbox |
| AI Integration | 1 | No production model, calibration, monitoring, or safe advisory chain | Validated model and explicit human/knowledge safety layers |
| Scalability | 4 | Good ports/modules, but local schemas are thin and server/client integration is absent | Durable services, versioned sync, observability, authorization, and pack operations |
| Localization | 7 | ARB parity across English/Nepali/Hindi is strong; content, audio, model labels, and font validation are absent | Reviewed agricultural glossary, audio, content fallback, and locale QA |
| Error Prevention | 6 | Delete confirmation and tri-state logic help; startup, photo lifecycle, camera, and no-op actions remain | Typed recoverable states, transactional ownership, and safety checks |
| Delight | 4 | Functional restraint but little warmth, progress, recognition, or agricultural identity | Calm feedback, useful progress, respectful personalization, and brand craft |
| Overall Experience | **5.7** | Solid prototype engineering cannot compensate for incomplete farmer outcomes | All Critical gates closed and every core journey ≥9 after field validation |

### Quality-gate interpretation

No criterion reaches 9. This does not require twenty unrelated redesign projects. Several root fixes lift multiple scores:

- Completing a safe crop-help outcome improves usability, trust, farmer friendliness, AI, learnability, and error prevention.
- A stable five-destination shell improves navigation, consistency, scalability, and learnability.
- A shared stated-component system improves accessibility, performance perception, visual consistency, and recovery.
- Field validation in regional languages improves readability, accessibility, outdoor visibility, touch ergonomics, and trust.

## 3. Feature-by-feature evaluation

### 3.1 First run and language

**Objective:** let a first-time user choose a readable language and understand the app without account friction.  
**Actual outcome:** one-tap endonym selection is unusually direct, but the following About screen explains limitations more clearly than it establishes immediate value.

**Problems:** no literacy/audio aid; no “change later” reassurance; no country/region or crop relevance; no progressive permission education; selection immediately navigates, making accidental taps harder to reverse; the first useful action is still another screen away.

| Redesign level | Proposal | Strength | Weakness |
|---|---|---|---|
| Conservative | Retain one-tap language cards; add speaker previews and “You can change this later” | Low risk and preserves speed | Does not personalize useful content |
| Moderate | Language → one-screen value promise → optional “choose crops near me” after first useful action | Builds relevance without blocking entry | Adds controlled onboarding state |
| Bold | Voice-led setup with spoken language/crop questions | Helps some low-literacy users | Speech recognition is fragile, private, and connectivity-sensitive |
| Future-looking | SIM/region/crop-calendar assisted setup with household profiles | Potentially contextual | High consent, accuracy, and shared-device risk |

**Selected:** Moderate, with the conservative audio preview. First value must remain available without account, location, or profile completion.

### 3.2 Home and navigation

**Objective:** expose the application’s useful destinations.  
**Actual outcome:** a clean launcher list works for the prototype but creates no daily reason to return and will collapse under the requested platform breadth.

**Problems:** no persistent navigation; no current farm/crop context; History is effectively empty in release; About occupies prime hierarchy; debug tools mix with product destinations in debug; no notifications/tasks/weather/market synthesis; no saved tab state or cross-module search.

| Redesign level | Proposal | Strength | Weakness |
|---|---|---|---|
| Conservative | Keep Home list, reorder by frequency, hide unavailable rows | Fastest change | Still a menu, not a decision surface |
| Moderate | Persistent Today / My Farm / Doctor / Market / More shell | Supports daily loop and clear mental model | Risks empty/card-heavy Today before data exists |
| Bold | Single conversational “What do you need?” home with voice/photo/text | Low apparent complexity | Poor scanability, discoverability, and trust for high-stakes advice |
| Future-looking | Predictive farm command center driven by weather, satellite, sensors, and tasks | High proactive value | Data dependencies, false urgency, and exclusion of smallholders |

**Selected:** Moderate. Today must degrade gracefully to handbook, saved crops, and one clear Doctor action; it must not fabricate personalization when data is absent.

### 3.3 Camera capture and quality coaching

**Objective:** obtain a diagnostically useful image while minimizing farmer error.  
**Actual outcome:** live brightness/blur coaching, safe-area composition, crop memory, off-UI processing, and double-tap protection are strong foundations.

**Problems:** 5 Hz decisions can flicker; accessibility announcements can chatter; the disabled shutter gives no causal response; default crop can silently bias inference; permission/no-camera/init errors collapse; no gallery, torch, tap focus, manual override, framing guide, or multi-photo support; “good photo” is not “diagnostically sufficient context.”

| Redesign level | Proposal | Strength | Weakness |
|---|---|---|---|
| Conservative | Add hysteresis, minimum message duration, retry/settings, and disabled-tap explanation | Fixes immediate harm | Still single-photo and context-poor |
| Moderate | Guided sequence: crop confirmation → symptom type → 1–3 guided photos → review | Better model input and farmer understanding | More steps; must allow fast path |
| Bold | Real-time overlay that detects leaf/lesion and auto-captures | Lowers manual burden | Model/device cost and false capture risk |
| Future-looking | Multimodal field scan combining photos, voice symptoms, weather, and sensor context | Better diagnostic context | Complex consent, calibration, and offline footprint |

**Selected:** Moderate with a one-photo fast path when confidence and coverage permit. Quality gates advise; they must never trap the user without explanation or override.

### 3.4 Diagnosis and result

**Objective:** help a farmer safely decide what to do after observing a crop problem.  
**Actual outcome:** the domain correctly distinguishes confident, uncertain, and out-of-scope results and permanently marks sample records. The shipped classifier is not diagnostic and the result has no actionable agronomy.

**Problems:** sample hash classifier; no localized disease knowledge; raw labels; no symptom comparison; no “do now / avoid / monitor” actions; no contraindications, dose governance, source/freshness, model limitations, or uncertainty explanation; expert and correction buttons are no-ops; no follow-up outcome capture; no crop-stage/weather context.

| Redesign level | Proposal | Strength | Weakness |
|---|---|---|---|
| Conservative | Remove nonworking buttons and ship notebook only | Honest and safe | Does not fulfill crop-doctor proposition |
| Moderate | Real tri-state diagnosis linked to reviewed offline action cards and working escalation | Creates a complete, bounded outcome | Requires serious ML, content, and operational governance |
| Bold | Generative agronomist writes personalized treatment plans | Flexible and compelling | Hallucination, pesticide, liability, and localization risk |
| Future-looking | Closed-loop diagnosis with field sensors, outcome learning, and agronomist oversight | Could improve relevance over time | Bias, privacy, causality, and operational complexity |

**Selected:** Moderate. Generative AI may summarize reviewed content or translate a farmer’s question, but may not invent diagnosis, dose, waiting period, or chemical mixing advice.

### 3.5 Notebook, observation detail, and history

**Objective:** preserve field memory and allow a farmer to revisit changes over time.  
**Actual outcome:** local photo/date/note records are useful and modest; diagnoses and observations are separated cleanly in the domain.

**Problems:** no farm/plot/season/stage link; no timeline comparison; no tags/tasks/treatment/outcome; separate History and Notebook mental models; saved-state and failure feedback are weak; deletion does not own photo cleanup; failed writes can orphan media; no storage budget, export, backup, or sync; diagnosis names can expose raw labels.

| Redesign level | Proposal | Strength | Weakness |
|---|---|---|---|
| Conservative | Fix save/delete/media ownership; add error recovery | Essential reliability | Thin long-term value |
| Moderate | Unified crop timeline with observations, diagnoses, actions, tasks, and outcomes | Matches seasonal memory | Requires schema and navigation migration |
| Bold | Auto-generated seasonal journal and recommendations | Reduces manual entry | Can infer incorrectly and obscure raw facts |
| Future-looking | Shared farm record for family, cooperatives, buyers, and extension workers | Powerful continuity | Ownership, consent, conflict, and surveillance risks |

**Selected:** Moderate. Keep raw observations immutable/auditable and label generated summaries separately.

### 3.6 Weather, market, irrigation, expenses, inventory, schemes, and experts

**Objective:** support real farm decisions beyond diagnosis.  
**Actual outcome:** these workflows do not exist. Architecture seam documents are not product capability.

Adding all of them at once would produce a shallow super-app. Sequence by frequency, data trust, and ability to recommend an action:

1. Experts as the safety net for diagnosis.
2. Crop-stage tasks and actionable weather.
3. Market price snapshots with source/freshness and saved markets.
4. Seasonal expense/input records.
5. Schemes only with eligibility, source, deadline, and application path.
6. Irrigation and inventory when farm records make them contextual.
7. Sensors, satellite, finance, and commerce only through validated partner pilots.

### 3.7 Device identity and backend platform

**Objective:** provide anonymous/device-based identity, reliable write replay, and a foundation for future sync.  
**Actual outcome:** ports, token rotation concepts, request IDs, typed errors, and middleware tests are good foundations; in-memory state and no client integration make the service non-durable and non-product.

**Selected redesign:** retain the modular-monolith boundary, replace repositories with PostgreSQL/Redis adapters, prove possession of the device key, protect refresh material with Android Keystore, create a versioned sync/outbox contract, implement authorization and deletion/export, and deploy observability before adding product modules. Microservices are not justified.

## 4. Screen-by-screen scorecard and critique

### Score legend

`VD` Visual Design · `US` Usability · `AX` Accessibility · `RD` Readability · `TE` Touch Ergonomics · `NV` Navigation · `PF` Performance · `CS` Consistency · `ID` Information Density · `LN` Learnability · `TR` Trust · `FF` Farmer Friendliness · `OV` Outdoor Visibility · `OF` Offline Readiness · `AI` AI Integration · `SC` Scalability · `L10N` Localization · `EP` Error Prevention · `DL` Delight · `OA` Overall Experience

#### A. Presentation and interaction

| Screen | VD | US | AX | RD | TE |
|---|---:|---:|---:|---:|---:|
| First-run language | 7 | 8 | 8 | 8 | 8 |
| About / how it works | 7 | 7 | 8 | 8 | 8 |
| Home | 6 | 6 | 8 | 7 | 8 |
| Capture | 7 | 6 | 6 | 7 | 7 |
| Notebook | 7 | 7 | 8 | 8 | 8 |
| Observation detail | 6 | 6 | 7 | 7 | 8 |
| Diagnosis history | 6 | 5 | 7 | 6 | 8 |
| Diagnosis result | 6 | 3 | 5 | 6 | 7 |
| Debug result preview | 6 | 5 | 7 | 7 | 8 |

#### B. Structure and cognition

| Screen | NV | PF | CS | ID | LN |
|---|---:|---:|---:|---:|---:|
| First-run language | 7 | 8 | 8 | 8 | 8 |
| About / how it works | 7 | 8 | 8 | 8 | 7 |
| Home | 3 | 8 | 7 | 7 | 6 |
| Capture | 6 | 6 | 7 | 7 | 5 |
| Notebook | 6 | 7 | 8 | 8 | 7 |
| Observation detail | 6 | 7 | 7 | 7 | 7 |
| Diagnosis history | 5 | 7 | 7 | 7 | 5 |
| Diagnosis result | 5 | 7 | 7 | 6 | 4 |
| Debug result preview | 4 | 8 | 7 | 7 | 6 |

#### C. Agricultural fitness

| Screen | TR | FF | OV | OF | AI |
|---|---:|---:|---:|---:|---:|
| First-run language | 7 | 7 | 7 | 9 | 1 |
| About / how it works | 8 | 6 | 7 | 9 | 1 |
| Home | 6 | 4 | 7 | 9 | 1 |
| Capture | 6 | 6 | 6 | 8 | 2 |
| Notebook | 8 | 7 | 7 | 9 | 1 |
| Observation detail | 7 | 6 | 7 | 9 | 1 |
| Diagnosis history | 4 | 4 | 7 | 9 | 1 |
| Diagnosis result | 2 | 3 | 6 | 8 | 1 |
| Debug result preview | 8 | 3 | 7 | 9 | 1 |

#### D. Product maturity

| Screen | SC | L10N | EP | DL | OA |
|---|---:|---:|---:|---:|---:|
| First-run language | 7 | 8 | 7 | 6 | **7.2** |
| About / how it works | 7 | 8 | 7 | 5 | **7.1** |
| Home | 3 | 8 | 6 | 4 | **6.0** |
| Capture | 5 | 8 | 5 | 6 | **6.1** |
| Notebook | 6 | 8 | 7 | 5 | **6.9** |
| Observation detail | 5 | 8 | 5 | 4 | **6.3** |
| Diagnosis history | 4 | 5 | 5 | 4 | **5.6** |
| Diagnosis result | 3 | 4 | 2 | 3 | **4.6** |
| Debug result preview | 2 | 8 | 8 | 4 | **6.1** |

The 9/10 offline scores recognize that these individual static surfaces work without a connection. They do not imply complete offline readiness for content, models, sync, weather, market data, or expert escalation.

### Required redesign by screen

| Screen | Objective | Main failure | Strongest redesign | Acceptance gate |
|---|---|---|---|---|
| First-run language | Choose comprehension mode immediately | No audio/literacy support or reversibility cue | Keep one-tap cards; add speaker sample and “change later” | 95% choose intended language without facilitator |
| About | Set expectations and start useful work | Describes absence more than farmer value | “How KrishiDoc helps” with one live promise and one CTA | User can state value and limitation after one reading |
| Home | Answer what matters now | Static launcher, no daily context | Today surface with one urgent item, one task, one Doctor CTA | First useful action within 5 seconds; no empty dead cards |
| Capture | Obtain sufficient evidence | Chatter, ambiguous disabled state, collapsed failure recovery | Guided, stabilized 1–3 photo flow with explicit crop/context | ≥90% usable capture; every failure offers recovery |
| Notebook | Find and continue field memory | Flat photo list lacks farm/crop timeline | Unified crop timeline with filters and outcomes | Entry found in ≤10 seconds with 100+ records |
| Observation detail | Add meaning safely | Thin note model, silent save failure, orphan-prone delete | Structured context plus explicit saved/error state and media ownership | Save/delete atomic; storage reclaimed and announced accurately |
| Diagnosis history | Revisit trustworthy decisions | Raw labels, no retry/filter, separate mental model | Fold into crop timeline; show reviewed name/state/freshness | No internal key visible; error is recoverable |
| Diagnosis result | Decide safely | No real inference/advice and two no-op actions | Answer → why → do now → avoid → monitor → expert → source | Every action works; agronomy and comprehension approval |
| Debug preview | Test tri-state presentation | Developer surface can be confused with product if leaked | Keep behind debug-only route and golden/accessibility tests | Release binary proves route and sample pack unreachable |

## 5. UI critique

### Buttons

- Strength: theme enforces generous control height and clear filled/outlined hierarchy.
- Failure: an enabled button with a no-op callback is worse than a disabled button because it creates false trust and an accessibility lie.
- Rule: render no action until it has a real outcome. Loading keeps the label visible, adds progress, blocks duplicate submission, and announces completion/failure.

### Cards and rows

- Strength: generous padding and full-row semantics support touch.
- Failure: too many target concepts are proposed as cards, which can make Today a vertically scrolling brochure.
- Rule: reserve cards for bounded objects or decisions. Use section rhythm and lists for related items. The top viewport gets one primary decision, not four competing cards.

### Forms

- Current product barely exercises forms beyond a note field.
- Future farm, task, expense, and inventory forms must use defaults, recent values, local units, input masks, autosave, clear required/optional labels, and review before high-impact submission.
- Voice can fill a form but must show the interpreted value for correction.

### Search, lists, filters, maps, charts, and tables

- Search, maps, charts, tables, and filters are absent. Do not add generic global search before there is enough content.
- First search targets: handbook conditions, crops, tasks, markets, and records. Results must be grouped by type and work offline for installed content.
- Maps are secondary to a text distance/direction option. Never make a map the only expert or market discovery surface.
- Weather and market charts should answer a decision, not display data. Examples: “Rain likely before spraying window” and “Price updated 2h ago; 12 km market.”

### Bottom navigation and action placement

- Use Today / My Farm / Doctor / Market / More when at least three destinations have real value.
- Doctor may be visually emphasized but must remain a standard semantic navigation destination, not a floating element with a different mental model.
- Do not add a global FAB. Use contextual actions such as “Add observation” within a crop timeline.

### Typography, spacing, color, and icons

- Retain existing spacing/token discipline and high-contrast semantic colors.
- Bundle and test a reviewed Devanagari font; prohibit letter spacing on joined scripts.
- Color never communicates diagnosis state alone; pair with icon, phrase, and action.
- Replace the stock launcher. Use one coherent icon family and label unfamiliar agriculture actions.
- Clamp nonessential toolbar title scaling only when the full scalable page heading remains in content.

### Motion and feedback

- Motion must explain state: capture freeze, queued sync, saved confirmation, timeline insertion, and expanding evidence.
- Honor reduced motion. Avoid celebratory motion for diagnoses or serious crop risk.
- Haptics reinforce a visible outcome; they never replace it.

### State completeness

Every async/data component requires: uninitialized, loading, delayed loading, empty, stale/offline, partial, success, recoverable error, terminal error, permission denied, and unsupported-device states where relevant. Skeletons are appropriate only when geometry is predictable; otherwise a short labeled loader is more honest.

## 6. UX critique

### Information architecture

The prototype’s route list is appropriate for a prototype but not a platform. The strongest revised hierarchy is:

```text
Today
├── one urgent decision
├── next farm task
├── crop health follow-up
└── weather/market freshness

My Farm
├── farms and plots
├── active crop cycles
├── crop timeline
├── tasks and observations
└── seasonal records

Doctor
├── diagnose from camera/gallery
├── offline handbook
├── recent follow-ups
└── expert escalation

Market
├── saved crops/markets
├── sourced price snapshots
└── watchlist alerts

More
├── language and audio
├── offline downloads/storage
├── notifications and privacy
├── schemes/support
└── about/data controls
```

### Task completion

- **Diagnose:** target ≤60 seconds for one-photo fast path, ≤3 minutes for guided multi-photo, with a useful uncertain outcome rather than forced certainty.
- **Record field change:** target ≤20 seconds from crop timeline, prefilled crop/plot/date.
- **Check weather action:** target ≤10 seconds to understand action, time window, source, and freshness.
- **Check market:** target ≤15 seconds for saved crop/market, unit normalization, source, and updated time.
- **Reach expert:** target ≤2 minutes including consented share preview, queued offline request, cost/hours expectation, and fallback phone path.

### Onboarding and permissions

Ask for camera only at capture, notifications only when creating a reminder/alert, location only when its benefit is visible, and media/network upload only through a share manifest. Never require an account before local value. Explain what stays on the phone and what will leave it.

### Returning, power, low-literacy, senior, shared-device, and offline users

- Returning users land on Today with the last active crop and stale/fresh labels, not an onboarding carousel.
- Power users get recent actions, filters, batch task completion, and export—not denser default screens.
- Low-literacy support combines plain regional language, human-recorded audio, photos, icons, and confirmation; voice-only design is not accessible to everyone.
- Senior users need stable layouts, larger targets, reduced time pressure, and no swipe-only actions.
- Shared-device profiles are optional and locally protected; avoid exposing financial/health-like farm records on the lock-screen notification.
- Offline users can capture, read installed guidance, add records, and queue expert/sync actions. The app distinguishes “saved on this phone” from “sent.”

## 7. Accessibility report

### Strengths to preserve

- Intentional `Semantics`/`ExcludeSemantics` composition for full-row controls.
- Minimum control sizing and scalable icon helper.
- Diagnosis state uses words and icons rather than color only.
- Three ARB catalogs have key parity and language names are endonyms.
- Camera instruction is presented on an opaque contrast-controlled surface.
- Confirmation exists before destructive row deletion.

### Critical and high gaps

| Priority | Gap | Required correction |
|---|---|---|
| Critical | Enabled result actions have no outcome | Hide until implemented or wire a complete reachable outcome; test semantic activation |
| High | No read-aloud/human audio for core guidance | Human recordings for critical content; labeled TTS fallback; downloadable packs |
| High | Devanagari rendering depends on device fonts | Bundle a reviewed font subset and test ligatures, clipping, and weights |
| High | Camera live messages can change/announce at 5 Hz | Hysteresis, 900ms minimum hold, deduplicated polite live region |
| High | Permission/error states lack differentiated recovery | Separate denied, permanently denied, restricted, unavailable, init failure, and retry |
| High | AppBar titles risk clipping at 200% | Full page heading in body; responsive toolbar behavior; all-locale device tests |
| High | Product has no validated low-literacy interaction model | Moderated comprehension testing using tasks, not preference questions |
| Medium | Dates/units may not match local expectations | Locale-aware relative date plus accessible exact value and explicit units |
| Medium | Dynamic content focus behavior is unspecified | Focus/announcement rules for route, result, dialogs, save, queue, and errors |
| Medium | No switch/keyboard test evidence | Add focus order, activation, and visible-focus coverage where Android input supports it |

### Accessibility acceptance gate

WCAG 2.2 AA automated checks are necessary but insufficient. Core journeys must pass TalkBack, 200% text, large display, reduced motion, grayscale/color-vision checks, switch access, screen magnification, outdoor glare, and regional-language comprehension on representative low-end Android hardware.

## 8. Performance report

### Current strengths

- Drift opens SQLite work on a background isolate.
- Image preparation is designed off the UI isolate.
- Frame quality calculation samples pixels rather than processing every pixel.
- Stream providers and bounded recent queries avoid an obvious all-record startup load.
- Offline-first local writes avoid network latency for current notebook tasks.

### Risks

| Priority | Risk | User effect | Budget/gate |
|---|---|---|---|
| Critical | Database/photo-store open before `runApp` without fallback | Black screen on corrupt storage or platform failure | First frame always appears with recovery shell |
| High | Camera assessment can rebuild/chatter at 5 Hz | Flicker, battery/thermal load, unstable shutter | Profile frame build/raster; no visible state faster than hold threshold |
| High | JPEG files have no lifecycle/storage budget | Low-storage failure and private orphaned media | Atomic ownership, cleanup queue, quota UI, low-storage tests |
| High | Model/content pack strategy is not implemented | Large install, failed updates, incompatible packs | Signed manifest, resumable update, rollback, version compatibility |
| High | No low-end device profile | Unknown capture/result responsiveness | P95 budgets on representative 2–4GB Android devices |
| Medium | Large histories need pagination and thumbnail strategy | Slow lists and memory pressure | Paginated timeline; generated thumbnails; image cache bounds |
| Medium | Sync/weather/market may wake radio excessively | Battery/data cost | Batched outbox, OS scheduling, user-visible data controls |

### Initial performance budgets

- Cold start to interactive recovery-capable shell: P95 ≤2.5s on target low-end device.
- Warm start: P95 ≤1.0s.
- Camera open to usable preview: P95 ≤2.0s.
- Shutter feedback: ≤100ms; frozen confirmation frame ≤250ms.
- Local save acknowledgement: P95 ≤300ms, with durable queue semantics.
- On-device result after accepted capture: target P95 ≤3s; always show staged progress after 400ms.
- Today local render: P95 ≤500ms after shell; network refresh never blocks local content.
- Scroll: no sustained frame misses; verify at 60Hz with image-heavy 500-record timeline.
- Background data: user-configurable download policy and size displayed before model/audio/content packs.

## 9. Technical architecture review

### Strong decisions

- Pure Dart `core_domain` separates truth-bearing models from Flutter.
- Store, classifier, camera, catalog, and photo ports improve testability.
- Drift mappings and migration test intent centralize persistence rules.
- Tri-state exhaustive result modeling is safer than one always-confident answer.
- FastAPI uses an application factory, injectable ports, typed error envelope, request IDs, and strict tooling configuration.
- Sample outputs remain permanently identifiable by model-version marker.

### Production blockers

| Priority | Finding | Required architecture change |
|---|---|---|
| Critical | Only `SampleClassifier` is wired | Production inference adapter, calibrated pack, device compatibility and release guard |
| Critical | No knowledge/advisory runtime | Versioned localized KB, agronomy workflow, source/freshness, signed packs, diagnosis mapping |
| Critical | Flutter has no API/sync client | Typed client, device proof, secure token store, network state, outbox, conflict contract |
| Critical | Server repositories are in memory | PostgreSQL device/consent/domain storage and Redis idempotency/replay with migrations |
| Critical | Release uses debug signing | Production signing outside repository and CI artifact verification |
| Critical | Startup has no recovery composition root | Start recovery shell first; open/migrate stores as typed state with retry/reset/export path |
| High | Photo/row writes have no transaction owner | Media staging, atomic row commit, cleanup queue, deletion cascade, integrity sweep |
| High | No signed pack operations | Trust root, signature/hash, compatibility, atomic activation, rollback, revoke/kill switch |
| High | No observability/deployment | Structured product metrics with privacy, traces, crash reporting, SLOs, runtime manifests |
| High | ADR numbering conflicts with handbook specification | Reconcile index and reserve new immutable decision numbers |

### Target architecture

Keep a modular monolith until scale proves otherwise:

```text
Flutter feature slices
  presentation + application state
        ↓ ports
  local Drift databases + file vault + outbox
        ↓ typed API / pack manager
FastAPI modular monolith
  identity | sync | farms | knowledge | diagnosis | experts | market
        ↓
PostgreSQL + object storage + Redis + signed content/model registry
```

Use separate local databases or clearly separated schemas for user records, knowledge content, and sync metadata so content-pack replacement cannot endanger farmer records. Sync sends client-minted immutable event IDs, is idempotent, and resolves conflicts per field/domain rather than last-write-wins globally.

### Security and privacy gate

- Prove possession of registered public keys.
- Store refresh secrets via Android Keystore and revoke rotation reuse.
- Encrypt transport; encrypt sensitive server fields and backups; document local-at-rest posture.
- Explicitly decide Android backup inclusion for photos, tokens, databases, and downloaded packs.
- Show a per-share manifest for expert escalation; upload nothing silently.
- Implement consent versioning, export, deletion cascade, retention, audit, authorization tests, and abuse limits.
- Do not train on farmer photos by default. Training consent is separate, revocable, and purpose-specific.

## 10. Design system audit

### Retain

- Semantic color roles and contrast tests.
- Central spacing, icon sizing, control height, typography helpers, and Material theming.
- One shared diagnosis-state view rather than screen-specific state rendering.
- Script-aware typography decision that avoids letter spacing in Devanagari.

### Correct

1. Rename tokens by role and component intent, not incidental current values.
2. Add surface/state tokens for stale, offline, queued, synced, warning, destructive, and evidence confidence.
3. Create shared components: `KdPageHeading`, `KdPrimaryDecision`, `KdAsyncState`, `KdOfflineBanner`, `KdFreshness`, `KdSource`, `KdAudioControl`, `KdPermissionRecovery`, `KdProgressSteps`, `KdTimelineItem`, `KdEmptyState`, and `KdConfirmation`.
4. Specify density rules for compact devices and text scaling rather than ad hoc screen exceptions.
5. Add component semantics, focus behavior, loading rules, content limits, localization examples, and golden tests to the catalog.
6. Add real illustration/photo guidance only when it teaches capture, symptoms, or a task. Decorative farm imagery must not compete with urgent content.
7. Replace generic launcher/splash and define a calm, competent agricultural brand—not a neon “AI” aesthetic.

### Governance

- A component enters the system only after two real usages or clear cross-product need.
- No new raw color, radius, spacing, control height, or text style in feature code without system review.
- Every shared component ships with English/Nepali/Hindi, 200% text, TalkBack, light/dark if supported, offline/stale, and error examples.
- Deprecations have migration notes and repository checks; screenshots are evidence, not the source of truth.

## 11. Competitive benchmark

Current official product material was used to compare patterns, not to award feature-count points. KrishiDoc should learn from each product’s clearest job while avoiding a collage of unrelated modules.

| Benchmark | Strong pattern to study | KrishiDoc response | What not to copy |
|---|---|---|---|
| [Plantix](https://plantix.net/en/) | Crop-problem entry is direct and visually legible | Make Doctor a first-class destination and connect every result to reviewed next actions | Do not imply broad condition coverage before local validation |
| [OneSoil](https://onesoil.ai/en/platform) | Field-centered scouting and remote crop visibility form a coherent spatial workflow | Add plot context only after the smallholder crop timeline is useful without satellite data | Do not make maps or NDVI the default for farmers without reliable boundaries/data |
| [John Deere Operations Center](https://operationscenter.deere.com/) | Operational records and connected-machine data support ongoing farm management | Preserve interoperable farm/event models and export seams | Do not import enterprise machinery complexity into the smallholder core |
| [Climate FieldView](https://dev.fieldview.com/) | Platform value grows through connected field data and developer integration | Version APIs/events and maintain partner seams after core data ownership is stable | Do not prioritize ecosystem breadth before a durable farmer record exists |
| [Cropin](https://www.cropin.com/intelligent-agriculture-cloud/) | Enterprise agriculture separates data, intelligence, and operational layers | Keep knowledge, user records, inference, and sync as governed bounded contexts | Do not expose enterprise terminology or dashboards to the farmer app |
| [Kisan Suvidha](https://www.pib.gov.in/newsite/PrintRelease.aspx?lang=2&reg=48&relid=186555) | Government-backed utility bundles weather, market, protection, and advisory information | Treat source, jurisdiction, freshness, and actionability as core UI attributes | Do not reproduce a portal menu with many shallow destinations |
| [AgroStar](https://corporate.agrostar.in/solutions/farm-advisory) | Advisory is paired with agronomic operations and human support | Make expert capacity and reviewed advice part of the service design | Do not allow commerce incentives to rank diagnosis or treatment advice |

**Competitive conclusion:** KrishiDoc cannot win by matching module lists. Its defensible experience is a locally credible, offline-capable chain from observation to safe action to seasonal memory. Competitors’ mapping, enterprise, marketplace, and ecosystem strengths should become optional layers, not the core information architecture.

## 12. Missing opportunities

### Highest-value unmet farmer workflows

| Workflow | Current | Recommended position | Why |
|---|---|---|---|
| Safe crop diagnosis | Debug sample only | Trust core | Central promise and safety risk |
| Offline handbook | Specification only | Trust core | Useful without model/network and supports result actions |
| Expert support | No-op button | Trust core | Safety net for uncertainty/out-of-scope |
| Disease/observation history | Thin local lists | Trust core | Enables follow-up and seasonal memory |
| Multiple farms/plots/crop cycles | Absent | Daily loop | Context for every later recommendation |
| Crop stages/tasks | Absent | Daily loop | Frequent, actionable return behavior |
| Weather alerts | Absent | Daily loop | High-frequency operational decisions |
| Market prices | Absent | Daily loop pilot | Economic value if source/unit/freshness are trustworthy |
| Expenses/season records | Absent | Next | Helps profitability memory after crop model exists |
| Inventory | Absent | Later | Useful when tasks/expenses share input data |
| Schemes | Absent | Partner pilot | High value but freshness/eligibility burden |
| Irrigation/sensors/satellite | Absent | Later partner layer | Cost, coverage, calibration, and farm-size fit |
| Voice | Absent | Cross-cutting access layer | Helps entry/read-aloud; must not be sole interface |

### Opportunities to decline for now

- Social feed, gamification streaks, public leaderboards, generic chat, embedded loan offers, input marketplace, autonomous pesticide plans, and satellite dashboards without actionable ground truth.
- These features increase moderation, conflict of interest, cognitive load, or safety exposure before the trust core is established.

## 13. Quick wins

| Priority | Change | Effort | Expected lift |
|---|---|---:|---|
| Critical | Hide expert/correction actions until they work | S | Trust, accessibility, error prevention |
| Critical | Replace debug release signing and add CI guard | S–M | Security and release integrity |
| Critical | Put a localized recovery shell before store initialization | M | Reliability and perceived performance |
| High | Add camera hysteresis/minimum message hold | M | Usability, accessibility, outdoor capture |
| High | Split camera permission/init/no-hardware errors with retry/settings | M | Recovery and learnability |
| High | Make photo deletion/write cleanup owned and testable | M | Storage, privacy, trust |
| High | Replace raw model labels through a reviewed localization registry | S–M | Readability, localization, safety |
| High | Bundle/test Devanagari font and 200% toolbar behavior | M | Accessibility and consistency |
| Medium | Replace stock launcher/splash | S–M | Trust and visual identity |
| Medium | Change About framing to live value plus limits | S | First-use comprehension |
| Medium | Add retry to History and explicit saved/error feedback to detail | S | Recovery |
| Low | Move debug routes out of Home into a developer-only harness | S | Product cleanliness |

## 14. High-impact improvements

1. **Ship the offline handbook before or with real diagnosis.** It creates standalone value and gives every result a governed action destination.
2. **Complete the trust chain.** Real model, calibration, localized labels, reviewed advice, uncertainty, working escalation, correction, monitoring, and kill switch are one release unit.
3. **Unify farm memory.** Replace separate notebook/history concepts with an active crop timeline that preserves facts, decisions, actions, and outcomes.
4. **Create Today only after it has real signals.** A task, follow-up, weather action, and market freshness should be computed from user-owned data, never decorative placeholders.
5. **Make offline state legible.** “Saved on this phone,” “queued,” “sent,” “stale,” “downloaded,” and “needs connection” must be distinct across the product.
6. **Build field validation into delivery.** Every sprint includes representative farmers, languages, devices, outdoor conditions, and observed tasks.

## 15. Long-term roadmap

### Phase 0 — Release safety (0–4 weeks)

Remove false actions, fix signing/startup/media lifecycle, stabilize camera, resolve ADR numbering, establish performance/accessibility baselines, and keep diagnosis non-distributable.

### Phase 1 — Trust core (1–3 months)

Offline reviewed handbook; localized content/audio; real expert directory/request path; crop/symptom search; working source/freshness; production data/pack infrastructure.

### Phase 2 — Real Crop Doctor pilot (3–6 months)

One or two crops and tightly defined conditions; guided capture; calibrated tri-state result; safe action cards; correction/outcome follow-up; kill switch; agronomist monitoring; staged regional pilot.

### Phase 3 — Daily farm loop (6–9 months)

Farm/plot/crop cycle, stages, tasks/reminders, unified timeline, actionable weather with freshness, and a lightweight Today surface.

### Phase 4 — Economic decisions and sync (9–12 months)

Durable cross-device sync, expert collaboration, market pilot with normalized units/source/freshness, seasonal expenses, export, and cooperative/extension workflows.

### Phase 5 — Partner ecosystem (12+ months, evidence-triggered)

Schemes, inventory, irrigation, sensors, satellite, and financial referrals only where coverage, governance, farmer demand, and sustainable operations are proven.

## 16. Prioritized backlog

### P0 — Release blockers

| ID | Backlog item | Acceptance result |
|---|---|---|
| P0-01 | Remove all reachable no-op actions | Every enabled semantic action changes state, navigates, communicates, or submits successfully |
| P0-02 | Production signing | Release build fails if debug signing is selected; secrets are outside repository |
| P0-03 | Startup recovery shell | Store/migration/photo failure renders localized retry/reset/export-support path, never black |
| P0-04 | Product/sample separation | Release artifact cannot reach sample classifier, pack, record, notice-only result, or debug preview |
| P0-05 | Photo transaction ownership | Failed save/delete cannot leak untracked media; integrity sweep and low-storage path tested |
| P0-06 | Durable identity/idempotency | Restart preserves device and replay state; concurrency and revocation tests pass |
| P0-07 | Decision record repair | ADR index has immutable unique IDs; handbook decisions receive new numbers |

### P1 — Trust-core requirements

| ID | Backlog item | Acceptance result |
|---|---|---|
| P1-01 | Offline KB runtime | Signed localized content pack installs, validates, activates atomically, rolls back, and searches offline |
| P1-02 | Agronomy governance | Every action has reviewer, jurisdiction, crop/stage scope, source, version, contraindication, and expiry |
| P1-03 | Camera recovery/stability | Hysteresis, explanation, retry/settings, gallery, crop confirmation, and low-end performance pass |
| P1-04 | Working expert escalation | Cost/hours/availability shown; share preview and offline queue work; fallback is clear |
| P1-05 | Real inference pilot | Validated model/calibration/device budget; safe threshold policy; out-of-scope and kill switch work |
| P1-06 | Result redesign | Answer, evidence, action, avoid, monitor, expert, source, and follow-up are complete in all locales |
| P1-07 | Accessibility foundation | Font/audio/live-region/focus/state components pass specified device matrix |
| P1-08 | App/API sync foundation | Secure device proof, token vault, outbox, freshness, retry, conflict, export, and deletion work |

### P2 — Daily loop

| ID | Backlog item | Acceptance result |
|---|---|---|
| P2-01 | Farm/plot/crop-cycle model | Supports multiple active/archived cycles without forced cloud account |
| P2-02 | Unified crop timeline | Observations, diagnoses, actions, tasks, treatments, and outcomes remain distinguishable |
| P2-03 | Today shell | One primary decision; graceful no-data/offline/stale states; preserved five-tab navigation |
| P2-04 | Tasks and crop stages | Useful defaults, local units/calendar, reminders, completion and skip reason |
| P2-05 | Actionable weather | Source, location, freshness, uncertainty, offline cache, and task-linked wording |
| P2-06 | Market pilot | Saved crops/markets, unit normalization, source/freshness, no trading-price promise |

### P3 — Evidence-triggered expansion

Expenses, inventory, schemes, shared households, extension dashboards, sensor/satellite integrations, partner referrals, and carefully separated commerce. Each requires a named owner, data-quality SLO, consent model, field evidence, and sunset plan.

## 17. Before vs. after comparison

| Dimension | Before: shipped prototype | After: selected target | Why it is stronger |
|---|---|---|---|
| Product promise | Photo notebook with debug sample diagnosis | Daily decision companion with a gated trust core | Aligns promise with safe, repeatable outcomes |
| Entry | Language → About → launcher | Language/audio → concise value → first useful action | Faster value with comprehension support |
| Home | Static destination rows | Today: one urgent decision, one task, one Doctor CTA | Creates return value without overload |
| Navigation | Independent push routes | Today / My Farm / Doctor / Market / More | Stable mental model for a broader product |
| Capture | One crop/photo, live quality gate | Stabilized crop/context and 1–3 guided photos with fast path | Better evidence and clearer recovery |
| Result | State card, raw label, no-op actions | Answer, why, do/avoid/watch, source, expert, follow-up | Converts classification into a safe decision |
| Records | Separate notebook and diagnosis history | Unified crop-cycle timeline | Matches how farmers remember a season |
| Offline | Local static flows | Local records + signed KB/model/audio + outbox + freshness | Makes offline capability explicit and complete |
| AI | Sample byte hash | Calibrated bounded model plus reviewed knowledge and human safety net | Avoids pretending generation is agronomy |
| Backend | In-memory identity/idempotency | Durable modular monolith with versioned sync and governance | Production operations without premature services |
| Accessibility | Semantics and sizing | Semantics + audio + stable states + font/device/field evidence | Supports real language, literacy, and context |
| Growth | Many desired modules | Three trust rings with evidence gates | Prevents shallow super-app sprawl |

## 18. Risk assessment

| Risk | Likelihood | Impact | Detection | Mitigation / stop rule |
|---|---|---|---|---|
| Incorrect diagnosis causes harmful treatment | High without validation | Severe | Calibration, field outcomes, complaint review | Narrow coverage, tri-state policy, reviewed actions, kill switch, expert path |
| Advice becomes stale or jurisdictionally wrong | Medium | Severe | Content expiry/source audits | Versioned scoped KB; block expired high-risk advice |
| Users interpret “confident” as certainty | High | High | Comprehension tests | Plain limitations, symptom comparison, monitoring and escalation |
| Broad roadmap dilutes trust core | High | High | Sprint/usage review | No new top-level module while P0/P1 gates fail |
| Today becomes empty or noisy | Medium | High | First-week retention and task tests | Graceful no-data value; one-primary-decision rule |
| Low-literacy users are excluded | High | High | Facilitated and unassisted field tasks | Audio/photo/plain language; voice never sole path |
| Weak network creates duplicate/lost actions | High | High | Chaos/offline tests | Durable outbox, idempotency, visible queued/sent states |
| Shared-device privacy leak | Medium | High | Threat modeling and field interviews | Optional profiles, notification redaction, local protection, explicit sharing |
| Photo/model/content storage exhausts device | High over time | High | Storage telemetry and low-space tests | Quota, thumbnails, cleanup, pack size display, reclaim controls |
| Data-provider prices/weather are stale | High | High | Freshness/SLO monitoring | Source/time always visible; stale degradation; no false alerts |
| Expert escalation has no capacity | Medium | High | Queue time/abandonment | Show hours/cost/ETA; capacity pilots; phone fallback; pause promotion |
| Commerce biases advice | Medium | Severe | Recommendation and conversion audits | Separate clinical/agronomic ranking from commerce; disclose conflicts |
| Model performs worse across devices/regions | High | Severe | Stratified evaluation and drift monitoring | Coverage registry, device gate, conservative fallback, staged rollout |
| Backend compromise exposes farm records/photos | Medium | Severe | Security testing/monitoring | Least privilege, encryption, consent, retention, audit, incident plan |
| Team treats automated tests as usability evidence | High | High | Research-gate review | Release requires observed farmer task evidence, not only test pass |

## 19. Redesign comparison and continuous iteration

### Whole-product alternatives

| Direction | Farmer value | Feasibility | Offline fit | Safety | Differentiation | Near-term score |
|---|---:|---:|---:|---:|---:|---:|
| Conservative: trustworthy notebook + handbook | 7 | 9 | 9 | 9 | 5 | 7.8 |
| Moderate: daily decision companion | 9 | 7 | 8 | 8 | 8 | **8.0** |
| Bold: voice-first AI agronomist | 8 | 4 | 5 | 3 | 9 | 5.8 |
| Future: connected autonomous farm platform | 9 | 2 | 4 | 4 | 9 | 5.6 |

**Winner:** the moderate direction, released through the conservative trust gate. It has the strongest balance of repeated farmer value, learnability, offline usefulness, safety, and feasible sequencing. The bold and future directions contain valuable interaction ideas but are not acceptable product foundations.

### Adversarial iteration 1 — Break the five-tab platform

**Attack:** Market and Today are empty without farm/profile/provider data; five tabs make the prototype feel larger but less useful.  
**Correction:** do not ship the shell merely as navigation. Start with Today / Doctor / My Farm / More, or retain the simple shell, until Market has a trusted saved-crop pilot. Remote configuration may hide an unready destination, but route stability and deep links must be preserved.  
**Residual risk:** changing navigation later can disrupt memory. Validate both four- and five-destination variants with repeated tasks before rollout.

### Adversarial iteration 2 — Break the Today dashboard

**Attack:** a card dashboard becomes generic, scroll-heavy, and falsely urgent.  
**Correction:** one primary decision per viewport; rank by user-owned context, consequence, actionability, and freshness. Group nonurgent items below. Explain “why shown” and allow dismiss/snooze.  
**Residual risk:** ranking can still be wrong. Begin rule-based and auditable; do not use opaque engagement ranking.

### Adversarial iteration 3 — Break the Crop Doctor

**Attack:** even a validated image classifier lacks crop stage, symptom history, weather, and differential diagnosis; farmers may act on a confident-looking card.  
**Correction:** collect only decision-relevant context, present compare/evidence, preserve uncertain/out-of-scope, link only reviewed actions, and require escalation for high-risk or unsupported cases.  
**Residual risk:** comprehension differs from model calibration. Use behavioral comprehension tests and follow-up outcomes, not confidence copy alone.

### Adversarial iteration 4 — Break the offline promise

**Attack:** expert, weather, market, sync, and updated guidance fail offline; “offline-first” becomes misleading.  
**Correction:** define capability-specific states. Core records and installed guidance work offline; network actions visibly queue; cached external data shows source/time; expired high-risk guidance degrades safely.  
**Residual risk:** users may not understand queue/freshness icons. Use explicit phrases and test them in each language.

### Adversarial iteration 5 — Break voice and localization

**Attack:** speech recognition fails with dialect, noise, mixed-language agriculture terms, and shared devices; TTS can mispronounce critical chemical guidance.  
**Correction:** human-record critical content, keep visible text/images, show speech transcript before saving, maintain regional glossaries, and never make voice the only route.  
**Residual risk:** content operations are expensive. Start with high-frequency/high-risk guidance and measure completion, not audio plays.

### Adversarial iteration 6 — Break the unified timeline

**Attack:** combining observations, diagnoses, tasks, treatments, and sync events makes records noisy and can blur farmer facts with AI claims.  
**Correction:** typed filters and unmistakable provenance: “You recorded,” “KrishiDoc suggested,” “Expert replied,” “Task completed.” Raw records remain accessible and generated summaries are labeled.  
**Residual risk:** a long season is still difficult to scan. Add crop-stage grouping and comparison mode only after timeline tests.

### Iteration stop condition

Conceptual improvements are now marginal compared with the unresolved evidence gap. Further desk redesign would create false precision. The next valid iteration must use working prototypes and representative farmers, not another speculative UI pass.

## 20. Final recommendations and quality gate

### Do now

1. Close P0 release integrity, startup, false-action, media, and durability blockers.
2. Build the offline handbook/content governance and a real expert safety net before marketing diagnosis.
3. Stabilize and validate capture on low-end hardware in real fields.
4. Pilot real diagnosis narrowly; treat model, content, result, escalation, monitoring, and kill switch as one release unit.
5. Model farm/plot/crop-cycle and unify field history before adding broad dashboards.
6. Introduce Today and Market only when each has fresh, actionable, trustworthy data.
7. Make regional-language, audio, TalkBack, outdoor, offline, and shared-device research release criteria.

### Do not do now

- Do not build a feature-complete super-app.
- Do not ship sample inference, raw classifier labels, or enabled no-op actions.
- Do not use generative AI for pesticide doses, chemical mixing, waiting periods, or unsupported diagnosis.
- Do not require account, location, notification, or upload permission before local value.
- Do not present stale weather, price, scheme, or advisory content without source and time.
- Do not add commerce to advice ranking without hard separation and conflict disclosure.

### Final gate status

| Gate | Status | Evidence needed to pass |
|---|---|---|
| No obvious usability problems | Fail | Core flows implemented and observed ≥90% task completion |
| Effortless navigation | Fail | Repeated-task field test of shipped shell |
| Visual consistency | Partial | Complete component/state catalog and device QA |
| WCAG/accessibility | Partial | Automated + TalkBack + 200% + low-literacy field evidence |
| Optimized workflows | Fail | Diagnosis, follow-up, farm timeline, weather, market and expert tasks |
| Farmer assumptions addressed | Fail | Representative longitudinal research and outcome evidence |
| Mobile-first | Partial | Low-end performance, outdoor, one-handed, storage and data-budget tests |
| Offline-first | Partial | Signed packs, outbox, freshness, conflicts, and complete offline journeys |
| Appropriate AI | Fail | Production model, calibration, governance, monitoring and safety chain |
| Growth architecture | Partial | Durable backend/client sync, observability, security, and operations |

**Final decision: not production-ready.** The correct next milestone is not “all scores at 9” through more design documentation. It is a narrow, instrumented trust-core pilot that closes every Critical blocker and demonstrates that farmers can understand, act on, recover from, and return to the experience safely. Only verified outcomes can raise the remaining scores.
