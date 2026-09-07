# Open Images V7 non-plant candidate staging

This pipeline stages object-focused photographs for **manual** review. It does
not create `non_plant` labels and does not modify an active dataset manifest.

## Why manual review is mandatory

Open Images V7 provides human-verified positive and negative image labels plus
object boxes, but those annotations are not an exhaustive inventory of every
object in a frame. The absence of a positive `Plant` or `Person` label is not
proof that no plant or person is visible. Background vegetation, food,
reflections, screens, small faces, and unannotated objects can remain.

Accordingly, every selected row has:

- `review_status=manual_review_required`;
- `admission_status=staged_not_admitted`;
- `intended_review_outcome=non_plant_candidate_only`; and
- no assigned training label.

## Reproduce the staging set

From the repository root:

```powershell
.\.venv\Scripts\python.exe ml\scripts\stage_openimages_negatives.py `
  --limit 750 `
  --workers 12
```

The checked-in policy is
`ml/datasets/openimages_negative_policy_v1.json`. It pins the official
metadata URLs, selection seed, target object classes, exclusion terms,
per-class cap, minimum bounding-box area, accepted pixel licence URLs, and the
manual-review state.

Generated local evidence is ignored by Git under
`ml/data/raw/openimages-v7-nonplant-candidates/`:

- `metadata/*.csv`: the four official source tables;
- `candidates.csv`: image IDs, positive labels, object evidence, source and
  landing URLs, attribution fields, licence URL, local path, bytes and SHA-256;
- `images/*.jpg`: pixels from the official Open Images public bucket; and
- `receipt.json`: policy/metadata hashes, counts, licences and fail-closed
  readiness state.

## Selection contract

The selector uses the Open Images validation split and requires:

1. a real, non-group, non-depiction target-object box covering at least 20% of
   the frame;
2. no human-positive image label or box label matching the policy's people,
   plant/crop/tree/flower/leaf, or food exclusions;
3. a per-image CC BY 2.0 URL in Open Images image information;
4. a non-empty original landing page and author; and
5. deterministic, class-balanced selection capped at 50 images per primary
   object class.

This is a candidate-reduction rule, not an automated ground-truth rule.

## Manual review protocol

Review the full-resolution local image and its original landing page. Reject a
candidate if any of the following is visible, even incidentally:

- a person, face, identifying document, licence plate, or sensitive text;
- any crop, plant, leaf, flower, tree, grass, fruit, vegetable, prepared food,
  feed, seed, or ambiguous organic material;
- an image dominated by a screen, drawing, or photograph of excluded content;
- corruption, extreme blur, a misleading crop-like texture, or insufficient
  resolution; or
- missing/inconsistent author, landing-page, or licence evidence.

An accepted review must record reviewer identity, review timestamp, a fixed
reason code, and the verified licence/landing URL. A second reviewer should
adjudicate ambiguous cases. Only a separately generated, reviewed manifest may
then assign `validity_label=non_plant`; never edit `candidates.csv` into the
active manifest directly.

## Licence boundary

The [Open Images V7 description](https://storage.googleapis.com/openimages/web/factsfigures_v7.html#licenses)
states that Google annotations are CC BY 4.0 and images are listed as CC BY
2.0, while expressly declining to warrant each image's licence status. The
[download documentation](https://storage.googleapis.com/openimages/web/download_v7.html)
defines the image-information fields retained by this pipeline, including the
author, original and landing URLs, licence URL, title, original MD5 and
rotation.

Release use therefore requires per-image attribution and licence verification;
the staging receipt is provenance evidence, not a legal clearance.
