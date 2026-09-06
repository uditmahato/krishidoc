# ADR-0058: Train and promote crop models through field-safety gates

- **Status:** accepted
- **Decision id:** D-58
- **Date:** 2026-09-02
- **Owners:** ML, mobile, product safety and agronomy
- **Amends:** D-15, D-17, D-18 and D-20
- **Does not supersede:** D-56's `possibleMatchOnly` release boundary

## Context

The bundled experimental MobileNetV2 is a genuine 38-class model, but it was
trained on a PlantVillage derivative and emits a closed-set softmax. It cannot
establish that a photograph is a usable leaf, that the selected crop is in the
frame, or that the symptoms belong to a covered class. It is also uncalibrated
for Nepal field photographs. A public validation score cannot close those
gaps.

The development laptop can fine-tune modern mobile backbones with CUDA, and
several public CC BY 4.0 field datasets are available. None is a substitute for
a locked, pathologist-reviewed Nepal field test. Some repositories also contain
pre-augmented copies, repackaged lab images, vague condition names, or scraped
images whose source rights are difficult to verify.

## Decision

Build three crop-specific, single-pass student models for tomato, potato and
maize. The default student is MobileNetV3-Large at 224 pixels; EfficientNet-B0
is the first challenger. Each model shares one backbone and emits **raw logits**
for two heads:

1. validity: usable target leaf, unsuitable target-crop view, wrong-crop leaf,
   other plant, or non-plant;
2. condition: only the reviewed, stable keys already represented in the app's
   crop taxonomy.

Uncovered symptoms, mixed conditions, nutrient stress and unsupported pests
are out-of-distribution cases. They train or evaluate abstention; they are not
silently mapped to the nearest disease. Known-label condition cross entropy
applies only to reviewed usable target-leaf examples. An opt-in, separately
weighted `KL(uniform || condition prediction)` objective may additionally use
usable examples explicitly labelled `<crop>_other_unknown`; it is disabled by
default and never applies to generic invalid-image negatives.

Every source is registered with version, DOI/revision, licence evidence,
intended role, exclusions and warnings. Exact hashes and perceptual-duplicate
clusters are built before splitting. A farm, plant, capture burst, derivative
family or duplicate cluster may exist in only one split. Offline augmentation
is forbidden before splitting; train-only augmentation is generated online.

The internal split is 70% train, 10% model selection, 10% post-freeze
calibration and 10% untouched test, grouped and stratified where evidence
allows. At least one whole field source is reported separately as domain shift.
Digital Green farmer photographs and the Bangladesh complex-background tomato
set are external tests, not optimization data. A future Nepal set is locked by
farm, district, season and device and is never used for tuning.

Selection uses field macro-F1, worst-class recall, calibration, selective risk,
OOD false accepts, model size and device latency. It never uses headline
closed-set accuracy alone. Post-training full-integer quantization uses
train-only representative images. Quantization-aware training is considered
only if PTQ misses the allowed parity delta.

The intended mobile artifact is one fully-int8 pack per crop, loaded on demand,
with aspect-preserving letterbox preprocessing and concatenated raw logits. A
schema-v2 manifest records tensor quantization, ordered head keys, preprocessing,
temperatures, class and validity thresholds, energy rule, hashes, snapshot
identifiers, licences and limitations. The current float32 38-output runtime is
kept unchanged until a separately reviewed integration implements that schema.

## Promotion gates

Initial gates are deliberately strict and may be revised only with recorded
field evidence:

- accepted-set per-class precision lower 95% confidence bound at least 0.90;
- healthy-call precision lower 95% confidence bound at least 0.95;
- OOD false-accept upper 95% confidence bound at most 0.05;
- usable-target-leaf recall at least 0.95;
- expected calibration error at most 0.05;
- int8 field macro-F1 and accepted-risk loss versus float at most one
  percentage point;
- each crop pack at most 6 MB and all packs keep the delivered app within the
  60 MB budget;
- warm p95 at most 750 ms and cold inference at most two seconds on the defined
  reference devices.

Passing public data does not enable a confirmed diagnosis. Any class without
adequate locked Nepal support remains `possibleMatchOnly`. D-56 is reopened
only after the Nepal test, agronomy review, localized safety review and rollout
controls also pass.

## Consequences

Training becomes reproducible and auditable, and model failures can be traced
to a source, split, taxonomy and artifact. The app gains a credible route to
refusing wrong subjects instead of naming a disease for every image.

The cost is additional modelling, labelling, calibration, conversion and
device work. Three packs require lifecycle management. Public datasets can
start representation learning and measure domain shift, but product promotion
still depends on collecting a Nepal-representative set with qualified labels.

## Rejected alternatives

**Retrain another global 38-way softmax and replace the asset immediately.**
Rejected because it preserves closed-set behavior and crop/background leakage.

**Use random image splits.** Rejected because bursts, copies and offline
augmentations can make near-identical leaves appear in both train and test.

**Treat a low maximum-softmax score as an OOD detector.** Rejected because a
closed-set network can be highly confident on unrelated inputs. Validity and
energy behavior require their own evidence and thresholds.

**Train on every downloadable repository.** Rejected. Noncommercial,
no-derivatives, conflicting or untraceable image rights are not made safe by
technical accessibility.

## Dissent

Recorded: three crop packs increase engineering and release complexity relative
to one model. Accepted because they reduce output confusion, keep packs small,
allow crop-specific calibration and match the app's explicit crop context.

Recorded: the initial precision and OOD gates may be unreachable with public
data. Accepted because a failed gate is useful evidence that the model must
remain experimental; lowering a safety claim to fit the available data would
not improve the product.
