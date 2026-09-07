# ADR-0061: Promote the V2 application to main

- Status: accepted by explicit repository-owner request
- Date: 2026-09-07
- Supersedes: D-51 branch placement and default-branch policy
- Preserves: model safety, field-validation and PR review requirements

## Context

PR #2 merged the current application, V7 test integration and refreshed README
into `v2`. Legacy `main` has unrelated history, causing GitHub's suggested
comparison to fail and the old homepage README to remain visible. After a
temporary default-branch switch to `v2`, the owner explicitly requested replacing
`main` with the current application.

## Decision

Make `main` the development trunk and GitHub default. Its new tree is the merged
V2 application plus branch-documentation and CI updates. Use a history-preserving
integration commit with both the old `main` tip and prepared V2 tip as parents;
push it as a fast-forward, never a forced rewrite. No legacy application files
are combined into the V2 tree.

Retain old `main` at `codex/legacy-main-before-v2-20260907` and keep `v2` unchanged
as the pre-promotion reference. Future feature PRs target `main`. CI supports
`main` pushes and PRs, retaining its existing `v2` triggers for compatibility.

This changes source-control organization, not release readiness. V7 remains an
opt-in research model, V3 remains the normal default, and all documented model
and security limitations remain. Legacy credentials in old history must still
be treated as compromised and rotated by their owner.
