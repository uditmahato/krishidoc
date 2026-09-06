# KrishiDoc Mandatory Adversarial Re-Review — Version 3

**Review date:** 4 August 2026  
**Repository state reviewed:** branch `v2`, commit `80eeeff`  
**Prior document attacked:** `docs/PRINCIPAL_PRODUCT_REVIEW_V2.md`, all 819 lines read  
**Review form:** difference report, not a rewritten generic product audit

## Adversarial verdict

Version 2 was directionally better than a diagnosis-only strategy, but it solved the wrong strategic equation. It selected a general-purpose “smallholder farming OS” before selecting a buyer, distribution channel, value chain, geography, service operator, or measurable economic outcome. It designed a sophisticated farmer record and platform kernel, then assumed adoption would follow.

The stronger strategy is a **partner-led crop-and-livestock operations network**:

- Choose one high-value crop or livestock value chain and one committed cooperative, extension program, agribusiness, or local-government partner.
- Give farmers a very small companion for work, questions, and receipts/records.
- Give field agents an offline enrollment, visit, triage, and follow-up workflow.
- Give partner operators a case, advisory, aggregation, and outcome console.
- Give agronomists/veterinarians a governed knowledge and decision-support studio.
- Use AI first to improve human service capacity, translation, quality control, and outbreak detection. Automate farmer-facing diagnosis only after the service produces sufficient validated evidence.

This is not a narrow crop-help core and not a generic OS. It is a vertical network that can later become a platform after one value chain repeats successfully.

### Disposition summary

Version 2’s granular recommendations were normalized into 70 decision clusters so duplicated bullets, tables, and roadmap items could be judged once without inflating agreement. Every recommendation maps to at least one cluster below.

| Disposition | Count | Share |
|---|---:|---:|
| Correct and retained substantially intact | 24 | 34% |
| Needs correction: partial, missing context, unsupported, poorly prioritized, or too absolute | 30 | 43% |
| Incorrect | 10 | 14% |
| Too ambitious for the assumed team/stage | 6 | 9% |
| **Total** | **70** | **100%** |

Only 34% survives intact. The result is materially different without manufacturing disagreement.

# Section 1 — Everything Version 2 Got Right

These recommendations survive because repository evidence, safety logic, or authoritative external evidence supports them. “Correct” does not mean sufficient.

| ID | Version 2 recommendation | Verdict | Evidence and defense |
|---|---|---|---|
| R01 | The current product is not production-ready | Correct | Sample inference, no client API, in-memory server state, startup risk, no-op result actions, and debug release signing are observable repository facts |
| R02 | Sample inference and debug preview must be unreachable in distributable builds | Correct | `SampleClassifier` hashes image bytes; permanent sample labeling is honest but cannot make it diagnostic |
| R03 | Enabled no-op expert/correction actions must be removed or completed | Correct | False affordances are a trust and accessibility defect, not merely incomplete scope |
| R04 | Release signing, startup recovery, and photo lifecycle are P0 | Correct | These can cause insecure artifacts, black startup, privacy leakage, and low-storage failure independent of product strategy |
| R05 | Retain confident/uncertain/out-of-scope states | Correct | Abstention and coverage boundaries are essential for any human- or model-assisted assessment |
| R06 | Results need evidence, action, avoid, monitor, source, and follow-up | Correct | Classification without a governed next action does not solve a farmer decision |
| R07 | External data must show source, location/unit, observation/valid time, and freshness | Correct | Weather, price, scheme, and advisory data can become harmful when stale or context-free |
| R08 | AI must be bounded by coverage, reviewed knowledge, policy, provenance, and human fallback | Correct | Generative fluency is not agronomic validation; dose/mixing/waiting-period generation remains prohibited |
| R09 | Training consent must be separate from product/service consent | Correct | A farmer asking for help has not consented to future model training |
| R10 | Sharing needs an explicit manifest | Correct | Farmers need to see which photos, location, records, and identifiers leave the device and why |
| R11 | Offline states must distinguish local, queued, sent, stale, and failed | Correct | “Offline-first” is otherwise an ambiguous marketing phrase; store-and-forward services depend on clear state |
| R12 | Content/model/audio packs need signature, compatibility, atomic activation, rollback, and revocation | Correct | Pack compromise or partial update can alter high-impact advice outside app-store review |
| R13 | Keep local records useful before login or network | Correct | Weak connectivity and shared/low-end device contexts make network-dependent first value fragile |
| R14 | Retain Flutter, Drift, Riverpod, GoRouter, and pure-Dart domain boundaries for now | Correct | No evidence justifies a framework rewrite; the present seams are testable and suitable for the intended Android client |
| R15 | Use a modular monolith before microservices | Correct | The current team/product has no demonstrated scale or ownership boundary that justifies distributed-service overhead |
| R16 | Riverpod needs query/command conventions and persisted truth outside provider memory | Correct | This prevents provider sprawl without replacing a workable state-management choice |
| R17 | Camera messages need hysteresis, stable announcements, typed permission/device recovery, and a fallback | Correct | Current 5 Hz assessment can chatter; farmers need recovery rather than judgment without explanation |
| R18 | Devanagari font, locale typography, TalkBack, 200% text, outdoor, and low-literacy tests are release evidence | Correct | ARB parity is not comprehension or rendering proof |
| R19 | Voice must have transcript/replay/correction and nonvoice fallback | Correct | Noise, dialects, code-switching, recognition errors, and disability make voice-only interaction unsafe |
| R20 | Performance includes battery, mobile data, storage, attention, frames, and latency | Correct | Farm software fails when it exhausts a low-end device even if screen rendering benchmarks pass |
| R21 | Design-system states must include offline, stale, queued, source, provenance, and trust | Correct | Domain-state consistency becomes more important as multiple surfaces and operators are added |
| R22 | Commerce must not rank agronomic advice | Correct | Supplier or transaction incentives cannot determine diagnostic/treatment priority |
| R23 | Measure outcomes, safety, equity, operations, and economics—not raw opens | Correct | Engagement without better decisions, income, time, or risk is not agricultural value |
| R24 | Use research gates, rollback/kill drills, export/deletion, and incident readiness | Correct | These are necessary controls for advice, sync, partner access, and production operation |

### What the retained 34% means

Most retained items are **quality constraints**, not the product strategy. Version 2 was strongest when it described what must never fail. It was weakest when it inferred who the product is for, why they return, who pays, and what to build first.

# Section 2 — Everything Version 2 Got Wrong

## Recommendation-by-recommendation challenge register

| ID | Version 2 recommendation | Disposition | Why it fails or lacks context | Replacement |
|---|---|---|---|---|
| R25 | Become a modular smallholder farming OS | Missing context | “Smallholder” is not one segment; subsistence grain, commercial vegetables, goats, dairy, seed, orchards, and cooperative production have different jobs/payers | Select one value chain + partner + outcome; generalize only after repeatability |
| R26 | Select Option D using a 7.8 weighted score | Unsupported | Weights and 1–10 values were invented; precision concealed the absence of market, willingness-to-pay, service-cost, and adoption data | Use explicit hypotheses and reversible gates; no strategic decimal until evidence exists |
| R27 | Build the OS data kernel in MVP | Too ambitious | It front-loads household, farm, plot, cycle, events, tasks, capabilities, sync, content, experts, weather, and money before proving a valuable workflow | Build the thinnest vertical data model for one partner program; extract a kernel after the second repeat |
| R28 | Use crop help as acquisition and Today/records as retention | Partially correct | Acquisition cost/channel and record-taking motivation are unknown; many farmers receive help through people/groups rather than app discovery | Let partner/agent enrollment be the acquisition channel; test farmer self-service as one channel |
| R29 | Use farmer-owned record as the central value | Missing context | Manual data entry creates work; value is delayed unless records unlock advice, payment, buyer access, compliance, or coordination | Capture only records that trigger an immediate service or later transaction the farmer values |
| R30 | Target all smallholders | Incorrect | Official data covers crop, livestock, forestry, fisheries, beekeeping, floriculture, and more; needs differ by geography and commercialization | Define an initial ICP: value chain, district, farm economics, organization, language, device/channel, and decision |
| R31 | Fixed shell: Today / Farm / Ask / Records / Services | Poorly prioritized | Five empty abstractions require the unbuilt OS and duplicate concepts; Services becomes the super-app drawer Version 2 warned about | Farmer pilot shell: **Work / Ask / Records**; partner context is implicit; expand only after observed use |
| R32 | Today is the source of truth | Partially correct | A software inbox assumes frequent app opening and predictable task models; partner calls, IVR, group meetings, weather, and field agents may be the real source | One work queue shared across app, IVR/SMS, agent, and console; app Today is merely one projection |
| R33 | Ask exposes photo, speak, type, search, and expert at once | Incorrect | Five modes increase decision load and blur whether the user seeks search, triage, or human service | Start with “Show or tell us the problem”; system/agent chooses evidence path; expert escalation is an outcome |
| R34 | First use asks Start crop / Ask / Browse guide | Partially correct | Three jobs are better than a tutorial but still assume self-onboarding and an app-led relationship | Partner code/agent enrollment path plus a self-service “Get help” path; request context only as needed |
| R35 | Guided 1–3 photo capture is the preferred diagnosis intake | Partially correct | More photos help some vision tasks but symptoms may require whole plant, field pattern, underside, root, pest, weather, or history | Dynamic evidence checklist determined by case type; allow voice/agent observation and “cannot capture” |
| R36 | Merge notebook/history into one farm event ledger | Too ambitious | Event-sourcing language overfits auditability, complicates deletion/corrections/querying, and imposes a record ontology before workflows are known | Conventional operational tables plus append-only audit/activity log; unified views without event-sourcing everything |
| R37 | Use household → farm → plot → crop cycle as canonical hierarchy | Incorrect | It excludes livestock-only holdings, communal/cooperative production, rented/fragmented parcels, sheds, ponds, herds, and post-harvest assets | Organization/participant → production unit → production cycle; unit can be plot, herd, flock, pond, orchard, greenhouse, facility |
| R38 | Immutable corrections supersede prior farm events | Missing context | Audit is useful, but deletion rights, mistaken sensitive notes, and simple farmer edits conflict with universal immutability | Immutable server audit for regulated/partner actions; editable farmer records with version history and deletion policy |
| R39 | Split local data into user DB, content DB, and file vault immediately | Partially correct | Replaceable content and file ownership are sound; separate databases add migration/backup complexity before content scale is known | Keep user SQLite + file vault; add content DB when signed pack replacement/FTS justifies isolation |
| R40 | Build custom push/pull sync with aggregate conflicts | Too ambitious | Custom local-first sync is a product in itself; the team has no durable backend or sync behavior evidence | Spike managed sync vs minimal program-scoped batch sync; choose after offline conflict prototypes |
| R41 | PostgreSQL + Redis + object storage + worker + CDN for MVP path | Too ambitious | PostgreSQL and object storage are plausible; Redis, job topology, and CDN are premature without load or pack operations | PostgreSQL + object storage + one background worker; use DB idempotency/rate controls until evidence requires Redis/CDN |
| R42 | Preserve device-public-key identity and add proof/Keystore | Poorly prioritized | Cryptographic device identity is technically elegant but does not solve partner enrollment, device replacement, shared phones, or farmer recovery | Program/partner enrollment code + optional phone/account recovery; bind secure device credentials only after identity journey is defined |
| R43 | Require no account before local value | Partially correct | Correct for self-service, but partner programs may need enrollment to deliver expert/market/benefit value and measure outcomes | Two modes: guest local help and transparent program enrollment with explicit benefits and data scope |
| R44 | Farmer always owns and controls the record | Partially correct | Normatively desirable but operationally vague when an institution pays, an agent creates data, or law/contract requires retention | Define data stewardship by record type, actor, purpose, retention, access, correction, portability, and revocation |
| R45 | Human-record all critical content audio | Too ambitious | Recording, translation, review, re-recording, and pack distribution can dominate operations and delay urgent updates | Human-record high-frequency/high-harm evergreen content; verified TTS/agent playback for fast-changing items, labeled clearly |
| R46 | Voice expense/observation in MVP | Unsupported | Offline multilingual ASR, code-switching, currency/unit parsing, noise, and correction burden are nontrivial; no user evidence selects voice expense | Pilot voice notes first; structured extraction remains agent-assisted or online until error/cost evidence passes |
| R47 | Add weather in MVP | Unsupported | Nepal’s topography and microclimates make generic forecasts easy to overstate; provider coverage and action rules were not evaluated | Begin with authoritative hazard/advisory distribution through a partner; add farm-level weather only where validated |
| R48 | Launch direct expert request in MVP | Partially correct | Safety need is real; capacity, credentials, liability, schedule, language, channel, and cost are undefined | Partner-operated triage queue with published scope/SLA; farmers can use existing call/agent channel |
| R49 | Add expenses early as a retention loop | Unsupported | Farmers may not maintain isolated expense records unless tied to credit, cooperative settlement, margin, tax, or input planning | Record transactions automatically/with agent when tied to input distribution, sales, or program benefit; test manual entry separately |
| R50 | Crop Doctor enters Beta as a bounded model | Poorly prioritized | It still puts automation before a labeled case stream and human service economics | Expert copilot first: quality checks, case summary, KB retrieval, translation, duplicate/outbreak clustering; farmer automation later |
| R51 | Four-month MVP includes farm, ledger, voice, handbook, tasks, weather, expert, shell, audio, release hardening | Incorrect | This is multiple products and operational programs; “thin slices” do not remove content, partner, service, and field complexity | Eight-week discovery/partner gate, then a 12-week concierge pilot with one outcome and one workflow |
| R52 | Public launch in 9–12 months | Unsupported | No production inference, content operation, durable backend, distribution contract, support, or device verification exists | Launch timing follows two repeatable pilots and production readiness; planning range 15–24 months, not a promise |
| R53 | 30–50 households are enough for MVP exit | Missing context | Useful for qualitative usability, insufficient for rare safety failures, retention, subgroup equity, service cost, or model performance | Mixed evidence: qualitative cohorts plus 100–300 participant operational pilot; model validation requires separate powered datasets |
| R54 | Numeric retention/helpfulness/SLA thresholds in roadmap | Unsupported | No baseline, season length, channel, cohort, or event frequency justifies the exact values | Pre-register pilot-specific hypotheses after baseline; use confidence intervals and cohort definitions |
| R55 | Farmer Plus is a core business layer | Unsupported | Direct willingness to pay among the selected segment is unknown and safety/core paywalls create exclusion | Treat B2B2C/institutional funding as primary hypothesis; test household payment only after measurable economic value |
| R56 | Institutional model is one later capability | Incorrect | Institutions may be the acquisition channel, payer, expert operator, and data steward from day one | Design farmer, field-agent, supervisor, and expert surfaces together for the first pilot |
| R57 | Capability contract for every module now | Too ambitious | Broad governance becomes documentation theater before modules/owners exist | Define contracts only for pilot capabilities, then standardize after two implementations |
| R58 | Reorganize code into many feature/runtime packages | Poorly prioritized | Current package boundaries are understandable; early reorg creates churn while product boundaries are uncertain | Preserve packages; add vertical folders inside the app and extract only proven independent runtimes |
| R59 | Keep every original media asset until explicit user deletion | Partially correct | Privacy and evidence matter, but storage can make the app unusable; partner cases may have retention requirements | Configurable retention, consented upload, compressed derivatives, archive/export, and transparent cleanup policy |
| R60 | Prohibit profile-completion indicators | Too absolute | Generic percentages can create busywork, but benefit-specific completeness can support applications, traceability, insurance, or buyer readiness | Show purpose-bound readiness: “2 items needed to submit this case,” never a generic engagement score |
| R61 | Cross-industry patterns justify Today/database views/dashboard model | Missing context | Linear, Notion, and Stripe serve literate power users with different stakes/devices; analogy is inspiration, not evidence | Validate each borrowed pattern with field tasks; prioritize agricultural service channels and operator workflows |
| R62 | Sensors and satellite can be one later capability | Incorrect | Their economics and jobs differ: satellite can serve regional/cooperative monitoring without farmer hardware; sensors may fit shared irrigation/cold-chain assets | Evaluate satellite, shared sensors, and on-farm sensors separately by value chain and spatial/operational fit |
| R63 | Market is primarily a price-information module | Incorrect | Nepal programs show market access depends on farmer groups, aggregation, collection/cold storage, quality, business plans, and buyer links—not prices alone | Build production/harvest intent, aggregation, quality, logistics, and buyer coordination for the selected value chain |
| R64 | Livestock can wait outside the crop-oriented model | Incorrect | Official 2022/23 data reports goat ownership around 61%, poultry 43.9%, cattle 37.8%, and buffalo 33.5% among agricultural households | Initial value-chain selection must include livestock candidates; use production-unit model |
| R65 | Climate is mostly a weather-card concern | Incorrect | Nepal faces floods, drought, heat, landslides, water risk, crop/livestock impacts, and post-disaster recovery | Add hazard preparedness, resilient practice, water, recovery, and partner alerts—not just forecast cards |
| R66 | Marketplace/transactions should wait broadly | Partially correct | Open marketplace is premature, but group input procurement and buyer commitments may be the most valuable first workflow | Allow closed partner procurement/aggregation pilot with conflict controls; defer open marketplace |
| R67 | Community should be expert-reviewed tips only | Missing context | Peer networks, farmer groups, shared labor, equipment, and collective selling may be core, not content garnish | Use moderated program groups and structured requests/offers; avoid open social feed |
| R68 | Performance budgets can be declared now | Unsupported | P95 numbers, 35MB app, 80MB pack, and 10MB/month were not measured against current binaries/devices/content | Establish baselines on target devices, then set budgets tied to user tolerance and distribution constraints |
| R69 | Default app architecture can cover institutional web later | Missing context | Agent and operations workflows have batch work, maps, queues, exports, and permissions unlike the farmer app | Share domain/API/design language; design console information architecture independently |
| R70 | A 3–5 year OS roadmap is decision-useful now | Incorrect | Detail beyond the first repeatable value chain creates false certainty before distribution and economics are known | Roadmap by evidence gates: thesis → concierge → repeat → productize → expand → platform |

## Root causes behind the errors

### Product bias: “record first”

Version 2 assumed a farm record creates compounding value. It can, but only if capture is cheaper than the benefit. A farmer may reasonably reject manual record-keeping that does not change an advisory, payment, buyer decision, compliance outcome, or labor plan.

### Engineering bias: platform before repetition

The event ledger, capability registry, custom sync, multi-database client, pack CDN, and extensive domain model optimize a future platform. The repository has not yet proven one production workflow or durable server repository.

### Direct-to-farmer bias

FAO’s Nepal Digital Villages work explicitly includes extension agents, community centers, government, SMEs, and value-chain actors. A 2026 World Bank-supported Nepal example links farmer groups, local government, cold/collection infrastructure, and buyers to reduce post-harvest loss and transport cost. The application cannot be reviewed as if distribution and service exist outside the product. [FAO Nepal DVI](https://www.fao.org/digital-villages-initiative/asia-pacific/country-briefs/en), [World Bank Nepal market linkage](https://www.worldbank.org/en/news/feature/2026/02/18/linking-farmers-to-markets-a-sustainable-model-from-a-rural-municipality-in-nepal)

### Crop bias

Nepal’s agriculture census explicitly covers crop and livestock production and ancillary activities. The current crop-only hierarchy would need a conceptual rewrite for herds, flocks, ponds, beekeeping, nurseries, dairy, and shared facilities. [Nepal NSCA scope](https://microdata.nsonepal.gov.np/index.php/catalog/134/study-description)

## Who would object to Version 2

| Stakeholder | Likely objection | Consequence |
|---|---|---|
| Experienced farmer | “Why should I keep all these records, and where are livestock, buyers, transport, water, and group work?” | Manual record adoption and crop-only relevance were assumed |
| Woman/shared-device user | “Who can see records entered by my household, agent, cooperative, or sponsor?” | “Farmer-owned” was a principle without an implementable power/role model |
| Field agent | “The roadmap gives the farmer an app but gives me no visit, roster, offline follow-up, or supervision tool.” | The likely distribution/service channel was omitted |
| Agronomist/veterinarian | “Who triages demand, checks evidence, approves content, handles emergencies, and measures outcomes?” | Expert escalation was a button/service idea rather than an operated system |
| Cooperative/buyer | “Price cards do not aggregate quantity, quality, collection, storage, or commitments.” | Market access was reduced to information rather than coordination |
| Investor | “Who pays, how is distribution acquired, and what repeats outside one subsidized pilot?” | The platform vision had no validated commercial engine |
| Product designer | “Five tabs and five Ask modes expose the architecture instead of the farmer’s immediate job.” | Progressive disclosure was stated but not consistently applied |
| Developer | “Why build event sourcing, custom sync, pack operations, and a platform domain before one production workflow?” | Engineering scope exceeded validated product scope |

# Section 3 — Everything Version 2 Completely Missed

## Missing product and domain opportunities

| Missed domain | Why it matters | Decision now | Credible first use | Main reason not to overbuild |
|---|---|---|---|---|
| Livestock health/production | Mixed farming is common; goats, poultry, cattle, and buffalo have major household presence | Include in value-chain selection | Vet/agent case, vaccination/reminder, mortality/production event | Species/disease/content operations differ from crops |
| Farmer-group/cooperative operations | Groups aggregate demand, production, market access, training, and bargaining power | Core to strategy | Member/cycle roster, visit/case queue, harvest intent | Power imbalance and data stewardship |
| Field-agent workflow | Agents may be the real interface for low-literacy/offline users | Build in first pilot | Enroll, visit, capture evidence, assign action, follow up offline | Agent burden and falsified/completed-for-user data |
| Operations console | Expert capacity and program outcomes require queue/campaign visibility | Build minimally in first pilot | Triage cases, publish advisory, monitor follow-up | Enterprise scope creep |
| Knowledge/model operations studio | Reviewed content and AI cannot be managed in source code alone | Build before automated advice | Author/review/version/localize/publish, evaluation cases | Workflow complexity; keep crop/value-chain scoped |
| IVR/outbound voice/SMS | Smartphone apps exclude some farmers and are not always the strongest alert channel | Pilot with partner | Missed-call callback, advisory playback, reply/agent request | Telecom cost, consent, delivery reliability |
| Supply aggregation | Income depends on coordinated volume, timing, quality, and buyers | High-value candidate | Harvest intent, expected quantity, collection slot | Requires real buyer/logistics operator |
| Post-harvest handling | Storage, grading, transport, and loss may dominate economic outcome | Select by value chain | Harvest checklist, lot/quality, cold-room/collection booking | Physical infrastructure outside software |
| Traceability | High-value/certified buyers may pay for lot history | Later within qualifying vertical | Batch/lot, producer, input/action evidence, chain of custody | Data integrity and audit cost |
| Group input procurement | Lower prices/authentic inputs may beat a generic expense tracker | Candidate early loop | Demand aggregation, approved catalog, distribution receipt | Commerce conflict and supplier verification |
| Input authenticity/safety | Counterfeit/wrong inputs affect yield and safety | Partner-dependent | Scan/lot lookup and report problem | No reliable catalog/source means false assurance |
| Financial planning/cash flow | Timing of input cost, labor, credit, and sale drives decisions | Add after transaction capture | Cycle budget and committed/actual cash flow | Manual data completeness and lending harm |
| Credit/insurance readiness | Existing subsidy/insurance programs may require records | Partner/government pilot only | Purpose-bound application readiness and document pack | Exclusion, adverse decisions, consent, regulatory risk |
| Buyer/logistics coordination | Price information alone does not move produce | Core in market-led vertical | Buyer commitment, collection point/time, quantity, acceptance | Must not promise demand that is not contracted |
| Community requests/offers | Labor, equipment, transport, and knowledge are social/group resources | Structured pilot, not open feed | Request sprayer/transport/help within verified group | Moderation, favoritism, safety, fraud |
| Equipment sharing | Small plots make individual machinery ownership inefficient | Partner-dependent | Availability/booking/receipt within a group | Maintenance, liability, scheduling operations |
| Climate hazard preparedness | Flood, drought, heat, landslide, disease shifts, and water risks exceed “weather” | Early partner capability | Targeted alert + preparation/recovery checklist + confirmation | Local precision and alert fatigue |
| Climate-resilient practice | Actionable adaptation may create more value than forecast display | Knowledge/program layer | Partner-approved variety, water, soil, shelter, contingency plan | Recommendations are agroecology-specific |
| Disaster loss assessment | After hazard, evidence affects support/insurance/program response | Later institutional workflow | Time/location/media loss record and verified visit | Fraud, trauma, legal/insurance standards |
| Satellite anomaly screening | At group/regional scale it can prioritize field visits | Later pilot, not farmer diagnosis | Plot/catchment anomaly queue for agents | Sentinel-2 has 10–20m pixels; small irregular plots/clouds limit field-level inference |
| Shared infrastructure sensors | Irrigation canals, greenhouses, milk/cold rooms may justify sensors | Partner pilot | Alert on shared water/storage temperature condition | Hardware maintenance/connectivity/ownership |
| Individual precision sensors | Potential value for high-value protected cultivation | Do not generalize | Paid greenhouse/orchard pilot | Cost and support are disproportionate for typical 0.4ha holdings |
| Predictive outbreak analytics | Aggregated cases can reveal regional pest/disease signals | Build only after case volume | De-identified cluster alert for experts/agents | Sampling bias, false alarm, privacy |
| AI expert copilot | Increases scarce human throughput while retaining accountability | Build before farmer diagnosis | Case summary, missing evidence, KB retrieval, translation, similar cases | Automation bias; expert must verify |
| Quality grading AI | Buyer acceptance and price may be a strong visual use case | Evaluate per commodity | Standardized image + human-reviewed grade | Lighting/device/buyer standard variation |
| Government service integration | Subsidy, insurance, advisories, local programs may drive adoption | Partner-specific | Verified scheme/advisory with eligibility/contact and deadline | API freshness, politics, identity burden |
| Carbon credits/MRV | Could fund resilient practices, but requires rigorous measurement and additionality | Do not build as general feature | Only as funded project module with accredited operator | Current Verra methods require baselines, monitoring/modeling and sometimes soil measurement; transaction cost is high |
| Data portability/interoperability standard | Partner-led products risk lock-in | Design from pilot | Export program records and documented API schema | Premature universal ontology |
| Support and grievance workflow | Incorrect advice/data/partner conduct needs redress | Build from first pilot | Call/agent complaint, case linkage, response SLA | Operational staffing |
| Partner governance/anti-coercion | Institutional distribution can become surveillance or mandatory sharing | Non-negotiable | Clear benefit, voluntary consent, role audit, exit/export | Without enforcement, consent is theater |

### Evidence-led decisions on requested frontier features

#### Satellite imagery

Use later for cooperative/agent prioritization, hazard mapping, crop-area estimation, or anomaly screening—not leaf diagnosis or precise prescriptions. ESA lists Sentinel-2’s relevant bands at 10m and 20m resolution with about five-day revisit. A 0.4-hectare square is only about 63m across, so a simple 10m grid covers roughly six pixels per side before boundary mixing; Nepal’s fragmented/irregular plots, topography, and cloud further reduce certainty. This calculation is an inference from official land-size and mission specifications. [ESA Sentinel-2 facts](https://www.esa.int/Applications/Observing_the_Earth/Copernicus/Sentinel-2/Facts_and_figures), [Nepal Living Standards Survey IV](https://data.nsonepal.gov.np/dataset/b6c3c19b-4b15-44bf-8653-1571e76dad14/resource/e2d52301-1c25-498b-8732-4326c62a2372/download/nlss-iv.pdf)

#### Sensors and precision agriculture

Do not reject them categorically. FAO/UNDP guidance recognizes remote sensing, IoT, AI, and mobile potential for smallholders while also highlighting infrastructure, literacy, technical feasibility, business model, and scaling barriers. Prioritize shared assets or high-value controlled environments where one operator maintains the hardware. [FAO precision agriculture overview](https://www.fao.org/family-farming/detail/en/c/1738176/)

#### Carbon credits

Do not add a “carbon” dashboard or promise credits. Verra’s current agricultural land-management methodology requires project eligibility, additionality, quantification, uncertainty controls, and specified soil-carbon measurement approaches. KrishiDoc may later collect activity evidence for a funded accredited program, but it should not become the project proponent or verifier by default. [Verra VM0042 v2.2](https://verra.org/methodologies/vm0042-improved-agricultural-land-management-v2-2/)

#### Climate resilience

Promote it earlier than Version 2 did. World Bank analysis identifies river flooding, heat, drought, landslides, and other hazards affecting Nepalese households and livelihoods; other Nepal work shows irrigation reliability and group-level infrastructure matter. The product response should be partner-targeted preparedness, resilient practice, and recovery workflows, not another generic forecast tile. [World Bank Nepal climate risk](https://documents.worldbank.org/en/publication/documents-reports/documentdetail/099062323152517268), [Nepal irrigation outcomes](https://www.worldbank.org/en/results/2019/05/22/nepal-modernizing-irrigation-system-for-economic-growth-and-poverty-reduction)

#### Voice/IVR and channel strategy

Version 2 treated voice mainly as an in-app input/accessibility layer. FAO material documents SMS, USSD, IVR, and outbound voice as distinct delivery channels for low-literacy and weak-internet contexts. The work queue and advisory system should be channel-agnostic. [FAO data-driven advisory](https://www.fao.org/investment-centre/latest/news/detail/Data-driven-advisory-services-key-for-Africa%E2%80%99s-agricultural-development/en), [FAO IVR evidence](https://www.fao.org/family-farming/detail/en/c/1734718/)

# Section 4 — Revised Recommendations

## Major decision alternatives

Every major Version 2 recommendation is forced through at least three alternatives below.

### 1. Product strategy

**Previous:** phased hybrid smallholder OS.

| Alternative | Description | Strength | Failure mode |
|---|---|---|---|
| A. Direct farmer utility | Offline handbook, records, weather, diagnosis | Simple organization and broad access | Distribution, trust, retention, payer unresolved |
| B. AI advisory service | Photo/voice triage plus experts | Clear high-stress job and dataset loop | Episodic, liability-heavy, expensive human capacity |
| C. Partner-led value-chain network | Farmer + agent + operator + expert surfaces around one crop/livestock outcome | Solves distribution, payer, service and data together | Partner dependency and enterprise capture |
| D. Generic platform/API | Infrastructure for other agriculture apps | Avoids farmer UX burden | No current customers/data/platform credibility |

**Decision:** C. It provides the best path to observable economic outcomes and repeatable operations. Preserve A as a guest/local access mode and B as one capability.

### 2. Initial customer and distribution

**Previous:** undefined smallholder plus optional institution.

| Alternative | Model | Decision test |
|---|---|---|
| A. App-store D2C | Farmer discovers and self-onboards | Affordable acquisition and repeated self-service value |
| B. Cooperative/extension B2B2C | Partner enrolls and operates service | Partner commitment, trusted reach, staff capacity, aligned benefit |
| C. Agribusiness contract farming | Buyer/input firm funds production coordination | Clear economics but strict advice/commerce separation |
| D. Government program | Public service integration | Scale potential; procurement/data/political risk |

**Decision:** run B and one carefully governed C/D candidate through discovery. Do not choose D2C without acquisition evidence.

### 3. Initial value proposition

**Previous:** decide, record, and act across the season.

| Alternative | Outcome | Best fit |
|---|---|---|
| A. Reduce preventable crop/livestock loss | Faster expert triage and follow-up | Disease-heavy value chain with expert capacity |
| B. Improve marketable volume/quality | Plan, grade, aggregate, collect, buyer link | Organized commercial vegetable/fruit/seed/dairy groups |
| C. Reduce input/work cost | Group procurement, task coordination, equipment | Strong cooperative operations |
| D. Improve climate readiness | Targeted preparation, water, resilient practice, recovery | Hazard-exposed program/municipality |

**Decision:** do not preselect in the report. Score real partner opportunities; choose exactly one primary outcome and one secondary safety outcome.

### 4. Farmer navigation

**Previous:** Today / Farm / Ask / Records / Services.

| Alternative | Structure | Tradeoff |
|---|---|---|
| A. Work / Ask / Records | Three stable jobs, program context implicit | Best pilot simplicity; fewer browsing destinations |
| B. Home / Farm / Services | Familiar portal model | Risks module clutter |
| C. Conversation-first | One photo/voice/text entry | Low chrome but poor scan/revisit |
| D. Partner-configured tabs | Per-program modules | Relearning and support fragmentation |

**Decision:** A. Use contextual links for farm/market/service. Add a destination only when repeated tasks prove it deserves permanence.

### 5. Farmer record model

**Previous:** household/farm/plot/crop-cycle event ledger.

| Alternative | Model | Tradeoff |
|---|---|---|
| A. Full event sourcing | Immutable events and projections | Audit-rich, high complexity |
| B. Conventional domain tables + audit log | Mutable operational state plus append-only sensitive action history | Clear CRUD/query/deletion, adequate audit |
| C. Document/case model | Flexible JSON forms per partner workflow | Fast pilot, weak interoperability/query |

**Decision:** B with limited versioned JSON extensions for partner-specific forms. Generalize production units beyond crops.

### 6. Offline and sync

**Previous:** custom UUIDv7 outbox, push/pull, aggregate conflict rules.

| Alternative | Approach | Tradeoff |
|---|---|---|
| A. Custom sync engine | Maximum domain control | Highest engineering/test burden |
| B. Managed local-first service | Faster delivery | Vendor limits, cost, FastAPI/Drift fit unknown |
| C. Program-scoped store-and-forward | Local queue, batch submit/receipt, minimal editing conflicts | Narrow but sufficient for case/visit pilot |

**Decision:** C for concierge/pilot. Run a time-boxed A/B technical spike before cross-device collaborative records.

### 7. AI deployment

**Previous:** bounded farmer-facing Crop Doctor in Beta.

| Alternative | AI role | Risk/value |
|---|---|---|
| A. Farmer diagnosis | Direct result | Highest safety and calibration burden |
| B. Expert copilot | Summarize, retrieve, translate, request missing evidence, find similar cases | Human accountability and data flywheel |
| C. Operational intelligence | Cluster cases, flag outbreaks/overdue work, data quality | High partner value; sampling/bias risk |
| D. No AI | Human/content service only | Safe baseline; capacity constraint |

**Decision:** B + limited C after evaluation. A remains an experiment until it outperforms/augments service on approved cases without equity/safety regression.

### 8. Human expertise

**Previous:** farmer requests expert from Ask/result.

| Alternative | Service | Tradeoff |
|---|---|---|
| A. On-demand direct marketplace | Farmer chooses expert | Discovery/quality/capacity/payment complexity |
| B. Partner triage queue | Agent/operator routes to assigned experts | Controlled SLA and context, partner dependence |
| C. Scheduled group clinic | Cases batched into visits/calls | Efficient, slower individual response |
| D. Referral directory only | Contact information | Low operations, weak resolution tracking |

**Decision:** B with C for common issues and D as fallback. Publish scope and response time; do not promise 24/7 care.

### 9. Voice and channel

**Previous:** in-app voice with transcript plus human audio packs.

| Alternative | Channel | Best use |
|---|---|---|
| A. In-app voice note | Rich asynchronous case evidence | Smartphone users and agent-assisted capture |
| B. IVR/outbound voice | Alerts, short guidance, escalation request | Low literacy/basic phone/weak internet |
| C. SMS/USSD | Short confirmations, codes, simple structured responses | Coverage and low data, literacy dependent |
| D. Human agent call | Complex/high-risk communication | Expensive but accountable |

**Decision:** channel mix by partner segment. Work/advisory state is backend-domain data, not app-only state.

### 10. Weather and climate

**Previous:** cached farm weather and action cards in MVP.

| Alternative | Product | Decision |
|---|---|---|
| A. Generic forecast | Easy, low differentiation | Reject as lead |
| B. Partner-authored action advisory using forecast/hazard data | Contextual and accountable | Choose for early pilot if provider/partner passes |
| C. On-farm station/sensor | Local precision | Only high-value/shared-asset pilot |
| D. Climate preparedness/recovery plan | Broader resilience | Include where hazard is primary outcome |

**Decision:** B or D per value chain; source/freshness/uncertainty always visible.

### 11. Market and commerce

**Previous:** quotes in Services, transactions later.

| Alternative | Workflow | Value |
|---|---|---|
| A. Price board | Information only | Weak if farmer cannot access buyer/logistics |
| B. Group harvest aggregation | Quantity/time/quality/collection/buyer | Strong partner outcome |
| C. Open marketplace | Discovery and transaction | Liquidity, fraud, dispute, logistics burden |
| D. Input procurement | Aggregate demand and distribute verified inputs | Savings/authenticity; conflict risk |

**Decision:** B or D inside a closed verified program. Defer C. Use A only as supporting context.

### 12. Backend topology

**Previous:** FastAPI modular monolith + PostgreSQL/Redis/object store/worker/CDN.

| Alternative | Topology | Fit |
|---|---|---|
| A. Postgres + object storage + worker | Minimal durable service | Selected pilot/launch base |
| B. Full proposed topology | Stronger scale/pack distribution | Add components from measured need |
| C. Managed backend platform | Faster auth/sync/storage | Evaluate vendor fit and exit risk |

**Decision:** A; preserve ports so B/C remain possible. Redis and dedicated CDN are not milestones.

### 13. Revenue model

**Previous:** free core + Farmer Plus + institution + expert + partner/API + transactions.

| Alternative | Primary payer | Risk |
|---|---|---|
| A. Farmer subscription | Clear user/customer alignment | Affordability and weak willingness-to-pay |
| B. Cooperative/NGO/government license | Distribution and service funding | Procurement cycles and surveillance risk |
| C. Agribusiness/value-chain contract | Strong ROI link | Advice/commerce conflict and farmer bargaining |
| D. Transaction fee | Outcome-linked | Requires liquidity/logistics/disputes |

**Decision:** B as initial hypothesis, with governed C pilot. Do not build billing tiers before partner unit economics are observed.

### 14. Satellite/sensor strategy

**Previous:** one optional later precision capability.

| Alternative | Use | Decision |
|---|---|---|
| A. Individual field recommendations | Farmer-facing precision | Reject without plot/ground validation |
| B. Agent anomaly/visit prioritization | Regional/portfolio screening | Pilot after mapped plots and case history |
| C. Shared infrastructure monitoring | Irrigation/cold-chain/greenhouse | Pilot where partner maintains asset |
| D. No precision layer | Manual/agent evidence | Default until value/cost proven |

**Decision:** D initially; B/C are separate evidence-gated products.

### 15. Roadmap logic

**Previous:** MVP → Beta → Public Launch → V2 → V3 by time and feature accumulation.

| Alternative | Logic | Tradeoff |
|---|---|---|
| A. Feature maturity stages | Familiar, easy to communicate | Hides market/service uncertainty |
| B. Evidence gates | Partner thesis → concierge → repeat → productize → expand | Selected; forces distribution/economics proof |
| C. Technology milestones | Backend/AI/platform first | Engineering-led and high waste risk |

**Decision:** B. “Public launch” occurs only after the same value chain succeeds with a second operator/cohort.

## Revised strategic statement

> **KrishiDoc should help a trusted local agriculture organization coordinate one production outcome with farmers—from work and questions to evidence, follow-up, and market/service completion—across app, agent, and voice channels.**

The long-term platform emerges from repeatable value-chain capabilities. It is not predeclared as an OS.

## Explicit challenge to the narrow crop-help strategy

A narrow Crop Doctor would be the right company strategy only if all of these were true: crop incidents are frequent enough to retain users; image/short-context triage resolves a high share safely; farmers or sponsors pay per resolution; distribution is affordable; expert escalation capacity is sustainable; and the resulting data creates defensible improvement.

The current evidence does not establish any of those conditions. It instead shows mixed crop–livestock livelihoods, small fragmented holdings, institutional/extension actors, climate and water risks, and market outcomes that depend on coordination and physical services. A narrow crop-help core also leaves the payer and post-advice action unresolved.

**The attempted proof succeeds:** narrow Crop Doctor is the wrong default company strategy. It remains a valid workflow inside a partner-led value-chain service, especially where preventable crop loss is the chosen outcome. If Gate 0 later proves the narrow conditions above for one segment, the board should permit a focused spinout or wedge—but not assume it now.

# Section 5 — New Priorities

## Priority order

| Rank | Priority | Why it precedes Version 2 work | Exit evidence |
|---:|---|---|---|
| 1 | Select partner, value chain, geography, payer, and primary outcome | Without this, “farm OS” requirements are guesses | Signed design-partner agreement, operator, target cohort, baseline, data/service scope, funding path |
| 2 | Repair release integrity | Existing app cannot be safely distributed for a pilot | Signing/startup/media/no-op/sample gates pass on device |
| 3 | Map the real service blueprint | App, agent, expert, group, buyer, provider, and grievance work must be one system | Current/future blueprint, capacity/cost, escalation and failure ownership |
| 4 | Build concierge case/work loop | Proves outcome before automation/platform | Farmer/agent submits; operator resolves; action/follow-up captured; outcome measurable |
| 5 | Build field-agent offline workflow | Distribution and low-literacy access may depend on it | Enrollment/visit/case/follow-up work through offline queue |
| 6 | Build minimal operations/knowledge console | Experts/content need tools before farmer AI | Queue, assignments, SLA, reviewed response, advisory publish, audit |
| 7 | Add farmer companion for repeated self-service jobs | Productize only jobs farmers actually repeat | Observed independent use reduces agent/operator burden without worse outcomes |
| 8 | Add expert copilot and operational AI | Increase capacity using labeled service data | Time/quality improvement with no safety/equity regression |
| 9 | Productize one market/climate/production workflow | Economic or resilience outcome drives retention | Partner-level outcome and sustainable operations |
| 10 | Repeat with second partner/cohort | Tests whether this is product, not custom project | Majority of capability reused; onboarding/support cost improves |
| 11 | Standardize capabilities, sync, and APIs | Platform abstraction becomes evidence-based | Two implementations share contract and data model |
| 12 | Consider farmer diagnosis, satellite, sensors, finance, marketplace | High-risk/complex layers now have data/distribution | Separate business, safety, and technical gates pass |

## Completely rebuilt roadmap

### Gate 0 — Thesis selection (weeks 0–8)

**Purpose:** decide what business and outcome KrishiDoc is actually building.

- Compare at least three Nepal value-chain candidates, including one livestock candidate and one high-value crop candidate.
- Interview/observe farmers, field agents, cooperative leaders, experts/vets, buyers, local government/program staff, and input/logistics actors.
- Map current channels, response times, record burden, loss/cost, market path, phone/device use, language, gender/decision roles, and existing workarounds.
- Run nonsoftware concierge tests: expert callback, group advisory, harvest intent, or agent follow-up.
- Estimate service capacity and payer economics before architecture expansion.

**Go:** one partner commits staff/cohort/data scope and a funded or credible payer path; one primary outcome is frequent/costly enough; digital/agent intervention has an observable mechanism.  
**No-go/pivot:** the app merely duplicates trusted channels, no operator owns follow-up, benefit is too small, or required data/provider access is unavailable.

### Gate 1 — Concierge operations pilot (months 3–5)

**Purpose:** prove the complete service manually with minimal product.

- Harden existing Flutter language, capture, notebook, and result-state foundations.
- Farmer path: Work / Ask / Records, or agent-assisted equivalent.
- Agent path: enroll participant/production unit, capture case/visit, assign action, follow up offline.
- Operator console: triage, assign expert, issue reviewed response, publish targeted advisory, export outcomes.
- Use human experts; AI runs only in shadow for quality/summarization experiments.
- Choose one workflow: e.g., vegetable crop-health resolution plus follow-up, goat health/vaccination service, or harvest aggregation/collection.

**Cohort:** operationally large enough to expose service behavior—typically 100–300 participants across multiple groups—while qualitative usability cohorts remain smaller and deeper. Exact sample is powered after baseline.  
**Exit:** target problem resolution/economic mechanism improves against baseline or credible comparison; participants/agents actually use the loop; operator SLA/cost is measured; severe safety/privacy failures are closed.

### Gate 2 — Digitized vertical product (months 6–10)

**Purpose:** automate repeated work, not speculative modules.

- Durable PostgreSQL/object storage, minimal batch sync, program enrollment/recovery, consent/audit, media retention.
- Productize work templates, cases, follow-up, advisories, IVR/SMS/app channel projection, and partner reporting.
- Add the vertical-specific economic/resilience workflow: aggregation, input distribution, vaccination, hazard preparedness, or quality/collection.
- Build expert copilot for case summary, missing evidence, reviewed retrieval, translation, and duplicate clustering under shadow/approval.
- Establish support, grievance, incident, content-release, and partner-governance processes.

**Exit:** service quality is maintained while operator time/cost improves; offline/channel reliability passes; AI copilot helps without increased error; partner will renew/expand; farmer data rights are exercised successfully.

### Gate 3 — Repeatability test (months 11–16)

**Purpose:** prove the product can repeat beyond one custom program.

- Launch the same value chain with a second partner, district, or operator.
- Measure what configuration vs custom code is required.
- Standardize only reused concepts: participant, production unit/cycle, work, case, advisory, evidence, transaction/lot if relevant, audit, capability.
- Add managed/custom sync decision based on actual conflict and collaboration patterns.
- Validate business model, onboarding cost, training, content localization, support and provider SLAs.

**Exit:** most core workflow/code/content operations are reused; second deployment reaches target outcomes faster/cheaper; no unacceptable equity or partner-power issue. This is the earliest credible “public launch” decision.

### Gate 4 — Adjacent capability expansion (months 17–30)

**Purpose:** increase value within the proven network.

Candidate capabilities are selected by observed bottleneck:

- Group input procurement/authenticity.
- Harvest aggregation, grading, collection, buyer commitments.
- Seasonal cash flow and settlement.
- Climate preparedness/water/recovery.
- Livestock/crop adjacency.
- Government scheme/insurance documentation.
- Structured community labor/equipment/service requests.

**Exit:** each capability has an operator, payer, outcome, source/SLO, conflict policy, adoption, and shutdown/export path. Remove underused or operationally unsustainable capabilities.

### Gate 5 — Network intelligence and platform (months 24–48+)

**Purpose:** offer scalable capabilities proven by multiple deployments.

- Partner APIs/sandbox and portable program data.
- Outbreak/anomaly intelligence with bias/coverage controls.
- Farmer-facing automated assessments only for validated strata.
- Satellite agent prioritization and shared sensor integrations where ground truth/business case passes.
- Traceability for qualifying high-value buyers.
- Finance/insurance referral only with regulatory, fairness, consent, and redress controls.
- Carbon/MRV only as an accredited program integration.

**Exit:** independent impact, privacy/fairness and security review; partner removal without farmer data loss; sustainable diversified revenue; outcome gains exceed surveillance/exclusion/complexity harms.

## New decision metrics

Do not set universal thresholds before baseline. Every pilot pre-registers definitions, cohort, season/time window, comparison, expected mechanism, and stop rules.

| Layer | Required measures |
|---|---|
| Farmer | Problem resolved, preventable loss, marketable output, time/cost, comprehension, record/service usefulness, grievance resolution |
| Agent | Visit/case time, completion quality, offline queue age, rework, workload, training burden |
| Expert/operator | Cases per hour, missing evidence, response time, agreement/overturn, content cost, escalation, incident |
| Partner | Member reach, production/quality/aggregation, renewal willingness, staff cost, data-quality and governance compliance |
| Equity | Outcomes by gender, literacy, language, geography, device/channel, farm type, program status |
| Product | Independent vs assisted completion, repeat useful workflow, abandonment/recovery, channel delivery, export/deletion |
| Technical | Crash/startup/camera baseline, sync integrity, media/storage/data/battery, security and pack validity |
| Business | Acquisition/enrollment cost, service cost per resolved outcome, payer value, renewal, partner concentration |

# Section 6 — What Should Actually Be Built

## Product: KrishiDoc Network pilot

### Surface 1 — Farmer Field Companion

Keep the Flutter app, but make the first pilot deliberately small.

**Primary navigation:**

1. **Work** — assigned actions, targeted advisories, appointment/collection window, complete/cannot-do/request-help.
2. **Ask** — one “show or tell us” intake; evidence prompts adapt to the program/case; status and reply remain visible.
3. **Records** — farmer-understandable observations, advice, completed work, receipts/transactions relevant to the selected outcome.

**Cross-cutting:** language/audio, offline/queued/sent state, program/contact, data/share/export, grievance. Farm/production-unit context appears in the header and selectors; it is not a navigation destination until multiple units make that valuable.

**Do not build initially:** generic dashboard, open marketplace, global social feed, full expense ledger, five-tab Services drawer, satellite map, sensor dashboard, carbon score, autonomous diagnosis, or universal farm profile.

### Surface 2 — Field Agent workflow

This may be a role within the Flutter application initially, with strict authorization and a different shell.

- Program roster and assigned visits.
- Participant and production-unit enrollment with purpose-bound fields.
- Offline visit checklist and evidence capture.
- Case creation/triage, action explanation, farmer confirmation.
- Follow-up/outcome and grievance capture.
- Queue state, sync recovery, duplicate detection, supervisor escalation.
- Clear declaration when the agent—not the farmer—entered data.

### Surface 3 — Operations and Expert Console

A web surface designed for queues and batch work, not a stretched mobile design.

- Program/cohort configuration and role access.
- Case queue by urgency, age, crop/species, geography, missing evidence, assignment.
- Expert response composed from versioned reviewed knowledge; source and constraints required.
- Advisory campaign by verified cohort with expiry, channel, delivery status, and opt-out.
- Work/visit/collection planning relevant to the pilot.
- Outcome, SLA, workload, unresolved safety, data quality and grievance dashboards.
- Audit trail, consent scope, export/deletion workflow.

### Surface 4 — Knowledge and AI Studio

- Condition/problem/action content authoring with crop/species, stage, geography, hazard, contraindication, source, review, expiry.
- English/Nepali/Hindi and local-term glossary; audio/TTS policy per item.
- Structured evidence checklist and triage protocol.
- Case annotation, expert disagreement, evaluation cohort, model/content/policy version.
- Pack publish/sign/rollback/revoke only when offline distribution is used.
- Shadow AI evaluation and approval workflow.

## Initial domain model

Use conventional relational entities plus audit history:

```text
Organization / Program
  ├── Participant + consent/contact/channel preferences
  ├── ProductionUnit (plot | herd | flock | pond | orchard | facility | other)
  │     └── ProductionCycle
  ├── WorkItem / Completion
  ├── Observation + MediaAsset
  ├── Case + Evidence + ExpertResponse + FollowUp
  ├── Advisory + CohortDelivery
  ├── TransactionOrLot (only when pilot needs it)
  ├── Grievance / Resolution
  └── AuditEntry
```

Farmer-created records can be corrected/deleted subject to transparent policy. Expert responses, consent, partner access, and regulated transactions retain audit history. This is simpler and more legally adaptable than making every state an immutable farm event.

## Initial architecture

### Keep

- Flutter Android client.
- Drift local database and background SQLite access.
- Riverpod with query/command conventions.
- GoRouter.
- Existing `core_domain`, `core_data`, `capture`, `inference`, and `design_system` packages until an actual boundary demands extraction.
- FastAPI application factory, typed errors, request IDs, idempotency concepts.

### Change first

- Start `runApp` before fallible store initialization and render a recovery shell.
- Remove sample/debug/no-op reachability and release debug signing.
- Repair media ownership and cleanup.
- Add vertical folders `work`, `cases`, `records`, `program`, and `sync` inside the app rather than a package explosion.
- Replace in-memory backend repositories with PostgreSQL.
- Add object storage for consented media and one background worker.
- Add program/role/consent authorization and an operations console API.
- Implement minimal local outbox/batch receipt for visits/cases; defer collaborative generic sync.
- Add security/retention/export/deletion/grievance tests.

### AI build order

1. Photo/evidence quality checks and missing-evidence prompts.
2. Expert case summarization with source-linked reviewed retrieval.
3. Translation/transcription assistance with visible original and correction.
4. Similar-case retrieval and duplicate/outbreak clustering for operators.
5. Quality grading or bounded assessment experiments specific to the chosen value chain.
6. Farmer-facing automated assessment only after powered validation, comprehension, monitoring, fallback, and service economics pass.

## Feature decisions requested by the adversarial brief

| Feature | Build now? | Actual decision |
|---|---|---|
| AI | Yes, limited | Expert copilot/shadow quality and operational intelligence first |
| Satellite imagery | No initial build | Later agent/cooperative anomaly pilot with mapped units and ground validation |
| Sensors | No general build | Shared-infrastructure or high-value protected-production pilot only |
| Precision agriculture | Not as a module | Evidence-gated capability for a specific value chain and operator |
| Livestock | Candidate/core model | Include at least one livestock value chain in Gate 0 selection |
| Cooperative farming | Yes | Primary distribution/operations hypothesis |
| Supply chain | Candidate early | Aggregation, collection, quality and buyer coordination may be the primary outcome |
| Traceability | Later/conditional | Build batch/lot only when buyer/certification value pays for integrity work |
| Financial planning | Later within transactions | Derive cash flow from real input/sale/settlement events before manual budgeting |
| Predictive analytics | Later | Expert/operator outbreak and workload signals before farmer predictions |
| Marketplace | Closed pilot only | Verified group procurement or buyer coordination; no open market |
| Community | Structured group workflows | Requests/offers/clinics inside verified programs; no engagement feed |
| Climate resilience | Early where relevant | Hazard preparedness, resilient actions, water/recovery through partner advisories |
| Carbon credits | No general feature | Accredited program integration only after MRV/additionality economics pass |
| Government integration | Partner-specific | Verified program/advisory/scheme/document workflow, not a generic portal |

## Final board decision

Version 2 was not near-optimal. Its safety, accessibility, offline-state, and engineering-quality constraints were strong, but its central OS recommendation was premature and its roadmap was not credible without distribution, payer, operator, and value-chain selection.

**Authorize only Gate 0 and P0 release hardening now.** Do not authorize the farm OS kernel, five-tab redesign, custom sync engine, Farmer Plus billing, farm-level weather, automated Crop Doctor Beta, or 12-month public-launch plan.

The next product decision must be earned by partner and field evidence. If Gate 0 identifies no value chain where KrishiDoc can measurably improve loss, quality, market access, work coordination, or climate readiness with a committed operator and payer, the truthful recommendation is to stop or reposition the project—not to build a broader app.
