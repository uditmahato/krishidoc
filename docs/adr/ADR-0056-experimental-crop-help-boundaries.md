# ADR-0056: Ship useful crop-help surfaces behind explicit evidence boundaries

- **Status:** accepted
- **Decision id:** D-56
- **Date:** 2026-08-04
- **Owners:** Eng (ML, Agri and native-language review gates remain open)
- **Supersedes:** the `minSdk 23` clause of D-14; the D-52 release wiring and calibrated-model re-open condition
- **Amends:** D-15 with a temporary experimental global-float32 exception; D-52 remains binding wherever the sample stand-in is used

## Context

The release app had a camera and a downstream result flow, but release-facing crop help was absent while debug used D-52's deterministic sample. Weather and a farmer's question also had no usable destinations. A genuine public TFLite artifact and public crop references make an honest experimental vertical possible now, but they do not supply Nepal field validation, fitted calibration, a curated treatment knowledge base, a production model registry, a live LLM service or official weather warnings.

The exact model provenance, tensor contract and safety flags are recorded in [`app/assets/models/plant_disease_experimental.metadata.json`](../../app/assets/models/plant_disease_experimental.metadata.json). The pinned MobileNetV2 artifact is 9,061,216 bytes, has 38 PlantVillage-derived outputs and uses a source-controlled label order and RGB/255 preprocessing contract. Its source notebook reports 92.44% validation accuracy on augmented, controlled-background data; KrishiDoc has not independently reproduced that result. Treating its softmax scores as a Nepal-field diagnosis would exceed the evidence.

## Decision

Wire the pinned experimental TFLite model in release builds and retain D-52's sample classifier as the default only in debug/tests. Run the full 38-class output first, then enforce the selected tomato, potato or maize scope without filtering and renormalising probabilities. Refuse a global winner from another crop. Set the pack to `possibleMatchOnly`, persist its `experimental-` model version, and never render a confident diagnosis from it. Inference and photos remain on device.

Ship two separate companion surfaces with equally explicit boundaries:

- a deterministic en/ne/hi offline crop guide, scoped to tomato, potato and maize, that selects structured low-risk actions, prevention, control, escalation and a public NARC reference from visible keywords; it is not generative chat, does not confirm a disease and exposes no pesticide product or dose field; and
- live Open-Meteo current conditions plus a seven-day city forecast using seven manually selected Nepal presets; request no location permission, label stale/cached data, and state that it is neither a field measurement nor an official DHM warning.

Raise Android `minSdk` from 23 to 26 for the selected official TensorFlow Lite Flutter runtime. This supersedes only D-14's platform floor. Keep D-14's low-memory target, D-47's delivery intent, D-15's production destination (validated per-crop int8 packs plus a server second opinion), D-21's curated-treatment authority, and D-22's server RAG destination. The current model, guide and weather surface are an experimental bridge, not evidence that those production decisions are complete.

## Rationale

**Why not keep the sample in release.** A sample can test plumbing but cannot perform the user's requested photo analysis. A pinned neural artifact supplies genuine local inference while an enforced possible-match-only policy prevents the UI from claiming validation it does not have.

**Why not call the model a diagnosis or derive treatment from it.** PlantVillage lab performance does not establish accuracy on Nepal field backgrounds, lighting, crop varieties, mixed symptoms or non-plant images. Calibration is also absent. Model-linked treatment would compound one uncertain output into a potentially costly action.

**Why not advertise generative AI.** No credentialed server, reviewed RAG corpus or D-23 evaluation gate exists. A bounded offline guide is useful during poor connectivity and is auditable, but must be named for what it is. Free-form generation, pesticide selection and dosing remain outside this implementation.

**Why Open-Meteo rather than pretending to have field sensing.** A live city forecast adds planning value without GPS permission or hardware. It does not know a farmer's plot microclimate and cannot replace DHM warnings, so those limits are part of the feature rather than footnotes.

**Why accept API 26.** The integrated official runtime requires it. Maintaining API 23 would require selecting, integrating and validating a different interpreter. That alternative may be reopened with device-distribution evidence; silently claiming API 23 while the shipped runtime cannot support it is not an option.

## Consequences

The release build now has reachable disease scan, crop guide and weather destinations. Model provenance, scope and version are auditable, and a photo does not need to leave the phone for classification.

The trade-offs are material: Android 6 and 7 devices (API 23-25) are excluded; the model adds about 9.1 MB before ABI/runtime overhead; weather depends on network and a third-party provider; the selected weather city persists but forecast data and the assistant session are in-memory only; the assistant understands a bounded symptom vocabulary rather than open conversation; and the classifier has no field evidence sufficient for a diagnosis. The measured arm64 release APK is 36.2 MB. On the Realme RMX3741, cold model load plus first AOT inference took 349 ms. A pinned three-image smoke check matched maize and potato but missed a labelled tomato early-blight image as a pepper class; the crop-scope rule correctly refused that output. These measurements replace, rather than inherit, the pre-model figures in `PROJECT_MEMORY.md` and reinforce the possible-match-only boundary.

Now forbidden:

- calling an experimental output confirmed, confident, Nepal-validated or safe for commercial crop decisions;
- discarding other-crop outputs and renormalising the selected crop into artificial certainty;
- using the offline guide to choose a pesticide, dose, mixture or waiting period;
- describing the guide as live generative AI or NARC-endorsed; or
- presenting Open-Meteo data as plot measurement, DHM warning or a reason by itself to make a high-consequence agronomic decision.

Re-open this ADR when a representative Nepal field set and fitted calibration exist; production per-crop packs and D-18 rollout controls land; D-21 reviewed content and D-22/D-23 server assistant gates are met; official DHM warnings are integrated; or measured device coverage justifies an API-23-compatible inference runtime.

## Dissent

Recorded: shipping an unvalidated research model, even with warnings, can anchor a farmer on the first disease name shown. Accepted only because the decision mode cannot produce confidence, important actions direct the farmer to local confirmation, and the feature is labeled experimental before capture and at every stored/result surface. This remains a field-test risk, not a closed safety claim.

Recorded: raising the API floor conflicts with the original low-end-device strategy. Accepted as an explicit, measurable compatibility loss for this runtime, not as a permanent dismissal of older devices. Distribution evidence can reopen the interpreter choice.
