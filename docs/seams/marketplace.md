# Seam: Marketplace (not built; reserved)

**Decision:** D-08, D-21. **Status:** seam only; payments and commerce are out of scope until a superseding ADR.

## What exists now (the seam)

- Advisory content references **active ingredients and abstract product entities, never brands** (also correct agronomy). A future marketplace attaches offers to those stable entity ids without touching the advisory pipeline or its safety review.
- The chemicals registry (jurisdiction-tagged, source-cited) doubles as the future catalog's compliance backbone.

## What is deliberately absent

Product listings, sellers, pricing, payments, logistics, and any monetary flow. No entitlement system is pre-built.

## When it opens

Trigger: a supply-side partner and a regulatory review (agro-input retail licensing differs between Nepal and India). First build steps then: catalog service keyed by existing entity ids; offers rendered adjacent to advice, never inside the reviewed advisory content; jurisdiction filter enforced by the same registry the validator uses (D-46).
