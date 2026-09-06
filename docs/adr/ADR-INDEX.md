# Architecture Decision Index

Decisions D-01..D-43 were made in the V2 design review meeting; D-44..D-50 in the external audit; D-51 on repo strategy. Full rationale and dissent records live in those two documents (delivered 2026-07-27); this index is the in-repo registry. Process: an individual `ADR-00xx-*.md` file (see TEMPLATE.md) is written from the corresponding D-decision **before the module that implements it is coded**; a decision is changed only by a superseding ADR, never by silent drift.

Status codes: A = accepted; A* = accepted as amended (by the referenced decision); S = superseded entirely.

| D | Title | Status |
|---|-------|--------|
| D-00 | Lesson: V1 died with its real work stranded on an unmerged dev branch; V2 is trunk-based with short-lived branches | A |
| D-01 | 1M users = design ceiling; provision 100k DAU; 10x by configuration only | A |
| D-02 | GKE Autopilot, single regional cluster asia-south1; cluster exotica banned | A |
| D-03 | PostgreSQL = OLTP system of record; BigQuery = analytics; portals never read the primary | A |
| D-04 | Redis ephemeral only; Pub/Sub for durable async; Cloud Tasks for scheduled; Celery rejected | A |
| D-05 | Full offline core loop (capture, diagnose, advise, history); chat degrades to labeled KB search | A |
| D-06 | Languages en/ne/hi with native agronomist review gate; new languages are data, not code | A |
| D-07 | "Hospital integration" = plant clinic referral network; static emergency card for human health | A |
| D-08 | IoT/Marketplace not built; seams: event envelope + active-ingredient/product entities (no brands) | A |
| D-09 | Ten-year regime: boring tech, language cap (Dart/Python/SQL/HCL), ADRs, /v1 additive-only | A |
| D-10 | Local store: SQLite via Drift + FTS5; perf budgets attached | A |
| D-11 | Op-log sync, UUIDv7, idempotent batched push, cursor pull, LWW-per-field, tombstones; no CRDTs | A* (D-44) |
| D-12 | Images: 1024px/q85 derivative, EXIF stripped both ends, research-consent originals WiFi-only | A* (D-45) |
| D-13 | Guest-first device identity; phone OTP via Identity Platform; no passwords; merge by op-log replay | A* (D-48) |
| D-14 | minSdk 23; 1 GB reference device; on-demand evictable packs; 500 MB total footprint | A* (D-47, D-56; API floor now 26) |
| D-15 | Hybrid inference: per-crop int8 LiteRT on device + ONNX server second opinion; versions logged | A* (D-56 experimental exception) |
| D-16 | Remembered crop context (no mandatory picker); live capture quality gate; crop-plausibility gate | A |
| D-17 | Tri-state results (confident / uncertain+top-3 / out-of-scope); calibrated per-class thresholds | A |
| D-18 | Model registry (GCS+PG), staged rollout, delta pack updates, per-version kill switch | A |
| D-19 | Serving: FastAPI + ONNX Runtime + L4 pool; KServe rejected until >3 model families | A |
| D-20 | Retraining flywheel: consented images, named annotators, dataset manifests, promotion by evals | A |
| D-21 | Curated KB is sole treatment truth; jurisdiction-tagged; validity horizons; revocation lists | A |
| D-22 | Chatbot: RAG over KB, server-side, pinned model, canonical Q&A in packs, semantic cache | A* (D-46) |
| D-23 | Prompt registry + per-language eval harness + red-team suite as release gates | A |
| D-24 | Chat sessions server-side, 30-day retention, deletable, exportable | A |
| D-25 | Advice UX: labeled AI turns, chemicals only as KB cards, IPM-first, errors never as chat bubbles | A |
| D-26 | FastAPI modular monolith + separate inference service; recorded split triggers | A |
| D-27 | REST/OpenAPI, generated Dart client, idempotency keys, cursor pagination, typed error envelope | A |
| D-28 | Cloud SQL HA + PgBouncer, Alembic expand-and-contract, partitioned high-churn tables, pgvector | A |
| D-29 | Abuse: App Check advisory mode, per-device token buckets, Cloud Armor, tiered quotas | A |
| D-30 | Events: versioned schemas → Pub/Sub → BigQuery batched; no third-party analytics SDKs | A |
| D-31 | Consent tiers T0/T1/T2; T1 vaulted stable pseudonym; deletion cascades with stated SLA | A* (D-45, D-50) |
| D-32 | Outbreak aggregates: geohash-coarse, k ≥ 20, public 7-day lag | A |
| D-33 | Firebase = FCM/Crashlytics/Remote Config/App Check only; Firebase Auth and Firestore banned | A |
| D-34 | Portals behind IAP + Workspace SSO; 4 roles; immutable audit log | A |
| D-35 | gen-l10n/ARB; domain terms as KB data; Weblate flow with native review; human audio packs | A |
| D-36 | Portals in Flutter Web as falsifiable bet; UX-owned spike exit criteria; thin-over-API | A |
| D-37 | 3 GCP projects, Terraform-only, GH Actions → Artifact Registry → Cloud Deploy, kustomize | A |
| D-38 | SLOs with farmer-visible paging only; packs keep read path alive through API outages | A |
| D-39 | Cost envelope; unit target < $0.06/user-yr; depends structurally on D-15/D-21/D-22 | A* (D-50) |
| D-40 | DR: PITR, cross-region backups, quarterly restore drills, RPO 15 min prioritized | A |
| D-41 | Maintainability regime: dep budgets, quarterly train, contract tests, runbooks, secret scanning | A |
| D-42 | Pure-Dart core packages, CI-enforced no-Flutter imports (framework severability) | A |
| D-43 | Advice-recall ledger: every delivery records content versions; revocation + push can recall | A |
| D-44 | Sync ordering by hybrid logical clocks; consent excluded from merge (server-authoritative CAS) | A |
| D-45 | Consent re-verified server-side at execution time; revocation purges dependent queues | A |
| D-46 | Chatbot safety = structured citation of KB entry ids (deterministic); NER secondary; LLM adapter | A |
| D-47 | Starter pack in install via Play Asset Delivery; 60 MB budget; first-run-offline CI-tested | A |
| D-48 | Account continuity: device-key rebind with cooldown; dormant-account second signal | A |
| D-49 | Content ops workstream: pinned launch scope, partnerships, velocity metric, registry cadence | A |
| D-50 | Audit sweep: op-log compaction, sync admission control, single-region posture, Devanagari FTS, cost | A |
| D-51 | V2 lives on orphan branch `v2` of the existing repo; V1 branches archived read-only; default-branch flip at first release | A |
| D-52 | Sample inference stand-in: deterministic, pack-specified, marked `sample-` in `modelVersion` for the life of every record; no distribution and no treatment content while wired ([ADR-0052](ADR-0052-sample-inference-standin.md)) | A* (D-56; release now uses the experimental model, sample rules remain in debug/tests) |
| D-53 | First run asks for the language off the single existing settings key; order pinned `ne, hi, en` on every device; the device locale is never a hint ([ADR-0053](ADR-0053-first-run-language-choice.md)) | A |
| D-54 | Endonyms are non-translatable ARB keys rendered with their own script metrics, never Dart constants and never the ambient theme ([ADR-0054](ADR-0054-endonyms-as-arb-keys.md)) | A |
| D-55 | The three-card onboarding deck is reduced to one About screen until the flows it would teach are reachable; no first-run completion flag ([ADR-0055](ADR-0055-one-about-screen.md)) | A |
| D-56 | Release uses a pinned possible-match-only experimental model; crop guidance stays bounded/offline, weather stays live/city-level, and the required TFLite runtime raises `minSdk` to 26 ([ADR-0056](ADR-0056-experimental-crop-help-boundaries.md)) | A |
| D-57 | Weather compares tomato, potato and maize against the visible seven-day city forecast using sourced temperature ranges; it never prescribes a crop or hides missing field inputs ([ADR-0057](ADR-0057-seven-day-crop-weather-fit.md)) | A |
| D-58 | Field-model development uses licensed, provenance-tracked, group-isolated data; crop-specific raw-logit int8 packs may replace the experimental model only after field, OOD, calibration, quantization and device gates ([ADR-0058](ADR-0058-field-model-training-and-promotion.md)) | A |
| D-59 | System gallery import and automatic crop suggestions with photo review, manual correction and unchanged disease rejection ([ADR-0059](ADR-0059-gallery-and-crop-suggestions.md)) | A |
| D-60 | Fixed bottom gallery/capture controls, explicit blur-only override, training-compatible potato resize and isolated diagnostic APKs ([ADR-0060](ADR-0060-capture-audit-and-training-resize.md)) | A |
