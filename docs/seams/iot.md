# Seam: IoT integration (not built; reserved)

**Decision:** D-08, D-30. **Status:** seam only; building anything here requires a partner, real hardware, and a superseding ADR.

## What exists now (the seam)

- The versioned event envelope and Pub/Sub topic namespace: sensor streams, when they exist, publish envelopes into `events.iot.*` topics and land in BigQuery like any other event source; no schema migration of the core pipeline is needed.
- Coarse-geo aggregation (D-32) already defines how field-level signals aggregate safely.

## What is deliberately absent

Device registry, provisioning, MQTT broker, firmware/OTA concerns, per-device auth. These are their own product; none of the current design depends on them.

## When it opens

Trigger: a named hardware partner and a pilot plot commitment. First build steps then: MQTT bridge (managed broker) → envelope adapter → topic namespace; device identity modeled alongside `devices` without touching farmer identity.
