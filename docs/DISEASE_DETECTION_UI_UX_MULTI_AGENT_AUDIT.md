# KrishiDoc Crop-Disease Detection UI/UX Evaluation

**Multi-agent product review board · 24 August 2026**  
**Scope:** Android farmer-facing crop-photo triage, not human clinical software  
**Evidence base:** repository source, ADRs, model metadata, widget/integration tests, prior reference screens, and authoritative external standards  
**Quality-gate verdict:** **FAIL — not ready for an unsupervised farmer field pilot**

---

## 1. Executive summary

KrishiDoc is a visually strong experimental prototype with unusually thoughtful uncertainty architecture, light-theme contrast, multilingual layout engineering, on-device privacy, and a genuine photo-to-result flow. It is not yet a trustworthy production crop-decision-support product.

The review found two release-blocking contradictions:

1. The experimental model metadata explicitly forbids treatment advice, but every possible match can be passed directly into an automatically generated screen labelled **“Treatment / what to do now.”** This converts an uncertain visual similarity into an implied treatment pathway.
2. Saved scan rows announce as buttons to TalkBack but expose no semantic tap action. A blind user can hear the record but cannot open it.

The next most serious risks are the absence of a validated non-leaf/open-set detector, no real technician escalation, candidate-first history hierarchy, no recovery/correction controls for the only result state the release model can produce, and unresolved Nepali/Hindi agronomy review.

### Overall score

| Measure | Score | Interpretation |
|---|---:|---|
| Raw ten-agent mean | **5.9/10** | Acceptable prototype quality across the whole product |
| Safety-weighted product score | **5.6/10** | Clinical/agronomy UX and Trust & Safety counted twice |
| Visual-system score | **7.3/10** | Strong prototype, below professional benchmark |
| Applied ten-feature mean | **5.6/10** | Alerts and reporting pull down feature completeness |
| Final status | **Not satisfactory** | Critical safety and accessibility items remain open |

### Biggest strengths

- Release inference is real, on-device, and structurally restricted to possible matches.
- Experimental limits appear before capture and persist on results/history.
- Crop scope is checked before result filtering, avoiding manufactured crop-specific certainty.
- Diagnosis state is carried by text, icon, layout, and color—not color alone.
- The light palette has executable contrast tests and outdoor-readability intent.
- Camera coaching is live, high contrast, spoken, and blocks poor blur/exposure captures.
- Devanagari has its own line-height and tracking rules.
- Records persist useful internal provenance: crop, predictions, model version, threshold-set version, timestamp, and local photo path.

### Biggest weaknesses

- Candidate-linked treatment violates the declared experimental safety contract.
- Photo clarity is presented as readiness even though leaf/crop/coverage validity is not checked.
- The offline guide is presented as escalation, but no human is involved.
- Result and history hierarchy can anchor users on a disease name more strongly than the warnings do.
- Explainability is absent; the model cannot state which visual signs it used.
- Recovery, dispute, delete, search/filter, comparison, and share/report flows are incomplete.
- TalkBack history activation is broken and dynamic status announcements are incomplete.
- Language layout testing exists, but native-language agronomy approval does not.

### Top five improvements

1. **Break the candidate-to-treatment connection.** Replace it with safe observation guidance and genuine technician contact/share when available.
2. **Fix the TalkBack history action** and add a regression assertion for `SemanticsAction.tap`.
3. **Strengthen refusal behavior.** Add validated leaf/wrong-crop/open-set checks or temporarily stop naming diseases when subject validity is unknown.
4. **Redesign result and history around uncertainty first.** Put the state before candidates, place the result before the photo, and add rescan/change-crop/dispute/delete recovery.
5. **Close field-readiness gates.** Nepal-representative validation, native Nepali/Hindi agronomy review, and a real escalation path are prerequisites for an unsupervised pilot.

---

## 2. Scope correction and methodology

The supplied brief describes human clinical software. Copying patient records, medical severity, medical emergencies, and clinician workflow into KrishiDoc would be incorrect. The board adapted the brief as follows:

| Clinical brief | KrishiDoc equivalent |
|---|---|
| Patient | Farm, field, crop, affected plant |
| Symptoms and medical history | Plant part, symptom duration, spread, crop stage, recent weather, irrigation, and prior action |
| Disease-risk prediction | Experimental crop-problem visual similarities |
| Clinician | Agriculture technician, extension worker, agronomist, or plant clinic |
| Clinical severity | Agronomic urgency, spread risk, and potential crop-loss impact |
| Diagnosis | Possible match; never confirmation with the current model |
| Patient report | Auditable scan record or technician-ready case summary |

Three independent review tracks covered agronomy/trust, visual foundations/design system, and accessibility/IA/responsiveness. The primary board inspected model and UI contracts, researched authoritative references, then ran a debate in which safety and comprehension outranked visual preference.

This is a code- and test-grounded expert review, not a usability study. The connected phone was locked during the final visual pass, so unlocked on-device optical QA, TalkBack traversal, Accessibility Scanner testing, and farmer comprehension testing remain required.

### Scoring method

- Each applicable feature receives 0–10 from each specialist lens.
- `—` means the feature is not materially expressed in that lens and is excluded from that lens average.
- The raw overall score is the mean of the ten lens scores.
- The final product score counts Agent 01 and Agent 07 twice because the brief explicitly prioritizes safety and trust over polish.
- Missing features are scored as missing; attractive execution of a smaller subset does not earn credit for functionality that does not exist.

---

## 3. Multi-agent UX scorecard

| Agent | Lens | Score | Board verdict |
|---|---|---:|---|
| 01 | Agronomy / safe workflow UX | **4.3** | Real end-to-end flow, but insufficient context, no true escalation, and unsafe treatment linkage |
| 02 | Visual design | **7.4** | Calm, coherent, and polished; card-heavy with weak result hierarchy |
| 03 | Color system | **6.8** | Excellent audited light palette; semantic collisions and no dark theme |
| 04 | Typography | **7.1** | Thoughtful multilingual metrics; unbundled fonts and a Devanagari-breaking override |
| 05 | Accessibility | **6.0** | Strong contrast/touch/live coaching; critical TalkBack history failure |
| 06 | Information architecture | **5.3** | Complete loop exists; guidance, correction, history, and audit boundaries are weak |
| 07 | Trust & Safety | **4.0** | Strong guardrails undermined by candidate-linked treatment and missing open-set validity |
| 08 | Responsive design | **5.8** | Good mobile scrolling/selective 200% tests; capture, populated history, and tablet behavior unverified |
| 09 | Design system | **7.0** | Solid foundations and sealed result states; tokens are not yet theme- or misuse-safe |
| 10 | Benchmark maturity | **4.8** | Good foundations, but far behind mature plant-clinic, collaboration, reporting, and evidence workflows |

---

## 4. Ten-feature evaluation

### 4.1 Per-feature, per-agent matrix

| Adapted feature | A01 | A02 | A03 | A04 | A05 | A06 | A07 | A08 | A09 | A10 | Feature score |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1. Farmer/crop dashboard | 6 | 8 | 8 | 8 | 7 | 6 | 6 | 6 | 8 | 6 | **6.9** |
| 2. Crop and observation input | 6 | 8 | 8 | 7 | 7 | 6 | 5 | 6 | 7 | 6 | **6.6** |
| 3. Disease photo matching | 4 | 8 | 8 | 7 | 8 | 7 | 4 | 7 | 8 | 7 | **6.8** |
| 4. AI result card | 5 | 7 | 7 | 7 | 6 | 6 | 5 | 6 | 7 | 6 | **6.2** |
| 5. Explainable AI | 3 | 7 | 6 | 7 | 6 | 5 | 2 | 6 | 7 | 4 | **5.3** |
| 6. Certainty and agronomic urgency | 5 | 7 | 6 | 7 | 6 | 6 | 4 | 6 | 7 | 5 | **5.9** |
| 7. Recommendation panel | 3 | 7 | 6 | 7 | 6 | 5 | 3 | 6 | 6 | 4 | **5.3** |
| 8. Assessment history | 5 | 8 | 7 | 7 | 3 | 6 | 5 | 5 | 7 | 5 | **5.8** |
| 9. Alerts and follow-up | 2 | — | — | — | — | 2 | 2 | — | — | 2 | **2.0** |
| 10. Reporting and auditability | 4 | 7 | 5 | 7 | 5 | 4 | 4 | 4 | 6 | 3 | **4.9** |
| **Agent score** | **4.3** | **7.4** | **6.8** | **7.1** | **6.0** | **5.3** | **4.0** | **5.8** | **7.0** | **4.8** | |

### 4.2 Feature findings

#### Feature 01 — Farmer/crop dashboard: 6.9

**Works:** scan, weather, crop guide, farm tasks, market, and records are reachable through a familiar bottom navigation. The scan hero has strong prominence.

**Missing:** no field identity, recent scan summary in Crop Help, active monitoring, spread status, or follow-up reminder. Avoid inventing a risk summary until an evidence-backed rule exists.

#### Feature 02 — Crop and observation input: 6.6

**Works:** selected crop is explicit and can be changed before capture. Preparation, privacy, and model scope are visible.

**Missing:** crop variety/stage, plant part, duration, affected proportion, field distribution, recent rain/irrigation, prior treatment, district/elevation, and gallery import. Collect only fields that alter refusal, escalation, or reviewed guidance; do not create form burden for decoration.

#### Feature 03 — Disease photo matching: 6.8

**Works:** real TFLite inference runs on-device; the global winner is checked before crop filtering; accepted release output is always uncertain; records are written before navigation.

**Risk:** the model is trained on controlled images, is not Nepal-field validated, and has no non-plant class. Blur/exposure readiness is not leaf validity. A 0.20 softmax floor is not an open-set detector.

#### Feature 04 — AI result card: 6.2

**Works:** permanent experimental notice, selected crop, stored photo, explicit states, safe caveat, and a stored/offline marker.

**Missing:** result-first hierarchy, honest subject-validity state, photo-quality facts, timestamp/model details, current-state recovery, and a boundary between possible match and general care.

#### Feature 05 — Explainable AI: 5.3

The implementation discloses model limitations but cannot explain why it selected a candidate. Alternatives are names only. Do not fabricate explainability with unvalidated heatmaps or symptom bars. The honest near-term design should say:

> “This model compares image patterns but cannot reliably explain which visible signs led to these possible matches.”

Useful, truthful evidence can include the selected crop, passed photo checks, full uncropped image, covered conditions, model/data limitations, and similar reference symptoms from an independently curated knowledge source—not from model attention pretending to be causality.

#### Feature 06 — Certainty and agronomic urgency: 5.9

The app communicates model uncertainty, not crop severity or urgency. That distinction is correct and should become explicit. Never derive “low/moderate/high/critical crop risk” from classifier confidence. Agronomic urgency may only come from a reviewed rule set, official advisory, validated disease progression inputs, or a human.

#### Feature 07 — Recommendation panel: 5.3

The offline guide is structured, multilingual, local, pesticide-product-free, and source-aware. Its unsafe part is the causal handoff from top candidate to a treatment-labelled answer. General crop care may remain, but it must state that it is not based on the possible matches.

#### Feature 08 — Assessment history: 5.8

**Works:** durable newest-first records, date, state, crop-aware labels, and permanent experimental/sample notices.

**Fails:** TalkBack activation is broken. Visual hierarchy promotes the candidate above uncertainty. There is no search, filter, compare, dispute/replacement trail, delete, or visible retention control; only 50 records are queried without a visible pagination state.

#### Feature 09 — Alerts and follow-up: 2.0

There is no scan-linked monitoring reminder, disease-spread alert, official advisory subscription, or technician follow-up. Keep weather advice and disease alerts separate. An alert should disclose source, geography, crop, published time, expiry, and whether it is official, predictive, or user-recorded.

#### Feature 10 — Reporting and auditability: 4.9

Internal records are stronger than the UI: timestamp, model version, threshold-set version, predictions, crop, and photo path are stored. Users cannot view technical details, export/share a case, see a correction trail, or identify a content-pack review date. Preserve internal auditability now; add export when a real technician/cooperative workflow and privacy model exist.

---

## 5. Critical findings, ranked

| Rank | Finding | Severity | User impact | Safety/access risk | Difficulty |
|---:|---|---|---|---|---|
| 1 | Experimental candidate is automatically linked to “Treatment / what to do now” despite `treatmentAdviceAllowed: false` | **Critical** | High | **Critical** | Small–Medium |
| 2 | History rows announce as TalkBack buttons but have no semantic tap action | **Critical** | High for screen-reader users | **Critical access failure** | Small |
| 3 | No validated leaf/wrong-crop/non-plant/open-set check; “Ready” means only blur/exposure passed | **High** | High | High | Large; interim wording/suppression is Medium |
| 4 | “Human escalation” is actually a deterministic offline guide | **High** | High | High | Medium–Large / partnership-dependent |
| 5 | History visually leads with a disease candidate and subordinates “not sure” | **High** | High | High anchoring risk | Small |
| 6 | Current release result state lacks rescan, change-crop, dispute, and delete controls | **High** | Medium–High | High recovery gap | Medium |
| 7 | Nepali/Hindi safety and agronomy review gates remain open | **High** | Broad | High | Medium, requires reviewers |
| 8 | Large photo can push the actual result below the first viewport | **High** | Medium–High | Medium | Small |
| 9 | Camera/result/assistant errors lack complete spoken status and recovery actions | **High** | High for assistive technology | High | Small–Medium |
| 10 | Scan-intro line-height override undoes Devanagari-safe metrics | **High** | Medium | Medium | Small |
| 11 | “Healthy” can appear as a possible match even though the model cannot clear crop health | **High** | High | High delay risk | Small–Medium |
| 12 | Historical certainty replay checks model version but not stored threshold-set version | Medium now / High later | Medium | Future overstatement | Small |
| 13 | Stored photo is cropped with `BoxFit.cover`; missing photos silently vanish | Medium | Medium | Medium evidence-verification gap | Small |
| 14 | Model/content provenance is stored but not visible; correction is not audited | Medium | Medium | Medium | Medium |
| 15 | Light-only theme and raw camera colors prevent safe dark-mode rollout | Medium | Low–Medium | Low today | Medium |

### Evidence for the two blockers

**Candidate-to-treatment contradiction**

- `app/assets/models/plant_disease_experimental.metadata.json:95-100` — treatment advice forbidden; human confirmation required.
- `docs/adr/ADR-0056-experimental-crop-help-boundaries.md:31` — model-linked treatment explicitly rejected.
- `app/lib/src/diagnosis/result_screen.dart:193-213` — first candidate sent to assistant.
- `app/lib/src/assistant/assistant_route_screen.dart:72-79` — automatic `candidate treatment prevention control` query.
- `app/lib/l10n/app_en.arb:349,371` — treatment-labelled heading and CTA.
- `app/test/product_flow_test.dart:157-199` — current unsafe handoff is regression-tested as desired behavior.

**TalkBack dead history action**

- `app/lib/src/history_screen.dart:240-255,299-300` — outer labelled button has no semantic action; real `onTap` is excluded.
- `app/lib/src/welcome/welcome_language_screen.dart:161-168` — the repository already documents and fixes this exact pattern elsewhere.
- Required regression: assert that each history semantic node has `SemanticsAction.tap`.

---

## 6. Individual agent reports

### Agent 01 — Agronomy / safe workflow UX: 4.3

- Strong: clear crop selection, private photo flow, and durable scan result.
- Weak: one photo and crop name are too little agronomic context for treatment or severity.
- Decision: keep the product as triage/observation support until field validation and reviewed guidance exist.

### Agent 02 — Visual design: 7.4

- Strong: coherent warm surfaces, useful hierarchy, large controls, and polished capture.
- Weak: too many equal cards on the intro and result content begins too low.
- Decision: “professional field intelligence,” not a green healthcare imitation.

### Agent 03 — Color system: 6.8

- Strong: audited light contrast and redundant state cues.
- Weak: green means brand, action, ready, success, and classifier confidence; dark theme is absent.
- Decision: blue for AI information, amber for uncertainty, slate for unsupported, green only for action/completion, red only for genuine error or validated urgency.

### Agent 04 — Typography: 7.1

- Strong: separate Devanagari metrics, zero Devanagari tracking, and generous body sizes.
- Weak: no bundled font and a local `height: 1.25` override breaks the language-aware token.
- Decision: bundle Noto Sans/Noto Sans Devanagari and forbid screen-level line-height overrides.

### Agent 05 — Accessibility: 6.0

- Strong: 48dp target floor, high contrast, reduced-motion helper, live camera coaching, and color-independent result states.
- Weak: dead history actions, missing dynamic announcements, incomplete focus/recovery, and inaccessible independent framing.
- Decision: accessibility quality gate must include semantic actions and manual traversal, not label presence alone.

### Agent 06 — Information architecture: 5.3

- Strong: the route from Crop Help to scan, camera, result, guide, and saved history is coherent.
- Weak: candidate and treatment are coupled; records are buried; corrections create another flow without correcting the first.
- Decision: make uncertainty and safe next step the spine of the flow.

### Agent 07 — Trust & Safety: 4.0

- Strong: possible-match-only enforcement, persistent warnings, local processing, crop-scope refusal, and pesticide-free guide.
- Weak: the treatment handoff negates the boundary; open-set validity and genuine escalation do not exist.
- Decision: no unsupervised pilot until P0 is closed.

### Agent 08 — Responsive design: 5.8

- Strong: mobile scroll patterns and selected 320px/200% tests.
- Weak: full capture, populated history, result with photo/notices, landscape, 600/840dp tablet, and 2× multilingual route tests are absent.
- Decision: expanded-width and large-text behavior precede dark mode.

### Agent 09 — Design system: 7.0

- Strong: explicit tokens, spacing/radius/icon scales, central theme, and sealed result presentations.
- Weak: arbitrary foreground/background component parameters allow contrast misuse; classifier `confident` naming permits success semantics.
- Decision: typed semantic variants must make unsafe combinations unrepresentable.

### Agent 10 — Visual references and benchmark maturity: 4.8

- Strong: the app already reflects Material navigation, concise warning surfaces, and local/offline decision support.
- Weak: it lacks the plant-clinic escalation, collaboration, review trail, case sharing, and validated field intelligence of mature systems.
- Decision: borrow patterns, not claims or visual skins.

---

## 7. Multi-agent debate and board decisions

### Agree

All agents agreed to:

- block candidate-linked treatment;
- place the experimental notice first and the actual result before the photo;
- make uncertainty dominant in result and history;
- remove radio-button icons from noninteractive candidates;
- avoid green success styling for AI output or “healthy” possible matches;
- avoid fabricated heatmaps, symptom factors, or fake expert contact;
- add recovery and accessible error states;
- bundle reliable multilingual fonts and validate translations with agronomy reviewers.

### Disagree

1. **Dark mode priority**  
   Visual design recommended a full light/dark semantic foundation. Accessibility and Trust argued that sunlight readability, TalkBack, large text, expanded widths, and safety boundaries come first.

   **Board ruling:** define dark token roles now, implement dark mode in P2 after P0/P1 safety and accessibility work.

2. **Compact versus comprehensive scan intro**  
   Visual design wanted fewer competing containers. Trust warned against burying model limits.

   **Board ruling:** simplify the layout, not the evidence boundary. Before-camera content must still state possible-match-only behavior, supported crops/leaf scope, lack of Nepal validation, local photo storage, and the need for confirmation before consequential action.

3. **Audit export now or later**  
   Trust favored immediate exportable summaries; Visual design warned against premature workflow complexity.

   **Board ruling:** expose technical details and preserve correction events now. Add export/share when a real technician/cooperative destination and privacy policy exist.

4. **Number of result actions**  
   Safety identified rescan, change crop, dispute, save, delete, and human escalation. Visual design warned against five equal CTAs.

   **Board ruling:** one primary safe action, one secondary recovery action, and remaining controls under “More” or progressive disclosure.

### Risk

The dangerous pattern is cumulative: a disease-name heading, green state color, candidate-first history, and treatment CTA can collectively feel like confirmation even when every screen contains a disclaimer. The redesign must remove those reinforcing cues, not merely add more warning copy.

### Final board recommendation

Use this result sequence:

1. Persistent compact banner: **Experimental possible match—not a diagnosis or health check**
2. Dominant state: **Possible visual similarities / Not sure / Not covered**
3. Candidate names as subordinate, noninteractive evidence
4. One safe next action: observable checks or real technician contact/share
5. Full uncropped expandable photo
6. General crop-care boundary, limitations, model/source details, correction, and delete under progressive disclosure

---

## 8. Proposed information architecture

### Current

```text
Bottom navigation
├── Work
│   ├── Scan hero / Scan FAB
│   ├── Weather
│   ├── Crop guide
│   └── Farm tasks
├── Doctor
│   ├── Scan leaf
│   └── Offline crop guide
├── Market
└── Profile
    └── Disease scans

Scan flow
Doctor/Work → Scan intro → Crop → Camera → Result → Candidate-linked crop guide
```

### Proposed mobile IA

Preserve the familiar four-item bottom navigation from the reference design, but rename **Doctor** to **Crop help** until a real person participates.

```text
Bottom navigation
├── Work
├── Crop help
│   ├── Scan a leaf
│   ├── Recent scans
│   ├── General crop guide
│   └── Technician / plant-clinic contact (only when real)
├── Market
└── Profile
    ├── All records
    ├── Language and crop defaults
    ├── Data and retention
    └── About, sources and model limits

Persistent primary action
└── Scan FAB → available from every primary tab without replacing navigation
```

### Proposed disease-flow hierarchy

```text
Crop help
→ Choose crop + minimal field context
→ Capture or import
→ Review the full photo
→ Experimental possible-match state
→ Candidate similarities + limitations
→ Safe observations / real escalation
→ Save, dispute, rescan or delete
→ Follow-up in scan history
```

### Progressive disclosure

Always visible:

- experimental state;
- selected crop;
- possible-match/not-sure/not-covered state;
- safe primary next action;
- no-confirmation/no-health-clearance boundary.

Expandable:

- full photo;
- other candidates;
- model and threshold-set version;
- content source and review date;
- privacy/retention detail;
- dispute/delete/share controls.

### History structure

- Group by date or growing season.
- Lead with state: “Not identified” or “Experimental similarities.”
- Show crop, secondary candidate, timestamp, and optional uncropped thumbnail.
- Filters: crop, date, state, accepted/disputed; disease-name search only as a candidate filter, never as confirmed history.
- Mark missing photos explicitly.
- Store corrections as linked immutable events instead of silently replacing the original.

---

## 9. Final visual direction

### Character

**Professional field intelligence:** calm warm-neutral canvas, crisp high-contrast content, forest-green actions, blue AI information, amber uncertainty, slate coverage gaps, and red reserved for genuine failure or validated urgency.

It should feel agricultural and operational—not clinical, ornamental, gamified, or alarmist.

### Result hierarchy

```text
EXPERIMENTAL POSSIBLE MATCH

Possible visual similarities
Late blight

This is not a diagnosis or a crop-health clearance.

[Check observable signs]  [Scan a different leaf]

Photo evidence ▾
Other similarities ▾
Model and data limits ▾
```

The disease candidate uses a dedicated 26sp result role, but remains visually subordinate to the uncertainty state. Do not show an uncalibrated percentage. Do not equate confidence, severity, or urgency.

### Before → after

| Surface | Before | After |
|---|---|---|
| Scan intro | Four similarly weighted containers | One purpose block, compact crop selector, three-step photo guide, separate privacy and limitation notes |
| Capture | “Ready” can imply diagnostic validity | “Light and focus are ready—make sure one affected leaf fills the frame” plus review/import path |
| Result | Notice, crop pill, 240px photo, then answer | Notice, state/result, safe next action, then expandable uncropped photo |
| Candidate list | Radio-looking noninteractive rows | Neutral bullets under “Unvalidated visual similarities” |
| Guidance | Candidate flows into treatment-labelled answer | General safe observations with a visible non-causal boundary |
| History | Disease candidate in bold, uncertainty secondary | Uncertainty/state first, candidate secondary, disputed/missing-photo states visible |
| Accessibility | Labelled history buttons without actions | Native/explicit semantic tap action, tested and manually traversed |
| System | Static light tokens and raw camera colors | Typed semantic roles; dark theme after safety/access matrix is green |

---

## 10. Semantic color system

### Principles

1. Color supports meaning; text, icon, and structure carry it.
2. AI certainty, crop severity, and agronomic urgency are separate systems.
3. Green means action, saved/completed state, or camera readiness—not classifier correctness.
4. Blue identifies AI information/possible matches.
5. Amber identifies uncertainty or a consequential limitation.
6. Slate identifies unsupported coverage.
7. Red identifies system failure or a validated urgent state, never model confidence.
8. Dark values are a target specification, not evidence that dark mode exists today.

### Foundation and state tokens

| Semantic role | Light HEX / RGB | Dark HEX / RGB | Meaning and usage | Contrast consideration |
|---|---|---|---|---|
| Background / canvas | `#F7F5EC` · 247,245,236 | `#10130F` · 16,19,15 | Page background | Pair with text-primary |
| Surface | `#FFFEFA` · 255,254,250 | `#1A1F19` · 26,31,25 | Cards and sheets | Base content surface |
| Surface elevated | `#FFFFFF` · 255,255,255 | `#242B23` · 36,43,35 | Dialogs/floating controls | Must remain distinct without shadow |
| Surface sunken | `#E8ECE2` · 232,236,226 | `#141914` · 20,25,20 | Disabled/recessed areas | Never use as only disabled cue |
| Text primary | `#12140F` · 18,20,15 | `#F3F5EF` · 243,245,239 | Headings and critical body | 16.97:1 / 17.04:1 on canvas |
| Text secondary | `#44483F` · 68,72,63 | `#C3C9BE` · 195,201,190 | Supporting copy | 8.57:1 / 11.07:1 |
| Text disabled | `#5A6353` · 90,99,83 | `#949D90` · 148,157,144 | Disabled labels | 5.24:1 / 6.35:1 on sunken |
| Border subtle | `#D6DCCF` · 214,220,207 | `#3D473D` · 61,71,61 | Decorative grouping only | Not a sole control boundary |
| Border strong | `#7C8474` · 124,132,116 | `#869184` · 134,145,132 | Inputs, safety-state edges | 3.85:1 / 5.10:1 on surface |
| Primary action | `#1B5E20` · 27,94,32 | `#8DD890` · 141,216,144 | Main action and brand | On-primary 7.87:1 / 8.75:1 |
| On primary | `#FFFFFF` · 255,255,255 | `#0B2E10` · 11,46,16 | Text/icon on primary | Use as a paired token only |
| Primary container | `#E1F0DE` · 225,240,222 | `#173C1D` · 23,60,29 | Selected crop, quiet brand emphasis | Pair with strong green ink/check |
| AI information | `#315A8A` · 49,90,138 | `#A9C7FF` · 169,199,255 | Possible match and explanation | 7.03:1 / 9.81:1 on surface |
| Success | `#216E39` · 33,110,57 | `#6FD08C` · 111,208,140 | Saved, ready, completed only | Never use for disease candidate/healthy |
| Warning | `#8A5300` · 138,83,0 | `#FFB95C` · 255,185,92 | Model uncertainty/limitations | 6.27:1 / 9.85:1 on surface |
| Error | `#A61B1B` · 166,27,27 | `#FFB4AB` · 255,180,171 | Camera/storage/processing failure | Pair with error icon and action |
| Possible-match band | `#E4EEFC` · 228,238,252 | `#1A2B42` · 26,43,66 | AI result container | Not a success surface |
| Possible-match ink | `#1C416B` · 28,65,107 | `#D9E6FF` · 217,230,255 | AI result text/icon | 8.89:1 / 11.38:1 on band |
| Uncertain band | `#FAECD8` · 250,236,216 | `#3D2A12` · 61,42,18 | Multiple similarities/limitations | Use with `?`/warning glyph and words |
| Uncertain ink | `#6B3F00` · 107,63,0 | `#FFE0B2` · 255,224,178 | Uncertain content | 7.73:1 / 10.76:1 on band |
| Unsupported band | `#E6E9EE` · 230,233,238 | `#242B35` · 36,43,53 | Outside coverage | Pair with search-off icon and cause |
| Unsupported ink | `#2B3441` · 43,52,65 | `#E0E7F0` · 224,231,240 | Coverage-gap content | 10.33:1 / 11.45:1 on band |
| Focus ring | `#005FCC` · 0,95,204 | `#B8D7FF` · 184,215,255 | Two-pixel keyboard/switch focus | ≥3:1 against adjacent state |

### Dormant agronomic-urgency roles

These roles must not be activated from model softmax or candidate order. They require reviewed agronomy rules, official advisories, or human assessment.

| Role | Light / dark | Text + icon | Intended trigger |
|---|---|---|---|
| Routine | `#315A8A` / `#A9C7FF` | “Routine” + info icon | Reviewed low-consequence follow-up |
| Monitor | `#8A5300` / `#FFB95C` | “Monitor” + eye/clock | Reviewed signs requiring observation |
| Prompt action | `#9B3E00` / `#FFB68F` | “Act promptly” + clock-alert | Time-sensitive reviewed rule |
| Critical | `#7A1020` / `#FFB4C0` | “Urgent” + alert triangle | Official outbreak/human-confirmed urgent state |

All four text colors clear 6.2:1 on their intended light/dark surfaces. Shape, wording, and placement—not hue alone—differentiate them.

---

## 11. Typography system

### Font stack

- English and numerals: **Noto Sans**
- Nepali/Hindi: **Noto Sans Devanagari**
- Bundled weights: 400, 500, 600, 700
- Metrics/prices/dates: enable tabular figures where the selected font build supports them
- Fallback: platform sans only after the bundled family

### Scale

| Role | Latin size / line | Devanagari size / line | Weight | Latin tracking | Usage |
|---|---:|---:|---:|---:|---|
| Display | 36 / 44 | 36 / 52 | 700 | -0.4 | Short onboarding hero only |
| H1 | 30 / 38 | 30 / 44 | 700 | -0.2 | Page title |
| H2 | 24 / 32 | 24 / 36 | 700 | -0.1 | Major section |
| H3 | 20 / 28 | 20 / 30 | 600 | 0 | Card/result section |
| H4 | 18 / 26 | 18 / 28 | 600 | 0 | Subsection |
| Body Large | 17 / 26 | 17 / 28 | 400 | 0.1 | Primary instructions |
| Body | 16 / 24 | 16 / 26 | 400 | 0.1 | Default reading |
| Body Small | 14 / 21 | 14 / 23 | 400 | 0.2 | Supporting text |
| Caption | 12 / 18 | 12 / 20 | 500 | 0.2 | Source/date/model metadata |
| Label | 15 / 20 | 15 / 23 | 600 | 0.1 | Buttons, chips, inputs |
| Data / Metric | 28 / 34 | 28 / 42 | 700 | -0.2 | Prices, measurements, counts |
| Crop Result | 26 / 34 | 26 / 40 | 700 | 0 | Candidate disease/problem name |

### Typography rules

- Devanagari letter spacing is always `0`.
- Do not override line height in a screen widget; use locale-aware token roles.
- Remove `height: 1.25` from the multiline scan-intro heading.
- Avoid all-caps translated text.
- Keep tablet line length around 40–65 characters.
- Preserve full system text scaling through 200%; change layout before clipping text.
- Do not truncate safety, error, uncertainty, or action labels.
- Candidate name may be large, but the uncertainty/state label remains higher in semantic order.

---

## 12. Accessibility audit

The target is WCAG 2.2 AA principles adapted to native mobile plus Android platform guidance. WCAG requires programmatically exposed names/roles/states and status messages; Android recommends at least 48×48dp targets. See [WCAG 2.2](https://www.w3.org/TR/WCAG22/) and [Android accessibility guidance](https://developer.android.com/design/ui/mobile/guides/foundations/accessibility).

| Area | Status | Evidence / required action |
|---|---|---|
| Light-theme text contrast | **Pass** | Executable contrast tests cover functional pairs; body contrast intentionally exceeds AA |
| Non-text/control contrast | Pass–Partial | Strong border token exists; arbitrary component color pairs and focus states remain risky |
| Color-independent status | **Pass** | Diagnosis states combine icon, words, rail, band, and layout |
| Touch targets | **Pass** | Button/icon/chip theme uses a 48dp floor; capture shutter is larger |
| Screen-reader history activation | **Fail** | Labelled button has no semantic tap action |
| Dynamic status messages | Partial | Camera coaching/progress use live regions; capture error, assistant answer/failure, and result error do not consistently |
| Independent capture | Partial–Fail | Spoken light/blur guidance exists; no accessible leaf/framing validation or gallery/import alternative |
| Text scaling | Partial | Useful 200% component tests exist; full intro/capture/populated history/result route matrix does not |
| Devanagari rendering | Partial | Separate metrics exist; one local override regresses them and fonts vary by OEM |
| Reduced motion | Strong | Custom duration helper respects platform reduced-animation preference |
| Keyboard/switch focus | Partial | Framework behavior exists; explicit tokenized focus ring and traversal QA are missing |
| Error recovery | Fail–Partial | Camera settings/retry, result retry/safe exit, and specific failure reasons are missing |
| Language content validity | **Fail for field release** | Layout is tested; native-language agronomy/safety sign-off remains open |

### Required accessibility verification matrix

- Devices/widths: 320×568, 360×800, 412×915, 600dp, 840dp.
- Orientations: portrait and landscape.
- Locales: English, Nepali, Hindi.
- Text scale: 1.0, 1.3, 2.0.
- States: intro, crop sheet, camera ready/not-ready/error, processing, all result states with/without photo, populated/empty history, assistant pending/answer/error.
- Manual: TalkBack swipe traversal, double-tap activation, Switch Access, Voice Access, Accessibility Scanner, reduced motion, high-contrast text, outdoor sunlight.
- Automated: semantics actions, live-region presence, target-size assertions, contrast pairs, overflow/layout matrix.

---

## 13. Component and design-system recommendations

### Foundation changes

- Replace globally static color access with `ThemeExtension<KdSemanticColors>` or an equivalent typed semantic theme.
- Rename classifier roles from `confident` to `possibleMatch` at the presentation layer.
- Separate primitive palette values from roles.
- Replace arbitrary color arguments in `KdStatusPill`/`KdIconWell` with typed tones.
- Add breakpoints: compact `<600dp`, medium `600–839dp`, expanded `≥840dp`.
- Center reading surfaces at approximately 680dp; use result/evidence supporting panes at expanded widths.
- Bundle fonts and make typography locale-aware through theme roles only.

### Component-state contract

`✓` required and defined, `—` not semantically applicable. Hover still matters for mouse/ChromeOS/tablet even though the primary target is touch.

| Component | Default | Hover | Focus | Active | Disabled | Loading | Error | Success/completed |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Primary/secondary button | ✓ | ✓ | ✓ | ✓ | ✓ | ✓, retain label | — | Optional confirmation, never AI result |
| Icon button | ✓ | ✓ | ✓ | ✓ | ✓ | — | — | — |
| Text input / textarea | ✓ | ✓ | ✓ | ✓ | ✓ | Optional suffix | ✓ inline + spoken | ✓ only for saved/validated input |
| Crop select/chip | ✓ | ✓ | ✓ | ✓ selected + check | ✓ | — | ✓ unsupported crop text | ✓ selection confirmed by check/text |
| Capture shutter | ✓ not-ready | — | ✓ | ✓ pressed+haptic | ✓ with reason | ✓ processing label | ✓ spoken + recover | ✓ photo captured, not diagnosis |
| AI result card | ✓ possible match | — | — | — | — | separate skeleton/status | ✓ processing failure | **No success state** |
| Experimental notice | ✓ persistent | — | link focus only | — | — | — | — | — |
| History row | ✓ | ✓ | ✓ | ✓ tap | — | skeleton row | missing-photo/disputed states | saved state text only |
| Photo evidence | ✓ full/contained | zoom affordance | ✓ | ✓ expand | — | placeholder | explicit unavailable state | — |
| Alert/notification | ✓ info/warning | action only | ✓ action | ✓ action | — | — | ✓ with remedy | ✓ completion only |
| Modal/bottom sheet | ✓ titled | — | ✓ trapped/restored | ✓ actions | action-level | ✓ where needed | ✓ inline | ✓ confirmation |
| Empty state | ✓ explanation + action | action | ✓ | action | — | — | — | — |
| Loading state | ✓ descriptive stage | — | — | cancel if meaningful | — | ✓ | timeout/failure route | completion announcement |

### Specific component decisions

- **Possible-match card:** blue, investigation icon, explicit state heading, candidates as plain list.
- **Uncertain card:** amber, “Not sure,” no radio affordances, one safe primary action.
- **Unsupported card:** slate, explicit cause; show retake only when a retake can help.
- **Healthy candidate:** neutral copy—“No covered disease matched strongly”—never green clearance.
- **Camera unavailable:** distinguish denied permission, unavailable hardware, initialization failure, and processing failure; provide **Open settings**, **Try again**, or safe exit as appropriate.
- **Missing photo:** show “Photo no longer available”; do not silently remove evidence context.
- **Correction:** record `userRejected`, link any replacement scan, and show the disputed state in history.

---

## 14. Reference and benchmark analysis

The references below support principles, not visual copying.

| Reference pattern | Why it works | Application to KrishiDoc | Proposed implementation |
|---|---|---|---|
| [Material 3 interaction states](https://m3.material.io/foundations/interaction/states/overview) | Uses consistent enabled/hover/focus/pressed/disabled cues and more than one indicator | Current controls have strong touch behavior but incomplete focus/state tokens | Central state layers and explicit focus role across all controls |
| [Carbon notifications](https://carbondesignsystem.com/components/notification/usage/) | Matches disruptiveness to context; persistent callouts suit pre-existing important information | Experimental limits exist before user action and must not disappear | Persistent compact callout with icon, title, body; one optional action |
| [NHS warning callout](https://service-manual.nhs.uk/design-system/components/warning-callout) | Concise, specific, self-contained warnings with textual headings remain understandable without color | Long repeated caveats can become a warning wall | One high-salience experimental heading, plain-language limits, no competing warnings |
| [GOV.UK error-message guidance](https://design-system.service.gov.uk/components/error-message/) | States what happened and how to fix it; keeps the user’s data | Current generic camera/result failures do not support recovery | Cause-specific error copy next to the failed task plus explicit remedy |
| [WCAG 2.2](https://www.w3.org/TR/WCAG22/) and [Android accessibility](https://developer.android.com/guide/topics/ui/accessibility/views/apps-views) | Programmatic roles/actions/status and 48dp native targets support assistive use | KrishiDoc has strong targets but misses one critical semantic action | Test actions, not labels; live announce dynamic states; manual TalkBack QA |
| [Apple accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility) | Supports large text and warns against color-only meaning | Reinforces the current redundant state strategy | Maintain text+icon+shape; support 200% layout; audit light and future dark modes |
| [CABI Plantwise](https://www.cabi.org/projects/plantwise/) | Combines plant clinics, trained plant doctors, diagnostic resources, and practical management advice | KrishiDoc currently substitutes a guide for a person | Build a real extension/plant-clinic escalation and technician-ready case handoff |
| [PlantwisePlus digital tools](https://www.cabi.org/plantwiseplus/resources/) | Country-specific, reviewable, offline factsheets support field work | Mirrors KrishiDoc’s offline/local direction but with stronger governance | Versioned Nepal packs, review dates, recommendation-level sources, offline availability |
| [NARC troubleshooting API](https://soil.narc.gov.np/crop/tsmapidoc/) | Provides Nepal crop/disease content and explicitly includes pesticide waiting-period cautions | Useful authoritative local source, but chemical detail raises review obligations | Cite or deep-link reviewed content; do not ingest products/doses without policy and agronomy review |
| [Plantix](https://plantix.net/en/) | Familiar photo check, crop library, community/expert route | Demonstrates farmer expectation for rapid scan plus human help | Borrow the clear task separation; do not copy “diagnosis” certainty claims |
| [Agrio](https://pro.agrio.app/main) | Combines photo checks, scouting, collaboration, weather alerts, and reports | Shows a path from isolated scan to field workflow | Add follow-up observations, field progression, and real collaboration after safety validation |

Reference policy: current product marketing claims from crop apps are not validation evidence for KrishiDoc. CABI/NARC patterns inform governance and escalation; WCAG/Android/Material/Carbon/NHS/GOV.UK inform interaction quality.

---

## 15. Prioritized improvement roadmap

### P0 — Before any farmer field pilot

1. **Remove candidate-linked treatment.** Do not inject a candidate into the guide. Rename “Treatment” to “Safe checks you can do now” and state that general guidance is not based on the possible matches. Reverse the product-flow regression test.
2. **Fix TalkBack history activation.** Put `onTap` on the exposed semantic node or preserve native action semantics; assert `SemanticsAction.tap`.
3. **Prevent false subject validity.** Interim: change readiness copy and suppress disease names when leaf/crop validity is unknown. Production: validated leaf/wrong-crop/OOD refusal.
4. **Do not present the guide as a human.** Add a real contact/share destination or label the limitation honestly.
5. **Block “healthy” clearance.** Use neutral coverage wording and a non-green state.
6. **Keep distribution internal/experimental** until Nepal-field, agronomy, and native-language review gates close.

### P1 — Safe supervised pilot

1. Redesign result/history around uncertainty first; move result above photo.
2. Add one-tap rescan, change crop, dispute/replacement, record/photo delete, and cause-specific recovery.
3. Add minimal observation context and a photo-review/import path.
4. Fix Devanagari line-height override; bundle Noto fonts.
5. Add dynamic status semantics and manual TalkBack/Switch/Voice Access verification.
6. Put recent scans in Crop Help and add state/date/crop filters.
7. Complete compact/medium/expanded, landscape, three-locale, 200% layout matrix.
8. Expose capture time, model/threshold versions, local-processing state, data limits, and content review date under “Assessment details.”

### P2 — Auditable production path

1. Collect and govern a Nepal-representative field dataset with non-leaf, wrong-crop, unseen-disease, mixed-symptom, nutrient, pest, and healthy examples.
2. Publish per-crop validation, calibration, subgroup/device analysis, rejection performance, and a monitoring/rollback plan.
3. Create versioned agronomist-reviewed knowledge packs with recommendation-level sources and review dates.
4. Build real agriculture-technician, extension-office, cooperative, or plant-clinic routing.
5. Add linked correction events, technician notes, and privacy-governed share/export.
6. Implement tablet supporting-pane layouts.
7. Move static colors into semantic theme roles and implement/audit dark mode.

### P3 — Only after evidence exists

- Evidence-backed symptom comparison or explainability.
- Time-series crop/field monitoring and before/after comparisons.
- Official or validated geographic disease advisories.
- Agronomic urgency classifications.
- Team/cooperative scouting and review queues.
- Disease-specific actions, only after independent confirmation and content governance.

### Explicit non-priorities

- Decorative AI heatmaps without validated meaning.
- Raw softmax percentages presented as probability of disease.
- “Critical” risk colors derived from model confidence.
- A fake expert/chat persona for an offline keyword guide.
- Dark mode before P0/P1 safety/access failures.
- Desktop clinical dashboards or patient-record concepts.

---

## 16. Quality gate

| Gate | Status | Reason |
|---|---|---|
| Professional field visual language | Partial pass | Strong visual prototype; result hierarchy and semantic collisions remain |
| Clear agronomic information hierarchy | Fail | Candidate/treatment and candidate/uncertainty hierarchy are unsafe |
| Strong typography | Partial pass | Good tokens; unbundled fonts and line-height regression |
| Consistent semantic color system | Partial pass | Strong light palette; green collision and static theme roles |
| Accessible contrast | Pass for light | Automated tests are strong; future dark theme untested |
| Color-independent status | Pass | Text, icon, color, and layout used together |
| Clear AI uncertainty | Partial pass | Copy is strong; history and treatment handoff undermine it |
| No misleading diagnostic claims | **Fail** | Candidate-linked treatment creates implied confirmation |
| Responsive layouts | Partial pass | Mobile subset tested; capture/full routes/tablets incomplete |
| Consistent components | Partial pass | Strong core; typed safety variants and full state contracts missing |
| Clear error states | Fail–Partial | Generic errors, incomplete spoken status and recovery |
| Clear loading states | Partial pass | Capture progress exists; result/assistant status behavior incomplete |
| Clear empty states | Pass for tested history | Other missing-photo/no-result states incomplete |
| Clear risk communication | Not ready | No validated agronomic urgency system; correctly must not be fabricated |
| High-quality references | Pass in this report | Standards and crop-service patterns are explicitly translated |
| Reusable design tokens | Partial pass | Good static tokens; semantic theming and misuse prevention incomplete |
| Consistent spacing and grid | Pass on compact mobile | Expanded-width contract absent |
| Professional data visualization | Not applicable today | Do not add risk charts without validated data |
| Low cognitive load | Partial pass | Camera is strong; intro and result warning/card stack need simplification |
| Strong trust and transparency | **Fail** | Safety contract contradiction, no real escalation, language/field gates open |
| TalkBack operability | **Fail** | Saved scans cannot be semantically activated |

**Final quality-gate decision: do not mark the disease-detection experience complete or field-ready.** The product can remain an internal/supervised experimental prototype while P0 is corrected.

---

## 17. Evidence index

Primary repository evidence reviewed:

- `docs/adr/ADR-0056-experimental-crop-help-boundaries.md`
- `app/assets/models/plant_disease_experimental.metadata.json`
- `app/lib/src/diagnosis/disease_scan_intro_screen.dart`
- `app/lib/src/capture/capture_screen.dart`
- `app/lib/src/diagnosis/result_screen.dart`
- `app/lib/src/diagnosis/diagnosis_presenter.dart`
- `app/lib/src/diagnosis/certainty.dart`
- `app/lib/src/diagnosis/sample_notice.dart`
- `app/lib/src/assistant/assistant_route_screen.dart`
- `app/lib/src/assistant/crop_assistant_screen.dart`
- `app/lib/src/assistant/offline_crop_assistant.dart`
- `app/lib/src/history_screen.dart`
- `packages/capture/lib/src/quality_gate.dart`
- `packages/inference/lib/src/model_pack.dart`
- `packages/inference/lib/src/prediction_resolver.dart`
- `packages/inference/lib/src/experimental_plant_pack.dart`
- `packages/design_system/lib/src/diagnosis_presentation.dart`
- `packages/design_system/lib/src/diagnosis_result_view.dart`
- `packages/design_system/lib/src/tokens.dart`
- `packages/design_system/lib/src/typography.dart`
- `packages/design_system/lib/src/theme.dart`
- `packages/design_system/test/contrast_test.dart`
- `packages/design_system/test/diagnosis_result_view_test.dart`
- `app/test/capture_test.dart`
- `app/test/history_test.dart`
- `app/test/product_flow_test.dart`
- `app/test/crop_assistant_screen_test.dart`
- `app/integration_test/typography_layout_test.dart`

### Final design-director statement

KrishiDoc should not become a generic “AI disease diagnosis” app. Its strongest credible future is a Nepal-focused crop-observation and decision-support tool that combines conservative on-device visual matching, explicit refusal, versioned local knowledge, longitudinal farm records, and a real extension/technician pathway. The current UI has a solid visual and engineering base. The next iteration should spend that credibility on fixing causal meaning, accessibility, and evidence—not on adding more features or more polish.
