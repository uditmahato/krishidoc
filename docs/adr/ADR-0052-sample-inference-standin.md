# ADR-0052: A sample inference stand-in, marked as such for the life of every record it touches

- **Status:** accepted
- **Decision id:** D-52
- **Date:** 2026-08-01
- **Owners:** Eng (with ML and Agri as reviewers when the real pack lands)

## Context

Everything downstream of inference is unbuildable and untestable while nothing
answers the shutter: the result card, the certainty band, the correction path,
the write into History, the escalation route. D-15 puts a quantized LiteRT
interpreter on the device, but the runtime is blocked on a trained `.tflite`
plus labels, which is a content and ML workstream deliverable that does not
exist. Module 11 ended with a capture that produces a byte count, which is
exactly the dead end this rebuild exists to remove.

The owner directed (2026-08-01) that we proceed with sample data and connect the
model later.

The hazard is obvious and it is the same hazard V1 embodied: a confident answer
that is not grounded in anything. V1's finding was decorative confidence (a
1.7:1 yellow badge asserting certainty it had not earned). A stand-in classifier
is that failure mode with a bigger blast radius, because a farmer acting on it
sprays a healthy crop or leaves a diseased one untreated.

## Decision

Ship a `SampleClassifier` in `packages/inference` that hashes the prepared image
bytes and emits logits targeting a probability profile derived from the pack's
own `rejectionFloor`, per-label `threshold` and `minMargin`, so that all three
D-17 states occur by construction. Pair it with `SamplePacks`, whose manifests go
through the real `ModelPack.parse`. Mark every such pack with a `modelVersion`
beginning `sample-`, make `isSamplePack` the single predicate the UI keys off,
and provide `assertNotSample` as a one-line guard for any path that must only
ever run against a real model.

The marker lives in the version string that D-18 already records on every stored
diagnosis, so a record written during the sample period stays identifiable as
sample data permanently, including after real records join it in the same
database.

## Rationale

**Why a stand-in at all, rather than waiting.** Waiting means the five screens
downstream of inference are designed without ever being seen with data flowing
through them, which is how the result card came to have no action and how one
certainty band came to serve every probability. Those defects were found by
review, not by use, and review is the weaker instrument.

**Why deterministic.** A farmer who retakes what is effectively the same
photograph and gets a different disease each time learns that the app guesses.
That lesson cannot be un-taught once the real model lands. Determinism also lets
tests pin exact outcomes rather than sampling a distribution.

**Why specified by the pack rather than by constants.** `ModelPack.calibrate`
computes `softmax(logits / temperature)`, so emitting `temperature * ln(p)`
recovers exactly `p`. That makes the targeting exact rather than approximate,
means the stand-in keeps producing all three states if calibration constants are
retuned, and lets the tests assert that the resolver's own rules agree with the
profile aimed at. A table of magic logits would drift silently the first time a
threshold changed.

**Why the marker is in `modelVersion` rather than a separate flag.** A separate
boolean would have to be plumbed through the domain record, the Drift schema and
the sync op-log, and it would be absent from every record written before it was
added. `modelVersion` is already required, already recorded, and already the
field D-18 says a bad diagnosis is traced through.

**Alternatives considered.**

- *A fixed canned outcome.* Rejected: exercises exactly one of three states, so
  the two states carrying the app's honesty stay unbuilt.
- *A random classifier.* Rejected: non-determinism teaches the farmer that the
  app guesses, and makes tests flaky.
- *A tiny genuinely trained model.* Rejected for this phase: it would be trained
  on a public dataset with no agronomist review and no calibration set, so it
  would be sample data wearing a lab coat, which is strictly worse than sample
  data that admits what it is.
- *Gating the whole flow behind a debug build.* Rejected: the owner needs to see
  and review the flow on a device, and release is the only build that renders
  faithfully. The permanent notice carries the honesty instead.

## Consequences

**Easier.** Every screen downstream of the shutter becomes buildable, testable
and reviewable now. The result card, certainty banding, correction path and
History write can all be designed against real data flow. `SamplePacks` also
exercises `ModelPack.parse`, so the manifest validation is covered by the sample
path rather than only by unit tests.

**Harder, and accepted.** Any surface that renders a diagnosis now carries an
obligation to check `isSamplePack` and show a permanent, non-dismissable notice.
That is a real cost on every such screen and it is the price of the decision.

**Now forbidden.**
- No build may be distributed outside the team while `isSamplePack` is true for
  any wired pack.
- No screen may render a sample diagnosis without the notice. This is a
  reviewable rule, and the intent is that a test enforces it once the result
  screen is wired.
- No treatment or dose bearing content may be shown against a sample result at
  all, notice or not. Advisory content is gated on the knowledge base (D-21) and
  on a real model, not on the flow existing.

**Re-open triggers.** The arrival of a trained `.tflite` with a fitted
calibration set retires the stand-in from the app wiring. `SampleClassifier`
itself stays in the repo as a test double. When that happens, `assertNotSample`
moves into the production wiring path so a regression is a crash rather than a
wrong answer.

## Dissent

The obvious objection is that shipping any fake diagnosis path is precisely what
this rebuild set out to stop, and that the notice is a fig leaf because users
skip notices. Recorded and partly accepted: the notice alone would be a fig leaf,
which is why the decision also forbids distribution outside the team while a
sample pack is wired, and forbids treatment content against a sample result
regardless of the notice. The residual risk is an internal build leaking, which
is judged acceptable against the cost of designing five screens blind.

A second objection, from the same direction: the confidence numbers the
stand-in produces will anchor our expectations, and the real model may be far
worse calibrated. Accepted as a real risk. Mitigation is that the thresholds and
temperature in `SamplePacks` are deliberately ordinary rather than flattering,
and that D-18 already requires recalibration to ship with the model rather than
with the app.
