# Living Project Memory

**Protocol:** updated at every major milestone close (minimum); consulted before any new decision; a recorded decision is changed only by an explicit superseding ADR. This repo copy is authoritative as of Module 1.

## Architecture decisions

Registry: [adr/ADR-INDEX.md](adr/ADR-INDEX.md) (D-00..D-51). Full rationale: the design review meeting and external audit documents (delivered 2026-07-27). Per-module ADR files are written before their module's code.

## Open questions

- Numerals and area units for doses (Devanagari vs Latin digits; ropani/kattha/bigha rendering): field test before dose-bearing content ships. Owner: Agri + UX (D-35 action).
- Starter pack regional variants (Nepal hills vs Indian plains crop mix): decide variant strategy during M1 (audit R2-3).
- Final applicationId + trademark check before store submission (audit L-3).
- RESOLVED (Module 2): `uv` installed via `python -m pip install uv`; backend env managed by `uv sync`, `uv.lock` committed, CI uses `uv sync --frozen`.

## Technical debt

- None yet (foundation only; no product code as of Module 1).

## Risks (register: implementation plan §14)

R1 KB editorial throughput (top risk) · R2 low-end device budgets · R3 launch model quality · R4 Flutter Web portal bet · R5 OTP SMS cost/abuse · R6 single-region outage · R7 LLM provider change · R8 Play policy friction · R9 bus factor · R10 adoption/retention.

## TODOs (module ladder within milestones M0..M6)

- [x] Module 1: repo foundation and governance (branch `v2`, docs, hygiene CI)
- [x] Module 2: toolchain scaffolds. Native pub workspace (melos deferred: first-party workspaces suffice; revisit on multi-package scripting pain). `packages/core_domain` seeded with decision-anchored types (ResultState D-17, ConsentScope D-31, AppLanguage D-06, Jurisdiction D-21) + tests. Backend FastAPI skeleton: app factory, /healthz, D-27 error envelope with input-sanitized validation errors, request-id middleware, JSON logging (D-38). CI wall: dart format/analyze/purity/test + uv ruff/mypy/pytest jobs. Packages appear only with real content (no empty scaffolds): core_data/api_client arrive with their modules.
- [ ] Module 3: Flutter app shell (`app/`): design-system seed with tri-state result components (D-17), navigation skeleton, l10n bootstrap (D-35)
- [ ] Module 4+: per milestone order (offline core loop → sync/identity/consent → advisory/content → chatbot/evals → analytics/research → hardening)

## APIs created

- None yet. Conventions fixed by D-27; endpoint inventory in implementation plan §3.

## Database changes

- None yet. Schema blueprint in implementation plan §2; first Alembic migration lands with Module covering identity/sync.

## Breaking changes

- None. /v1 is additive-only once first published (D-09/D-27).

## Milestone log

- 2026-07-27: Phase 5 audit closed (D-44..D-50 adopted, no critical/high open). Phase 6 plan delivered. D-51: V2 on orphan branch `v2` of existing repo. Module 1 committed.
- 2026-07-27: Module 2 committed. Toolchain deviations recorded: native pub workspaces instead of melos; content-bearing packages only. Local verification: dart analyze clean, 8 Dart tests green; ruff + strict mypy clean, 8 backend tests green at 100% coverage.
