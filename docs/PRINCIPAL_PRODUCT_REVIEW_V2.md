# KrishiDoc Principal Product Review — Version 2

**Second-pass date:** 4 August 2026  
**Repository baseline:** branch `v2`, commit `80eeeff`  
**Decision horizon:** public launch through a 3–5 year platform horizon  
**Status:** first-principles rework; Version 1 is preserved as a superseded review, not silently edited

## Method: what changed from Version 1

Version 1 over-weighted implementation discipline and framed expansion mainly as risk. Version 2 scores the shipped product by farmer outcomes and evaluates expansion as both an opportunity and a coordination problem.

Five Version 1 biases were explicitly removed:

1. **Safety bias became strategy bias.** Safety gates were correct, but they were allowed to imply that Crop Doctor should determine the entire product sequence.
2. **Feature breadth was treated mostly as clutter.** This missed the fact that diagnosis is episodic while planning, weather, records, expenses, and market decisions create retention.
3. **The architecture was evaluated as a larger app, not as a platform kernel.** A farming operating system can be broad in its data/capability model while remaining simple in each farmer’s interface.
4. **Revenue and distribution were underdeveloped.** A trustworthy product still needs a sustainable B2C, cooperative, extension, or partner model.
5. **The score rewarded code quality too generously.** Clean ports, semantics, and tests matter, but they do not compensate for an absent agronomic outcome.

### Evidence base

- Direct inspection of the current Flutter routes, widgets, domain/data/inference/design packages, FastAPI service, Android release configuration, localization catalogs, tests, ADRs, and specifications.
- Nepal’s official [Living Standards Survey IV](https://data.nsonepal.gov.np/dataset/b6c3c19b-4b15-44bf-8653-1571e76dad14/resource/e2d52301-1c25-498b-8732-4326c62a2372/download/nlss-iv.pdf), whose 2022/23 comparison reports 60.3% agricultural households, average agricultural land of 0.4 hectares, and 88.5% of holdings operating under 0.5 hectares.
- Nepal’s [National Sample Census of Agriculture 2021/22 data](https://data.nsonepal.gov.np/dataset/national-sample-census-of-agriculture-2021-2022-national-level), which exposes holdings, land, crops, irrigation, loans, subsidies, climate knowledge, training, and other dimensions that a serious farm record may eventually need to represent.
- FAO’s [Digital Villages Initiative in Nepal](https://www.fao.org/digital-villages-initiative/asia-pacific/country-briefs/en), which connects smallholders with extension, community centers, crop records, knowledge, market prices, payments, and finance. This is evidence for an ecosystem path, not proof that every module belongs in one launch UI.
- Current first-party product documentation and sites for agriculture and cross-industry benchmarks, linked where used.

### Verification limit

The local `uv` executable is unavailable and the configured Flutter executable hangs even on `flutter --version`; therefore no new build, automated test, profile, screenshot, or device run is claimed. Visual/performance conclusions are implementation-informed hypotheses until validated on representative Android hardware and in fields.

## 1. Executive Summary — Version 2

### Revised verdict

KrishiDoc should not become only an AI Crop Doctor, and it should not expose a generic agriculture super-app. It should become a **modular smallholder farming operating system**: one local-first farm record, one daily decision queue, and a set of installable/activatable capabilities spanning crop health, work, weather, records, markets, and human services.

The strategic recommendation is **Option D: phased hybrid**.

- **Acquisition wedge:** photo/voice/text crop help and an offline handbook.
- **Retention engine:** Today, crop-stage work, observations, weather decisions, expenses, and follow-ups.
- **System of record:** household → farm → plot → crop cycle → event ledger.
- **Trust layer:** reviewed knowledge, source/freshness, bounded AI, expert escalation, and auditable provenance.
- **Platform layer:** capability registry, local-first sync, institutional roles, APIs, and partner modules.
- **Interface principle:** the architecture may be broad; the farmer sees only the next relevant decision and activated capabilities.

### Revised product score

**Outcome-weighted current score: 4.1/10. Production gate: fail.**

This score is intentionally lower than Version 1’s 5.7. Version 2 weights solved farm work, repeated value, production truth, and business viability more heavily than code quality.

| Outcome dimension | Weight | Current score | Evidence |
|---|---:|---:|---|
| Farmer problem solved end-to-end | 18% | 3.0 | Photos and notes solve a narrow memory problem; crop advice is not real or actionable |
| Trust and agronomic safety | 14% | 4.0 | Honest sample/tri-state design, but no validated model, KB, source, or working expert path |
| Workflow breadth/coherence | 11% | 2.5 | Notebook/capture only; farm, season, weather, task, money, market, and service loops absent |
| Daily relevance and retention | 9% | 2.0 | Home is a launcher; no recurring queue or seasonal progress |
| Usability and learnability | 10% | 6.0 | Simple routes and large controls; camera/recovery/context gaps remain |
| Accessibility and literacy reach | 8% | 6.5 | Semantics and localization are strong foundations; audio/field proof absent |
| Offline resilience | 8% | 6.0 | Local records work; content, models, sync, freshness, and queue semantics do not |
| Technical production readiness | 8% | 3.5 | Good boundaries; sample inference, in-memory server, no client API, startup/signing blockers |
| Performance/device fitness | 4% | 5.5 | Background work is considered; no current low-end profile and storage lifecycle |
| Localization/regional relevance | 4% | 7.0 | English/Nepali/Hindi ARB parity; agricultural terminology/audio/content missing |
| Commercial/distribution viability | 6% | 2.0 | No defined payer, channel, service operations, or measurable recurring benefit |

### Decisions that change from Version 1

| Version 1 default | Version 2 decision |
|---|---|
| Trust core first, broader platform later | Platform data kernel starts in MVP; multiple small coherent loops prove recurrence alongside trust work |
| Crop Doctor as central destination | “Ask” is a multimodal help surface; crop diagnosis is one tool alongside handbook and human support |
| Five fixed modules including Market | Stable shell is Today / Farm / Ask / Records / Services; modules inside are activated by context and region |
| Unified crop timeline mainly for diagnosis follow-up | Append-only farm event ledger becomes the core domain and powers tasks, expenses, inventory, advice, audits, and multiple views |
| Expansion mostly gated after P0/P1 | Capability contracts are designed now; rollout remains gated, but teams can develop independent vertical slices safely |
| Primarily product/technical roadmap | Stage gates include distribution, service capacity, unit economics, content operations, and institutional adoption |

## 2. Revised Product Strategy

### Strategic option comparison

Scores use 10 = strongest. For complexity, cost, development effort, and risk, 10 means easier/lower. Weights emphasize farmer value without ignoring sustainability.

| Criterion | Weight | A: Focused AI Crop Doctor | B: Modular agriculture platform | C: Full digital farming OS | D: Phased hybrid |
|---|---:|---:|---:|---:|---:|
| Farmer value | 18% | 7 | 8 | 9 | 9 |
| Daily engagement | 10% | 3 | 8 | 9 | 8 |
| Long-term retention | 10% | 4 | 8 | 9 | 9 |
| Technical complexity | 8% | 6 | 4 | 2 | 6 |
| Cost | 8% | 6 | 4 | 2 | 6 |
| Scalability | 10% | 7 | 8 | 9 | 9 |
| Market differentiation | 10% | 5 | 6 | 8 | 8 |
| Revenue potential | 10% | 5 | 8 | 9 | 8 |
| Development effort | 6% | 6 | 4 | 2 | 6 |
| Risk | 10% | 4 | 5 | 3 | 7 |
| **Weighted result** | **100%** | **5.4** | **6.6** | **6.9** | **7.8** |

### Option A — Focused AI Crop Doctor

**Case for it:** clear proposition, easy acquisition creative, bounded IA, useful at a stressful moment, and a feasible pilot by crop/condition. [Plantix](https://plantix.net/en/) demonstrates the legibility of crop-problem entry as a product category.

**Case against it:** disease events are episodic; image-only evidence is insufficient for many conditions; liability and agronomy operations are expensive; diagnosis alone produces weak seasonal records and limited daily retention; differentiation erodes as vision models commoditize.

**Best use:** acquisition wedge and specialist capability, not the company’s full identity.

### Option B — Modular agriculture platform

**Case for it:** combines frequent and high-value decisions, supports different regions/crops, creates multiple revenue surfaces, and can integrate services. [OneSoil](https://onesoil.ai/en/platform) shows a coherent field/scouting platform, while FAO’s Nepal program shows that a multi-stakeholder digital ecosystem is locally plausible.

**Case against it:** without one canonical farm record and experience policy, “modular” becomes a portal of shallow cards, incompatible data, duplicated permissions, and vendor priorities.

**Best use:** product delivery model built on a platform kernel.

### Option C — Full digital farming operating system

**Case for it:** strongest long-term data compounding, institutional value, automation, interoperability, and revenue potential. [John Deere Operations Center](https://operationscenter.deere.com/) and [Cropin](https://www.cropin.com/intelligent-agriculture-cloud/) demonstrate the strategic power of connected operations and intelligence.

**Case against it:** their assumptions do not transfer directly to fragmented smallholdings, shared devices, manual records, weak connectivity, or a small team. Building everything centrally before proving behavior creates extreme capital and adoption risk.

**Best use:** 3–5 year architecture and ecosystem vision, not a first release scope.

### Option D — Phased hybrid: selected

Build the operating-system kernel now, deliver modular vertical slices, and reveal complexity progressively.

```text
Acquisition         Daily habit                 System of record             Ecosystem
Ask/Doctor    →     Today + tasks       →       Farm event ledger     →      Experts/markets/partners
Handbook            Weather/follow-up           Cycles + expenses             APIs/institutional roles
```

This differs from sequencing a narrow product and “adding platform later.” Identity, farm hierarchy, event provenance, capability boundaries, content versioning, offline semantics, and sync IDs are foundational from MVP. Only the visible modules and service operations are phased.

### Positioning

> **KrishiDoc helps smallholders decide, record, and act across the season—even when the network is weak.**

Avoid “AI-powered” as the lead promise. AI is a method. The farmer-facing promise is fewer missed tasks, clearer crop problems, safer next actions, better seasonal memory, and easier access to people/services.

### Engagement model

- **Daily/weekly:** today’s work, weather window, reminder, observation, expense.
- **Event-triggered:** symptom, severe weather, market movement, expert reply, scheme deadline.
- **Seasonal:** crop setup, input planning, harvest, revenue/expense summary, next-season learning.
- **No artificial streaks:** farm work is weather- and season-dependent. Continuity celebrates useful records and completed plans without punishing rest, crop gaps, or emergencies.

### Business model hypothesis

| Layer | Payer | Offer | Guardrail |
|---|---|---|---|
| Free farmer core | Sponsored/public/free | Local records, handbook, basic tasks, bounded help | Never lock the farmer’s own records or safety content |
| Farmer Plus | Farmer/household | Advanced seasonal analytics, storage/sync, family collaboration | Low-data mode and export remain available |
| Cooperative/extension | Cooperative, NGO, government | Enrollment, consented caseload, campaigns, aggregate operational reporting | No silent surveillance; farmer controls sharing scope |
| Expert service | Farmer/institution | Triage and scheduled agronomist cases | Cost, response time, and credentials shown before request |
| Partner/API | Weather, market, insurers, suppliers, platforms | Governed capability/API integration | Source/freshness and conflict-of-interest disclosure |
| Transactions, later | Buyer/seller/finance partner | Optional market or financial workflow | Advice ranking must be independent of payment/conversion |

## 3. Revised Feature Evaluation

Scores are present-value scores, not implementation-quality scores. `E` essential, `X` expand, `M` merge, `R` remove from product surface, `L` later/conditional.

| Feature | Score | Decision | Current assessment/problems | Proposed improvement | Priority | Expected farmer impact |
|---|---:|---|---|---|---|---|
| First-run language | 7.5 | E/X | Fast endonym choice; no audio, dialect, or “change later” assurance | Tap-to-hear language sample; explicit reversibility; remember per household/profile | P1 | Higher comprehension and lower accidental-language abandonment |
| About screen | 4.5 | M | Honest but delays value and explains absence | Merge into a 20-second value/consent primer; move enduring facts to More | P2 | Faster first useful action |
| Home launcher | 3.5 | R/replace | Static route list; no work context or recurrence | Replace with Today decision queue powered by farm events and capabilities | P1 | Daily relevance and clear next action |
| Language menu | 7.0 | E | Useful; app-wide switch can surprise shared-device users | Preview before switch; persist by local profile; keep one-tap access in More | P2 | Safer shared-device use |
| Camera session | 6.0 | E/X | Real camera abstraction; failure states collapsed | Typed permission/device recovery, gallery, torch, focus, multi-photo support | P0–P1 | More successful captures in real conditions |
| Quality coaching | 5.5 | E/X | Blur/light guidance is valuable but can chatter/trap | Hysteresis, message hold, cause on shutter tap, override, model-aware framing | P0 | Fewer failed attempts and less frustration |
| Crop picker | 3.0 | M | Three-item sheet; silent default can bias result | Pull from active crop cycle/recent crops; “not listed”; capability coverage | P1 | Less data entry and fewer wrong-crop assessments |
| Observation capture | 6.5 | E/X | Honest photo record works offline | Attach plot/cycle/stage; voice note; quick tags; task/follow-up creation | P1 | Creates useful seasonal memory beyond diagnosis |
| Notebook list | 5.5 | M | Simple photo list; weak at scale and divorced from decisions | Become filtered Records view over canonical farm event ledger | P1 | Faster recall and one trusted history |
| Observation detail | 5.0 | X | Thin note editor; save failure/media deletion issues | Event detail with provenance, structured context, attachments, explicit sync/storage state | P0–P1 | Reliable, meaningful record and correction |
| Sample inference | 1.0 | R | Hash-based output is a harness, not farmer capability | Move to component/model lab; CI proves unreachable in distributable builds | P0 | Prevents accidental misinformation |
| Tri-state result model | 7.5 | E/X | Sound confident/uncertain/out-of-scope foundation | Add reason codes, coverage, evidence quality, policy version, escalation severity | P1 | Honest uncertainty and safer actions |
| Diagnosis result UI | 2.5 | R/replace | Raw label, no advice, no-op correction/expert controls | Decision brief: finding, evidence, actions, avoid, monitor, ask, source, follow-up | P0–P1 | Converts a classification into a safe workflow |
| Diagnosis history | 3.5 | M | Separate list duplicates notebook concept | Render assessments as typed events inside Records/crop timeline | P1 | One mental model; clearer provenance |
| Photo store | 4.5 | E/fix | Private local persistence; orphan lifecycle and quota absent | Staged asset lifecycle, derivatives, reference ownership, cleanup, quota/export | P0 | Fewer low-storage failures and privacy leaks |
| Local Drift database | 6.0 | E/X | Background SQLite and migrations are good; schema is too thin | User DB + replaceable content DB + sync metadata; event-based domain schema | P1 | Durable offline foundation for all modules |
| Local settings | 6.5 | E/X | Language/crop preference only | Capability, profile, download, privacy, units, calendar, audio, and sync settings | P2 | Regional fit and controllable data cost |
| Design system | 6.5 | E/X | Strong tokens/contrast/semantics; incomplete states and identity | Domain components, dense/large modes, charts, audio, provenance, offline/freshness | P1 | Consistency across rapidly expanding modules |
| Localization catalogs | 7.0 | E/X | Key parity in three languages; UI strings only | Agricultural glossary, reviewed content, audio manifest, units/calendar, fallback policy | P1 | Safer regional-language actions |
| Device identity API | 4.0 | E/redesign | Good seams and rotation concepts; no proof, persistence, or client | Passkey-like device proof, Keystore, household/profile identities, recovery/transfer | P0–P1 | Optional sync without password burden |
| Request ID/error/idempotency | 6.5 | E/X | Useful platform foundation; only in memory | Durable idempotency, mobile error taxonomy, traceable outbox acknowledgements | P0 | Reliable weak-network writes |
| Debug preview | 5.0 | R from app | Valuable UI harness mixed with application routes | Dedicated component/model lab and golden/a11y scenarios outside release navigation | P2 | Faster QA with zero leakage risk |

### Features absent but essential to the selected strategy

| Feature | Why now | First useful slice |
|---|---|---|
| Farm/plot/crop cycle | Canonical context for every recommendation and record | One farm, optional plot name, active crop, planting date/stage estimate |
| Farm event ledger | Prevents separate silos for notes, diagnoses, work, money, and advice | Append observation/task/assessment/expense with provenance and correction links |
| Today queue | Converts records and external data into next actions | Due tasks, follow-ups, stale data, one weather decision, expert replies |
| Offline handbook | Standalone value and reviewed grounding for Ask/results | Searchable crop/problem/actions pack with photos and audio |
| Tasks/reminders | Frequent retention loop tied to crop stages | Add/complete/snooze/skip; optional notification; local calendar |
| Weather decision cards | Raw forecast is not enough | Cached source/freshness plus one action window for active crop/task |
| Expert case | Safety and service layer for uncertainty | Consented case bundle, queued offline, cost/ETA/channel, reply in record |
| Expense record | High-value low-complexity seasonal memory | Amount, category, crop cycle, voice entry, local unit/currency |

## 4. Revised UX Audit

### Target mental model

The farmer should not learn “modules.” The durable model is:

1. **My farm and active crop** — context.
2. **What needs attention** — Today.
3. **Ask for help** — photo, voice, text, or human.
4. **What happened** — Records.
5. **Available services** — weather, market, schemes, experts, partners.

### Revised navigation

| Destination | Job | Default content | Empty-state value |
|---|---|---|---|
| Today | Decide what to do next | Ranked tasks, weather windows, follow-ups, replies, alerts | Start crop, read seasonal guide, record observation |
| Farm | Maintain operating context | Farms, plots, active crop cycles, stages, summary | Create first crop with three questions |
| Ask | Resolve a question/problem | Photo/voice/text intake, handbook search, recent cases | Browse common crop problems offline |
| Records | Recall and prove what happened | Event ledger with views for timeline, money, health, work | Explain what recording unlocks; one-tap observation |
| Services | Reach external value | Expert, market, schemes, downloads, partner capabilities | Region-aware availability and waitlist; no dead tiles |

Capabilities can be disabled by region/account, but destination semantics must not change unpredictably. Weather belongs in Today/Farm; market lives in Services until repeated use earns a shortcut. This avoids Version 1’s assumption that every important domain needs a tab.

### Core journeys and step budgets

| Journey | Target path | Budget | Offline behavior |
|---|---|---:|---|
| First useful value | Language/audio → choose “record crop” or “ask” → result | ≤60 seconds | Fully local except external expert request |
| Start crop | Farm → crop → planting timing/stage → save | ≤45 seconds | Local; richer fields progressive |
| Record observation | Contextual add → photo/voice/text → confirm | ≤20 seconds | Saves locally and appears immediately |
| Ask about crop | Ask → active crop prefilled → photo/voice/context → decision brief | ≤2 min fast; ≤4 min guided | On-device/installed KB; remote/human queues visibly |
| Check today | Open app → top decision → complete/snooze | ≤10 seconds | Cached/local items first; stale external data labeled |
| Record expense | Records/add → voice or amount/category → save | ≤15 seconds | Fully local |
| Contact expert | Result/Ask → share preview → cost/ETA → submit | ≤2 minutes | Case bundle queues; phone/SMS fallback if configured |
| End season | Farm/cycle → harvest/outcome/cost summary → archive | ≤3 minutes | Local summary, sync later |

### Progressive disclosure

- On first use, request no account and no full farm survey.
- Ask only for information that changes the next output; explain why.
- Advanced plot geometry, variety, irrigation, input lots, household roles, and integrations appear when a relevant capability needs them.
- A “Complete farm profile” percentage is prohibited; it creates busywork. Show benefit-specific prompts instead: “Add planting date to receive stage reminders.”

### Low-literacy and voice model

- Every core action has text + recognizable icon + optional spoken label.
- Voice intake records locally, shows/translates the recognized transcript, and asks for confirmation before creating a record or case.
- Human-recorded audio is used for high-risk guidance; device TTS is explicitly labeled for other content.
- A persistent audio control reads the decision summary and each action step, not the entire screen chrome.
- The app supports mixed-language agricultural terms through a reviewed glossary and correction logging.
- Voice failure always falls back to large choice chips, photo prompts, or expert contact; it never blocks the workflow.

### Notification philosophy

Today is the source of truth. Push notifications are a user-controlled projection of high-value events: time-sensitive weather/task windows, expert replies, and chosen reminders. No engagement spam, generic tips, streak loss, or silent re-enablement.

## 5. Revised UI Audit

Every routed screen was redesigned from three alternatives. “Strongest” refers to the target strategy, not necessarily the smallest patch.

### Screen alternatives

| Current screen | Weakness that matters | Approach 1 | Approach 2 | Approach 3 | Selected and why |
|---|---|---|---|---|---|
| First-run language | Text-only choice assumes reading confidence | Endonym tiles + speaker preview | Device-language default + confirmation | Voice-led language conversation | **1**, with device suggestion: fastest, reversible, accessible, offline; voice remains aid not gate |
| About | Explains constraints before value | Short value primer | Swipe tutorial | Choose first job: Start crop / Ask / Browse guide | **3** with one-line trust primer: intent routes directly to value and avoids a generic tour |
| Home | Static launcher cannot rank work or scale | Module grid | Today decision queue | Conversational assistant home | **2**: most scannable outdoors, auditable, and useful without forcing conversation |
| Capture | One-photo gate lacks context and recovery | Stabilized existing camera | Adaptive guided 1–3 photo capture | Auto-detect/auto-shutter AR overlay | **2**: improves evidence while retaining fast path; 3 is device/model dependent |
| Notebook | Flat gallery loses season structure | Searchable gallery | Crop-stage timeline | Farm ledger with Timeline / Work / Money / Health views | **3**: one record supports multiple jobs without duplicate data |
| Observation detail | Note editor cannot continue work | Rich editable note | Structured event sheet | Follow-up workspace with comparison and actions | **2** initially, growing into 3 when follow-up exists; keeps facts/provenance clear |
| Diagnosis history | Separate history duplicates notebook | Better filtered diagnosis list | Health tab within Records | Global activity feed | **2**: maintains a health lens while using the same event ledger |
| Diagnosis result | Classification card has no complete action | Improved state card | Structured decision brief | Open-ended AI chat | **2**: fastest safe action and evidence hierarchy; chat is a subordinate clarification control |
| Debug preview | Developer state can leak into product navigation | Keep hidden route | In-app developer menu | Separate component/model lab | **3**: supports QA without release reachability |

### Strongest screen specifications

#### First-use intent screen

After language selection:

1. One sentence: “Plan work, record your season, and get crop help—even offline.”
2. Three 56dp actions with icon, text, and audio: **Start my crop**, **Ask about a problem**, **Browse crop guide**.
3. Small trust line: no account required; records stay on this phone until sharing/sync is chosen.

#### Today

Top-to-bottom hierarchy:

1. Active farm/crop switcher with stage and offline/sync indicator.
2. One **Now** decision with consequence, source/reason, and primary action.
3. **Next** compact work list with complete/snooze.
4. Awaiting follow-up/expert response.
5. Weather and market summary only when fresh and relevant.
6. Contextual “Record” action; no global ornamental FAB.

If nothing is due, Today says so and offers a season-appropriate guide or observation. It never manufactures urgency.

#### Ask

- Entry modes: **Take photos**, **Speak**, **Type**, **Search guide**, **Ask expert**.
- Active crop/plot prefilled and editable.
- “Why we ask” for stage, spread, duration, or treatment context.
- Capture progress shows required/optional evidence and permits “I cannot take this photo.”
- Ask remembers the unfinished draft locally.

#### Decision brief

1. **Finding:** “This may be…” / “We cannot identify this safely.”
2. **Why:** visible symptoms and missing evidence; never raw model probability alone.
3. **Do now:** at most three ordered safe actions.
4. **Avoid:** the most consequential common mistake.
5. **Watch:** time-bound follow-up and worsening signs.
6. **Ask:** expert/correction with real cost, hours, and sharing preview.
7. **Evidence:** reviewed source, region, version, freshness, coverage/limitations.
8. **Save follow-up:** task added to Today and event ledger.

#### Farm and Records

- Farm overview uses crop-cycle cards, not a generic analytics dashboard.
- Record views reuse the same event data: Timeline, Work, Health, Money.
- Every item declares actor/provenance: You recorded, KrishiDoc suggested, Expert replied, Imported from partner.
- Corrections append a superseding event; they do not silently rewrite history.

### Cross-industry interaction benchmark

| Product | First-party pattern | Adaptation for KrishiDoc | Boundary |
|---|---|---|---|
| [Linear Inbox](https://linear.app/docs/inbox) | Work needing attention, snooze, reminders, focused actions | Today as a finite decision inbox with complete/snooze and reason | Do not import keyboard density or team-software language |
| [Linear Cycles](https://linear.app/docs/use-cycles) | Repeating time boxes reduce planning busywork | Crop-stage templates create recurring work without manual scheduling | Crop seasons are biological/weather-driven, not fixed sprints |
| [Notion databases](https://www.notion.com/help/intro-to-databases) | One object set supports multiple views/properties | One farm event ledger powers timeline, health, work, and money views | Farmers do not design schemas or manage database complexity |
| [Stripe Dashboard](https://docs.stripe.com/dashboard/basics?locale=en-GB) | Stable resource navigation, search, operational state, analytics | Consistent farm/cycle resources, global record search, explicit sync/service health | Avoid desktop dashboard density on mobile |
| [Google Maps offline](https://support.google.com/maps/answer/6291838?hl=en-GB) | Download lifecycle, storage choice, updates, expiry, degraded capability | Manage crop/region knowledge, model, audio, and optional map packs with size/freshness | Explain exactly what stops working offline; never imply full parity |
| [Duolingo learning path](https://blog.duolingo.com/duolingo-101-how-to-learn-a-language-on-duolingo/) | Clear next step and progressive difficulty | Stage-based next action and small achievable records | No points, hearts, leaderboards, or punishment for missed farm work |
| [Duolingo streak experiments](https://blog.duolingo.com/improving-the-streak/) | Reduce the minimum action to build continuity and test behavior | Make one useful observation/task completion enough for seasonal continuity | No manipulative daily streak; optimize farming outcome, not app opens |
| [Headspace app](https://www.headspace.com/app) | Personalized recommendations, progress, reminders, content + AI + experts | Calm Today recommendations and escalation across self-help, AI, and humans | Do not anthropomorphize AI authority or hide source/limitations |

### Visual language

- **Character:** calm field utility, not futuristic AI and not government-portal bureaucracy.
- **Color:** neutral warm surfaces; deep green as navigation/primary action; blue for information; amber for caution; red only for urgent/destructive. Diagnosis state always has words and icon.
- **Typography:** bundled Noto Sans + reviewed Noto Sans Devanagari subset, locale-specific line-height, no joined-script letter spacing.
- **Density:** default field mode with 52–56dp controls; optional compact record-list density, never on high-risk actions.
- **Data visualization:** direct labels, locally familiar units, accessible summary before chart, and data-source/freshness. Favor stage progress, cash in/out, rainfall windows, and comparison over decorative gauges.
- **Illustration:** instructional capture/symptom diagrams and crop-stage visuals; no generic stock-farmer hero art in task flows.
- **Motion:** 120–220ms state continuity, reduced-motion support, capture freeze, queue/sync transitions, no celebratory disease animations.

## 6. Revised Architecture Review

### Architecture objective

Support 3–5 years of modular growth without forcing a microservice rewrite or a super-app UI. The central abstraction is a provenance-rich farm event, not a diagnosis row.

### Client structure

Retain Flutter, Riverpod, GoRouter, Drift, and pure Dart domain code, but reorganize around vertical capabilities:

```text
app/lib/
  bootstrap/               startup recovery, environment, feature manifest
  shell/                   navigation, session, locale, connectivity, Today ranking
  features/
    farms/                 farm, plot, crop cycle, stage
    records/               event ledger, media, views, export
    ask/                   intake, diagnosis, handbook, expert cases
    work/                  tasks, reminders, templates
    weather/               snapshots and action rules
    money/                 expenses, income, inventory slice
    services/              market, schemes, integrations

packages/
  domain/                  bounded context models, commands, policies
  local_store/             user DB, sync metadata, migrations
  content_runtime/         KB packs, FTS, audio, provenance
  ai_runtime/              model adapters, policy, structured assessment
  sync_engine/             outbox/inbox, conflict resolution, attachments
  design_system/           primitives and domain components
  observability/           privacy-safe events, performance, failures
```

Do not create a package for every screen. Package boundaries are justified by independent testing, replaceable runtime, or reuse. Each feature owns presentation, application controllers, and adapters; domain truth remains Flutter-free.

### State management

Riverpod remains suitable. Correct the future risk of provider sprawl by defining:

- Query providers for read models.
- Command controllers for mutations with typed pending/success/error states.
- Explicit session/farm/capability scopes.
- No business rules in widget callbacks.
- Persisted user work through repositories/outbox, not provider memory.
- Selectors and pagination for large ledgers.
- A deterministic Today-ranking service with explainable rule inputs.

### Canonical domain model

| Aggregate/entity | Purpose |
|---|---|
| Household | Shared device/ownership boundary without requiring cloud identity |
| PersonProfile | Language/audio/role/access preferences |
| Farm / Plot | Operational and spatial context; geometry remains optional |
| CropCycle | Crop, variety if known, planting/harvest timing, stage, status |
| FarmEvent | Immutable envelope: actor, time, place, provenance, source, supersession |
| Observation | Farmer evidence: photo, voice/text, symptom/context |
| Assessment | Model/expert/knowledge interpretation with version and coverage |
| Recommendation | Reviewed action set, constraints, source, expiry, jurisdiction |
| Task | Due window, completion/snooze/skip, origin and related event |
| MoneyEvent | Expense/income, category, amount/unit, crop-cycle link |
| InventoryLot | Optional input quantity, expiry, movement, treatment link |
| WeatherSnapshot / MarketQuote | External source, observed time, valid time, location/unit |
| ExpertCase | Shared evidence manifest, consent, SLA/cost, messages, resolution |
| Capability | Region/crop/version/dependency/permission/availability contract |
| SyncEnvelope | Client event ID, aggregate version, idempotency, tombstone/conflict data |

### Local storage

Use three failure domains:

1. `user.db`: household, farm, events, tasks, cases, settings, outbox/inbox.
2. `content.db`: immutable/replaceable knowledge indexes and localized metadata.
3. File vault: original media, derivatives, audio, model/content packs with reference table and quota.

Use FTS5 for offline knowledge and record search. Stage media to a temporary owned state, commit the referencing event, then mark durable. Deletion produces a tombstone and cleanup job; export precedes destructive reset when possible. Encrypt especially sensitive local credentials using platform keystore; evaluate SQLCipher only after measuring device cost and threat model.

### Offline synchronization

- Local commit is the default success state.
- Every syncable command writes an outbox record in the same transaction.
- Client-generated UUIDv7 event IDs and idempotency keys make retries safe.
- Server acknowledges version and canonical receipt time; it never silently overwrites local history.
- Conflicts are aggregate-specific: append events merge; profile fields use version prompts; task completion is monotonic with correction; media is content-addressed; deletion uses tombstones/retention.
- UI vocabulary is explicit: **On this phone**, **Waiting to send**, **Sent**, **Needs attention**, **Out of date**.
- Pack updates use signed manifests, chunked/resumable download, compatibility checks, atomic activation, rollback, and revocation.

### Backend

Use a modular monolith through public launch:

```text
FastAPI
  identity_access
  sync
  farms_records
  knowledge_content
  assessments
  experts_cases
  external_data
  capabilities
  consent_audit
      ↓
PostgreSQL | Redis | object storage | job worker | pack CDN
```

- PostgreSQL provides durable aggregates, row/tenant authorization, consent and audit.
- Redis handles bounded idempotency, rate limits, short-lived coordination, not system-of-record data.
- Object storage holds consented uploads and signed packs with retention policies.
- A worker handles thumbnails, pack build/validation, notifications, integrations, and expert routing.
- Separate services only when scaling, security isolation, deployment cadence, or ownership is demonstrated—likely media/ML jobs or external-data ingestion first.

### API boundaries

- `/v1/sync/push`, `/v1/sync/pull`: coarse-grained mobile batches with cursors.
- `/v1/capabilities`: device/region/crop/version availability and dependencies.
- `/v1/content/manifests`: signed packs via CDN.
- `/v1/expert-cases`: explicit evidence manifest and message stream/poll cursor.
- `/v1/external-data`: normalized weather/market/scheme snapshots with source/freshness.
- Administrative agronomy/content APIs are separate from farmer APIs and strongly authorized.
- REST/OpenAPI is sufficient. Do not add GraphQL before query needs justify its operational cost.

### AI architecture

```text
Farmer input
  → evidence/quality extractor
  → task router (vision, search, speech, translation, expert)
  → bounded model or reviewed retrieval
  → policy engine (coverage, confidence, risk, jurisdiction, freshness)
  → structured assessment/recommendation schema
  → decision brief + provenance + follow-up
```

- On-device models handle supported low-latency/offline tasks where device evaluation passes.
- Remote models may assist broader triage, speech, translation, or retrieval only with consented upload and a useful offline fallback.
- Generative models may rewrite reviewed content to literacy level, summarize a case, translate, or ask clarifying questions. They may not originate pesticide dose, mixing, waiting period, legal claim, or unsupported diagnosis.
- Registry records model/content/policy version, crop/region/device coverage, calibration, rollout cohort, and kill state.
- Evaluation includes class/region/device strata, abstention, action safety, translation fidelity, latency/size, and human disagreement.
- Feedback is not ground truth. Corrections become review cases; outcome learning requires consent and agronomist/model governance.

### Security, privacy, and maintainability

- Replace debug signing; establish Play App Signing and artifact attestation.
- Prove device-key possession and protect refresh material with Android Keystore.
- Support optional household profiles and role-scoped sharing; do not expose private records in notifications.
- Show an exact share manifest before expert/partner upload.
- Separate service consent, analytics consent, and model-training consent.
- Enforce authorization at repository/query level and test cross-household isolation.
- Build export, deletion, retention, backup, and incident response before public sync.
- Reconcile conflicting ADR numbers; automate ADR index validation.
- Add architecture fitness tests for forbidden Flutter imports, release sample/debug reachability, API compatibility, migrations, pack signatures, and module dependency direction.

## 7. Revised Accessibility Review

### Accessibility model

The target is not merely WCAG-conforming screens. It is successful farm work across literacy, language, age, disability, shared devices, outdoor conditions, fatigue, noise, and unreliable connectivity.

| Area | Current evidence | Version 2 requirement | Release test |
|---|---|---|---|
| Semantics | Thoughtful full-row nodes and labels | Shared components define label, value, state, hint, action and live-region behavior | TalkBack task completion, not tree snapshot alone |
| Text scaling | Responsive intent, AppBar risk | 200% text and large display across all locales; body owns full heading | No clipping/loss on representative devices |
| Touch | 48dp theme discipline | 52–56dp core field actions, spacing under one-handed/wet-hand use | Outdoor observed error rate |
| Devanagari | ARBs and script-aware spacing | Bundled reviewed font, ligatures/weights/numerals/line-height | Nepali/Hindi linguistic + visual QA |
| Literacy | Plain UI text only | Audio labels, human-recorded critical guidance, photo/choice alternatives | Unassisted comprehension with low-literacy participants |
| Camera | Opaque banner, semantics | Stable message hold, haptic/visual feedback, recovery, no rapid announcements | TalkBack + sunlight + moving-hand capture |
| Charts | Not present | Accessible summary, direct labels, table/list alternative, no color-only encoding | Screen reader and grayscale tests |
| Voice | Not present | Transcript confirmation, replay, edit, fallback, noise/dialect testing | Real farm/noise tasks in each supported language |
| Timing | Few timed interactions | No time limits; tasks/voice drafts recover after interruption | Background/kill/resume testing |
| Cognitive load | Restrained current UI | One main decision, progressive fields, explain reason, reversible actions | Five-second comprehension and recovery tests |

Critical content audio must include version and language in the pack manifest. If translation/audio is missing or expired, the product must say so rather than falling back invisibly to English.

## 8. Revised Performance Review

### Performance strategy

Treat battery, data, storage, and attention as performance budgets alongside frames and milliseconds.

| Budget | MVP target | Public-launch target | Failure behavior |
|---|---:|---:|---|
| Cold start to recovery-capable shell | P95 ≤2.5s | P95 ≤2.0s on supported low-end tier | Shell opens immediately; service init retries visibly |
| Today from local data | P95 ≤600ms | P95 ≤400ms | Last valid view remains with stale/refresh status |
| Camera usable preview | P95 ≤2.0s | P95 ≤1.5s | Typed retry/settings/gallery path |
| Shutter feedback | ≤100ms | ≤80ms | Freeze immediately; never accept double tap |
| Local record durable | P95 ≤350ms | P95 ≤250ms | Draft retained and retryable |
| On-device assessment | P95 ≤4s | P95 ≤3s per supported device/model | Progress then uncertain/manual/expert fallback |
| Timeline 1,000 events | 60Hz target | 60Hz with bounded image cache | Pagination and thumbnail placeholders |
| Core app download | ≤35MB target | Track by device/region | Optional capabilities remain separate |
| Initial regional pack | ≤80MB visible | Delta/resumable | Size, Wi-Fi/data choice, pause/delete |
| Background data | <10MB/month base goal | Measured by capability | Per-capability data controls |
| Storage | User-visible by category | Quota and reclaim tools | Original never deleted silently |
| Battery | No continuous background location/camera | Android vitals target monitored | Schedule/batch; capability disables gracefully |

Instrument time-to-first-useful-action, camera failures, abandoned voice/capture, queue age, pack failures, list jank, storage pressure, and background data. Analytics events must avoid raw farm text/photo content and honor consent.

## 9. Revised Design System Recommendations

### System layers

1. **Foundations:** color, type, spacing, shape, elevation, motion, iconography, photography, audio cues, chart palette.
2. **Primitives:** buttons, fields, sheets, dialogs, lists, tabs, chips, progress, banners.
3. **State patterns:** loading, delayed, empty, partial, stale, offline, queued, synced, permission, recoverable/terminal error.
4. **Farm components:** crop switcher, stage marker, task row, event item, money row, weather window, market quote.
5. **Trust components:** source/freshness, AI/human provenance, coverage, evidence quality, action/avoid/watch, consent manifest.
6. **Access components:** audio control, voice transcript confirmation, large-choice prompt, illustrated instruction.

### Token changes

- Add semantic tokens for `fresh`, `stale`, `queued`, `synced`, `warning`, `urgent`, `unknown`, `expert`, and `generated` states.
- Add locale typography tokens rather than one universal text style.
- Add field-mode and compact-mode density tokens; high-risk actions always use field mode.
- Add chart tokens with tested adjacent contrast and non-color patterns.
- Add content-width and page-rhythm tokens for compact phones, tablets, and web institutional views.

### Component contracts

Each component documents:

- Intended job and prohibited uses.
- Required/optional content and maximum lengths in all three languages.
- Interaction, keyboard/switch, focus, semantics, audio, loading and reduced-motion behavior.
- Offline/stale/provenance behavior.
- Field/compact density and text-scale examples.
- Golden, semantic, contrast, and interaction tests.

### Governance

- The farmer app and institutional web surface share foundations and domain language, not necessarily widget implementations.
- Capability teams cannot introduce a new status vocabulary; states map to the shared model.
- Agronomy copy, translations, audio, and icons are versioned content with named reviewers.
- A quarterly accessibility/localization audit and monthly component adoption report prevent divergence.
- Default Flutter launcher assets and generic splash are replaced before Beta recruitment.

## 10. Missing Opportunities

Version 1 missed or underdeveloped the following opportunities:

| Opportunity | Why it matters | Smallest credible version | Risk/control |
|---|---|---|---|
| Multimodal Ask | Farmers may know a problem by appearance, local term, or spoken story | Photo + voice/text + handbook retrieval + human fallback | Structured intake and provenance; no free-form authority |
| Seasonal operating plan | Creates recurring value before disease occurs | Crop-stage task template editable by farmer/expert | Local variation; never imply exact dates without context |
| Voice expense/observation | Converts field speech into a durable record quickly | Offline recording, transcript, amount/category confirmation | Noise/dialect; require visible correction |
| Household/shared work | Farm work spans family members and shared phones | Optional local profiles, assignment initials, later sync invites | Privacy and coercion; opt-in and clear ownership |
| Extension-worker mode | Human capacity can improve trust and distribution | Consented case queue and farmer-approved record view | Institutional surveillance; minimal scope and audit |
| Cooperative campaigns | Timely regional advisories and data collection | Signed targeted message with source/expiry and opt-out | Spam/political misuse; approval policy and frequency cap |
| Outcome follow-up | Turns advice into learning and safety monitoring | “Better / same / worse / did something else” task | Not ground truth; review before model use |
| Farm data passport | Portability increases trust and partner value | Human-readable PDF/CSV/JSON export with provenance | Re-identification; farmer-controlled sharing |
| Capability packs | Enables regional/crop fit without giant app | Crop/region content + model + audio + task templates manifest | Signature, compatibility, rollback, storage |
| Explainable Today ranking | Prevents opaque engagement feed | Rule reason: due, weather window, follow-up, reply, expiry | Alert fatigue; dismiss/snooze and audit |
| Local peer/co-op knowledge | Regional practices may outperform generic content | Expert-reviewed community tip submission, not open feed | Misinformation/moderation; named review and expiry |
| Input traceability | Connects treatment, inventory, expense, and outcome | Scan/enter lot and link to action | Counterfeit/incorrect catalog data; source labeling |
| Water/irrigation log | Important where irrigation is available or constrained | Manual watering event + reminder + weather interaction | Avoid precise prescriptions without soil/system data |
| Data-driven season review | Farmers need learning, not dashboard vanity | Cost, work, health events, yield notes, next-season prompts | Incomplete records; label estimates and missingness |
| Automation recipes | Reduce repeated work without opaque autonomy | “After planting, propose stage tasks”; user confirms | Wrong timing; explain and require confirmation |
| Store-and-forward expert media | Weak networks should not block escalation | Compress/resume case attachments with preview | Quality loss and privacy; preserve original locally |

## 11. Feature Expansion Proposal

### Capability portfolio

| Capability | Primary loop | Dependency | Activation rule | Monetization hypothesis |
|---|---|---|---|---|
| Farm kernel | Context/record | None | Always available | Free foundation |
| Records | Observe/remember | Farm kernel | Always available | Free; paid storage/sync later |
| Work planner | Plan/do | Crop cycle + templates | Active crop | Plus or institution-sponsored advanced templates |
| Ask/Handbook | Learn/resolve | Content packs | Region/crop pack | Free safety core; sponsored content operations |
| Crop Doctor | Assess/follow up | Ask + model/policy + KB | Supported crop/device/region | Plus or institutional program, never pay-per-confidence |
| Weather | Decide timing | Location + provider + rules | Coverage/freshness passes | Partner/institutional |
| Expert | Escalate/resolve | Identity/sync/capacity | Region/service hours | Case fee or institutional license |
| Money | Record/learn | Farm/cycle | User activates | Plus seasonal analytics |
| Market | Compare/sell | Crop/unit/location/provider | Trusted regional feed | Partner/API; no hidden sponsored ranking |
| Inventory | Plan/use | Money/tasks/catalog | User has repeated inputs | Plus/cooperative |
| Schemes | Discover/apply | Region/eligibility/source | Trusted institution feed | Government/NGO program |
| Irrigation | Schedule/record | Plot/weather/system data | Relevant farm type | Plus/partner |
| Sensors/satellite | Monitor/predict | Geometry/hardware/provider | Explicit compatible integration | Partner subscription |
| Institutional console | Support caseload | Consent/roles/sync | Contracted organization | B2B/B2G license |

### Capability contract

Every module declares: value proposition, supported region/crop/role, required data, permissions, offline behavior, storage/data size, source/freshness, safety class, dependencies, price/payer, support owner, metrics, and shutdown/export behavior. A module with no service owner or freshness SLO cannot be marked available.

### Prioritization formula

Use a transparent score each quarter:

```text
Priority = (farmer value × reach × frequency × evidence confidence)
           / (delivery cost × operational burden × harm risk)
```

Strategic foundation work may override the score only with an explicit decision record and expiry date. Revenue does not multiply advice priority.

## 12. New Product Roadmap

Roadmap dates are ranges, not promises. Each phase exits on evidence rather than calendar alone.

### MVP — Farm memory and help foundation (0–4 months)

| Dimension | Commitment |
|---|---|
| Features | Startup/release/media fixes; language/audio entry; farm + active crop; event ledger; photo/voice/text observation; offline handbook; tasks; cached basic weather with freshness; working expert directory/request pilot; redesigned Today/Ask/Records shell; no distributable AI diagnosis |
| Objectives | Prove farmers can create context, record work, return to a next task, find reviewed help, and understand offline/sync language |
| Dependencies | Agronomy content workflow, field research panel, Devanagari font/audio, local DB redesign, provider pilot, release CI |
| Risks | Too much setup, weak recurring value, content operations slower than code, expert capacity |
| Success metrics | ≥70% complete first useful action; ≥50% create active crop; ≥40% return in week 2 during active season; ≥60% of returners complete/record one useful event; ≥90% critical-guidance comprehension; crash-free sessions ≥99.5% |
| Exit criteria | All P0 blockers closed; 30–50 representative households complete core offline tasks; no unresolved severe safety/accessibility issue; handbook content/version operations demonstrated; service capacity meets stated ETA |

### Beta — Bounded intelligence and recurring loops (5–8 months)

| Dimension | Commitment |
|---|---|
| Features | Real Crop Doctor shadow then pilot for 1–2 crops/limited conditions; guided capture; decision brief; outcome follow-up; secure sync; household profile; expert case messaging; expense records; richer Today; market quote pilot; pack manager |
| Objectives | Prove bounded AI improves resolution without harmful overconfidence and that non-diagnosis loops drive retention |
| Dependencies | Dataset/model evaluation, policy engine, reviewed KB mapping, PostgreSQL/Redis/object store, Keystore identity, expert workflow, weather/market contracts |
| Risks | Model/translation disparity, case overload, sync conflict, data/provider staleness, battery/storage |
| Success metrics | Supported-case assessment helpfulness ≥80%; unsafe action recommendation = 0 in reviewed pilot; abstention within approved band; expert SLA ≥90%; week-4 active-season retention ≥35%; ≥2 distinct loops used by 40% of retained households; sync success ≥99% excluding offline queue |
| Exit criteria | Agronomy/model/accessibility/security gates signed; kill/rollback drill passes; no raw label/no-op path; external data shows source/freshness; unit economics and support load measured |

### Public Launch — Reliable regional product (9–12 months)

| Dimension | Commitment |
|---|---|
| Features | Production infrastructure/observability/support; expanded validated crop/condition packs; robust offline downloads; export/delete/recovery; Today/Farm/Ask/Records/Services shell; tasks/weather/expenses; expert and selected market coverage; Plus/institution pilot billing |
| Objectives | Deliver a reliable regional system of record and decision companion with sustainable operations |
| Dependencies | Store compliance, incident response, customer support, content release train, partner SLAs, consent/legal review, analytics governance |
| Risks | Scale exposes agronomy/support/provider gaps; payer incentives distort priorities; shared-device privacy |
| Success metrics | Crash-free ≥99.7%; P95 startup/camera budgets met; 30-day active-season retention ≥30%; ≥50% retained users use 3 loops/month; harmful advice incidents below defined zero-tolerance class; support first response within published SLA; positive contribution path per institutional cohort |
| Exit criteria | Two successful release/rollback cycles; on-call and incident drill; all critical WCAG/field tests pass; retention and service costs meet board-approved thresholds; farmer export/deletion verified |

### Version 2 — Seasonal operations platform (12–24 months)

| Dimension | Commitment |
|---|---|
| Features | Multiple farms/plots/cycles; inventory; seasonal plan/review; household collaboration; cooperative/extension console; scheme capability; richer markets; provider APIs; optional plot geometry/satellite; advanced analytics |
| Objectives | Become the trusted seasonal operating record and a scalable institutional service platform |
| Dependencies | Mature role/consent model, institutional onboarding, API governance, data quality SLOs, web console design system, partner support |
| Risks | Institutional surveillance, enterprise requests pollute farmer UX, incomplete records make analytics misleading, partner lock-in |
| Success metrics | Season-over-season retention ≥45% among completed cycles; ≥30% households share/export a record for a useful purpose; institutional renewal target met; farmer task time does not regress; capability-specific outcome measures improve |
| Exit criteria | Independent privacy/fairness review; farmer and institution roles proven without data leakage; module shutdown/export drills; at least two interoperable partner capabilities |

### Version 3 — Smallholder farming OS ecosystem (24–60 months)

| Dimension | Commitment |
|---|---|
| Features | Public partner capability framework; sensors/irrigation/satellite where justified; forecasting and confirmed automation; cross-season benchmarks; consented data passport; buyer/logistics/finance referrals; multi-region content/model operations |
| Objectives | Let farmers and trusted organizations compose services around a portable farm record without surrendering control |
| Dependencies | Mature trust/governance, regional teams, certification, partner sandbox, auditability, sustainable business model |
| Risks | Platform abuse, financial exclusion, algorithmic discrimination, ecosystem fragmentation, operational overreach |
| Success metrics | Partner quality/SLO compliance; measurable farmer income/time/risk outcomes by cohort; low complaint/incident rate; data portability use; diversified revenue without advice-ranking conflicts |
| Exit criteria | Governance board and enforcement demonstrated; independent impact evaluation; partner removal works without farmer data loss; expansion meets region-specific safety/economic thresholds |

## 13. Updated Risk Register

| Risk | Horizon | Probability | Impact | Early signal | Control / stop condition |
|---|---|---:|---:|---|---|
| Product becomes a cluttered super-app | MVP+ | High | High | More tiles, lower task success, weak module repeat | Progressive capability activation; one decision queue; remove modules below value/SLO threshold |
| Crop Doctor remains an attractive but episodic gimmick | Beta | High | High | High installs, low week-4/season retention | Measure cross-loop adoption; invest in farm/work/record recurrence |
| Harmful or misunderstood advice | Beta+ | Medium | Severe | Expert corrections, worsening outcomes, comprehension gaps | Bounded coverage, policy/KB, abstention, kill switch, human escalation; stop affected pack |
| Platform kernel overengineering delays value | MVP | Medium | High | Architecture tasks without user-visible loop | Thin event/kernel implementation; vertical slices; four-month exit gate |
| Content/audio operations cannot keep pace | MVP+ | High | High | Expired/missing translations, delayed packs | Named content owners, scoped crops/regions, release calendar; hide unsupported capability |
| Expert demand exceeds capacity | MVP+ | High | High | Queue age and abandonment exceed promise | Show ETA/cost/hours, capacity routing, limit cohort; pause acquisition |
| Today ranking creates false urgency or bias | MVP+ | Medium | High | Dismissals, alert fatigue, ignored tasks | Auditable rules, reason, snooze/dismiss, no engagement optimization |
| Offline label hides partial failure | MVP+ | High | High | Queued cases mistaken as sent, stale price acted upon | Explicit state vocabulary, freshness, queue age and recovery testing |
| Shared-device records leak | Beta+ | Medium | Severe | Household complaints, notification exposure | Local profiles, lock/redaction, scoped sync/sharing, threat tests |
| Institutions become de facto data owners | V2 | Medium | Severe | Mandatory sharing, inability to revoke/export | Farmer-owned consent, purpose/scope/expiry, audit and regulator review; terminate violating tenant |
| Commerce biases agronomy | V2+ | Medium | Severe | Recommended products correlate with margin | Organizational/data separation, ranking audit, disclosures; prohibit pay-to-rank advice |
| Weak provider data harms weather/market trust | MVP+ | High | High | Missing/stale/conflicting feeds | Multi-source quality score, explicit source/time, safe degradation, SLO termination |
| Event ledger becomes incomprehensible | Beta+ | Medium | Medium | Low findability with >100 events | Typed views, stage grouping, search, provenance, raw history access |
| Voice errors corrupt money/agronomy records | MVP+ | High | High | Edit/correction rate, dialect disparity | Transcript confirmation, constrained fields, audio replay, manual fallback |
| Local media/packs exhaust storage | MVP+ | High | High | Save/download failures | Quota, derivatives, pack size/delta, reclaim tools, low-storage test |
| Sync duplicates or loses farm events | Beta+ | Medium | Severe | Divergent event counts/version conflicts | Transactional outbox, idempotency, append semantics, chaos and migration tests |
| AI disparities across region/device/language | Beta+ | High | Severe | Stratified performance/comprehension gaps | Coverage registry, cohort gates, abstention, local validation; disable failing strata |
| Monetization excludes smallholders | Launch+ | Medium | High | Safety/core feature paywall, low-income churn | Free farmer-owned records/safety content, institutional subsidy, pricing research |
| Metrics optimize engagement rather than outcomes | All | High | High | More opens with no task/outcome improvement | Outcome metric hierarchy; no streak/notification dark patterns; ethics review |

## 14. Prioritized Action Plan

### First 30 days — decide and de-risk

1. Adopt Option D and define the farm-event/capability contracts in ADRs; repair ADR numbering.
2. Recruit a standing research cohort across gender, age, literacy, crops, geography, phone tier, connectivity, and shared-device use.
3. Prototype three vertical slices: start crop, record observation, complete a Today task. Test before schema hardening.
4. Establish agronomy/content governance, expert capacity/cost assumptions, and initial crop/region scope.
5. Close debug signing, startup recovery, no-op actions, sample-release reachability, and media ownership blockers.
6. Define business hypotheses for farmer-free, Plus, and institutional routes; identify who funds MVP operations.

### Days 31–60 — build the platform kernel through visible value

1. Implement household/farm/crop-cycle/event/task/media domain and local migrations.
2. Replace Home/Notebook/History with the shell and Records read models behind feature flags.
3. Build offline handbook pack runtime with search, source/version, audio manifest, signing design, and one validated content slice.
4. Implement voice transcript confirmation for observation and expense prototypes.
5. Stabilize camera/permission states and capture metrics on supported devices.
6. Build a real expert-case service prototype with share manifest, queue, ETA/cost, and operator workflow.

### Days 61–120 — MVP field loop

1. Ship Today ranking rules for task/follow-up/weather/expert events.
2. Add one weather provider and explicit source/freshness/offline cache.
3. Complete release, accessibility, localization, performance, export/recovery, and low-storage gates.
4. Conduct repeated field use across a crop stage, not one lab session.
5. Measure return behavior, record completeness, comprehension, expert workload, content cost, and failures.
6. Make the MVP/Beta go/no-go decision from exit criteria; do not advance because the calendar ended.

### Priority backlog

| Priority | Workstream | Definition of done |
|---|---|---|
| P0 | Release truth | Production signing, startup shell, no sample/debug/no-op path, media integrity, ADR repair |
| P0 | Research/service foundation | Cohort, agronomy reviewers, expert operator, consent model, payer hypothesis |
| P1 | Farm/event kernel | Local household/farm/cycle/events/tasks, provenance, corrections, export, migrations |
| P1 | Experience shell | Today/Farm/Ask/Records/Services with empty/offline/stale/recovery states |
| P1 | Knowledge/access | Signed handbook slice, FTS, reviewed translations, font, critical audio |
| P1 | Field inputs | Stable camera, voice confirmation, gallery, contextual crop/stage, low-end metrics |
| P1 | Expert pilot | Working case bundle, queue, SLA/cost, response, outcome, privacy |
| P2 | Sync/backend | PostgreSQL/Redis/object store, secure identity, outbox/inbox, conflicts, observability |
| P2 | Bounded Crop Doctor | Validated model, policy, decision brief, monitoring, follow-up, kill/rollback |
| P2 | Daily/economic loops | Weather actions, expenses, market pilot, seasonal summary |
| P3 | Institutional/partner | Role/consent console, APIs, schemes, inventory, integrations after evidence |

### Decision dashboard

Leadership should review these together each month:

- **Farmer outcome:** useful tasks/decisions completed, time saved, issues resolved, seasonal record used.
- **Trust/safety:** comprehension, abstention, escalations, harmful incidents, source/content freshness.
- **Retention:** active-season week 2/4 and season-over-season; number of distinct useful loops, not raw sessions.
- **Equity:** outcome gaps by language, literacy, gender, geography, device, connectivity, and shared-device use.
- **Operations:** expert SLA/cost, content update lead time, provider freshness, support burden.
- **Technical:** crash-free, startup/camera latency, queue age, sync integrity, pack failure, storage/data/battery.
- **Business:** acquisition channel, cost per active household, payer conversion/renewal, contribution path, concentration risk.

## 15. Final Product Vision

### Vision statement

KrishiDoc becomes the **farmer-controlled operating record and decision layer for a smallholding**. It remembers the season, explains what needs attention, accepts evidence by photo/voice/text, works through weak connectivity, connects trusted people and services, and makes every automated suggestion traceable and reversible.

### What the product feels like

- As focused as Linear’s attention queue, but designed for weather-dependent field work.
- As structurally flexible as Notion’s multiple views, without exposing database construction.
- As operationally explicit as Stripe’s resource/state model, without dashboard density.
- As dependable about downloaded capability as Google Maps offline packs.
- As clear about the next small step as Duolingo, without coercive streaks.
- As calm and layered across self-help, AI, and humans as Headspace, while preserving agronomic source and accountability.

### Non-negotiable principles

1. The farmer owns the record and decides what leaves the phone.
2. Architecture is broad; each moment is simple.
3. External data always shows source, place, unit, observation/valid time, and freshness.
4. AI is bounded by coverage, reviewed knowledge, policy, provenance, and human fallback.
5. Offline is described per capability, not used as a blanket marketing claim.
6. Voice and regional language are primary access modes, not decorative localization.
7. Advice ranking is independent from commerce and payer incentives.
8. Every module has an operator, SLO, safety class, metrics, and shutdown path.
9. Success is improved farm decisions and usable seasonal memory, not screen count or daily opens.
10. No roadmap phase exits without field, operational, accessibility, technical, and economic evidence.

### Final quality gate

| Question | Version 2 answer |
|---|---|
| Did this materially improve Version 1? | **Yes.** It changes the strategy from a narrow core with later expansion to an OS kernel with phased coherent loops; it adds business/distribution, capability governance, and outcome-weighted scoring. |
| Were prior assumptions challenged? | **Yes.** Crop Doctor centrality, fixed navigation, expansion aversion, scoring, data architecture, and roadmap gates were re-decided. |
| Is major guidance evidence-backed? | **Yes, with explicit limits.** Repository facts, Nepal official statistics/FAO context, and first-party product patterns are linked; unvalidated user behavior remains labeled as hypothesis. |
| Are implementation paths realistic? | **Yes, conditionally.** The modular monolith, event kernel, local-first sync, capability contract, vertical slices, service operations, metrics, and exit gates specify how to proceed without pretending capacity is known. |
| Will this improve product decisions? | **Yes, if used as a stage-gate system rather than a feature mandate.** It makes tradeoffs, owners, dependencies, revenue conflicts, stop conditions, and evidence gaps visible. |

**Final recommendation:** authorize the phased hybrid strategy and a four-month MVP that proves farm memory, Today/work, reviewed help, and human service as one coherent smallholder loop. Build the operating-system kernel beneath it, but do not expose operating-system complexity. Crop Doctor enters Beta only as a bounded capability with a complete safety and operations chain. Public launch requires evidence of recurring multi-loop value and sustainable service delivery—not merely a working classifier.
