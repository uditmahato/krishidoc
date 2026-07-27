# Contributing

## Workflow

Trunk-based on `v2`. Branches are short-lived (target ≤ 3 days), squash-merged by PR:

- `feat/<scope>-<slug>`, `fix/<scope>-<slug>`, `infra/<slug>`, `content/<slug>`, `docs/<slug>`
- Emergency: `hotfix/<slug>` from the release tag, cherry-picked back to `v2`
- No long-lived integration branches. V1 died on one; ADR-0000 records the lesson.

## Commits

- Conventional commits (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, `infra:`).
- Authored under the committing engineer's own git identity. No tool or AI attribution trailers of any kind.
- No commented-out code, no `TODO` without an issue id, no secrets (CI secret scan blocks the PR).

## Reviews

- Every PR: one approval and a green required-checks wall.
- Consent, sync-merge, chatbot validator, and pesticide-registry code: two approvals, one from the module owner.
- Every PR states which decisions it touches: `Decisions: D-xx, D-yy` (template enforces the field).
- A change that contradicts a recorded decision must ship a superseding ADR in the same PR, or it does not merge.

## Definition of done

Code, tests at the required tier, docs delta (ADR/runbook/memory if applicable), and budgets green (size, perf, coverage) where wired.
