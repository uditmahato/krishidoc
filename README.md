# KrishiDoc V2

Offline-first plant disease diagnosis and advisory for smallholder farmers in Nepal and India. Flutter client with on-device inference, FastAPI backend, PostgreSQL, curated agronomist-reviewed advisory content, and a citation-constrained chatbot.

**Status:** pre-M0 (foundation). No releasable build yet.

## Branch model

| Branch | Meaning |
|---|---|
| `v2` | V2 trunk (this branch, orphan history). All work lands here via short-lived PR branches. Becomes the default branch at first release. |
| `main`, `dev` | V1, archived read-only for reference. Do not build on them. |

## Where things are decided

The architecture is governed by 51 recorded decisions (D-01..D-51). Nothing here contradicts them without a superseding ADR.

- [docs/adr/ADR-INDEX.md](docs/adr/ADR-INDEX.md): the decision index and ADR process
- [docs/PROJECT_MEMORY.md](docs/PROJECT_MEMORY.md): Living Project Memory (consult before any decision)
- [docs/seams/](docs/seams/): deliberately-not-built future integrations (IoT, plant clinics, marketplace)
- [CONTRIBUTING.md](CONTRIBUTING.md): workflow, commit, and review rules

## Planned repository layout

Monorepo per the implementation plan: `app/` (Flutter farmer app), `portals/` (admin, research; Flutter Web), `packages/` (pure Dart core), `backend/` (FastAPI modular monolith), `inference/` (ONNX serving), `ml/` (training, evals, packs), `content/` (KB and audio pipelines), `infra/` (Terraform, kustomize). Directories appear as their modules are built; empty scaffolding is not committed.

## Security notes

- No secrets in this repository, ever. CI runs secret scanning on every push.
- The V1 Google API key that exists in `main`/`dev` history is treated as compromised and must be rotated in Google Cloud Console regardless of this branch.
