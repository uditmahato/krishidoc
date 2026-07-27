# Living Project Memory

**Protocol:** updated at every major milestone close (minimum); consulted before any new decision; a recorded decision is changed only by an explicit superseding ADR. This repo copy is authoritative as of Module 1.

## Architecture decisions

Registry: [adr/ADR-INDEX.md](adr/ADR-INDEX.md) (D-00..D-51). Full rationale: the design review meeting and external audit documents (delivered 2026-07-27). Per-module ADR files are written before their module's code.

## Open questions

- Numerals and area units for doses (Devanagari vs Latin digits; ropani/kattha/bigha rendering): field test before dose-bearing content ships. Owner: Agri + UX (D-35 action).
- Starter pack regional variants (Nepal hills vs Indian plains crop mix): decide variant strategy during M1 (audit R2-3).
- Final applicationId + trademark check before store submission (audit L-3).
- `uv` not installed on the dev machine; Module 2 decides uv install vs pip/venv for backend tooling.

## Technical debt

- None yet (foundation only; no product code as of Module 1).

## Risks (register: implementation plan §14)

R1 KB editorial throughput (top risk) · R2 low-end device budgets · R3 launch model quality · R4 Flutter Web portal bet · R5 OTP SMS cost/abuse · R6 single-region outage · R7 LLM provider change · R8 Play policy friction · R9 bus factor · R10 adoption/retention.

## TODOs (module ladder within milestones M0..M6)

- [x] Module 1: repo foundation and governance (branch `v2`, docs, hygiene CI) - this commit
- [ ] Module 2: toolchain scaffolds (melos workspace, backend pyproject, full CI wall, pre-commit)
- [ ] Module 3+: per implementation plan milestone order (offline core loop → sync/identity/consent → advisory/content → chatbot/evals → analytics/research → hardening)

## APIs created

- None yet. Conventions fixed by D-27; endpoint inventory in implementation plan §3.

## Database changes

- None yet. Schema blueprint in implementation plan §2; first Alembic migration lands with Module covering identity/sync.

## Breaking changes

- None. /v1 is additive-only once first published (D-09/D-27).

## Milestone log

- 2026-07-27: Phase 5 audit closed (D-44..D-50 adopted, no critical/high open). Phase 6 plan delivered. D-51: V2 on orphan branch `v2` of existing repo. Module 1 committed.
