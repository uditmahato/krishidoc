# KrishiDoc field-model dataset card and provenance ledger

- **Card version:** 1.0
- **Evidence snapshot:** 2026-09-02 17:50 NPT
- **Product scope:** photo-based possible-match assistance for maize, potato,
  and tomato
- **Release status:** research and provisional model development only
- **Nepal claim status:** **not established**

This document distinguishes data that merely exists on disk from data that has
passed the repository's manifest audit. It describes the evidence available at
the timestamp above; an archive that finishes downloading later is not silently
covered by this snapshot.

## Intended use and non-use

The admitted data may be used to train and evaluate an experimental visual
matching and refusal system. It may not be used to claim that KrishiDoc
diagnoses disease, performs reliably in Nepal, or recommends a pesticide,
mixture, dose, waiting period, or other treatment from a photograph alone.

The intended model has a crop-condition head and a validity/refusal head. A
label ending in `_other_unknown` is open-set exposure, not a disease-name
target. `not_applicable` means no crop condition is assigned. Public-dataset
performance is evidence about those sources only.

## Evidence states

| State | Meaning |
|---|---|
| **Admitted** | Present in the immutable audited manifest snapshot and eligible for its assigned role. |
| **Staged** | A complete local artifact exists and has integrity evidence, but its images are not in the audited manifest. It must not affect the current run. |
| **Incomplete** | A `.part`, partial extraction, or unreceipted multi-file acquisition exists. No image from the incomplete batch is admissible. |
| **Registered only** | Described in `sources.json` but absent from this local evidence snapshot. |

## Audited manifest snapshot

The only audited corpus in this card is
`ml/data/prepared/manifest_8bb7dc0355d1.csv`.

| Evidence | Value |
|---|---:|
| Manifest SHA-256 | `8bb7dc0355d1e2fa09a178695e9db6311dc6f215708ae27495a56c0d80ff7cae` |
| Audit status | passed |
| Audit time | 2026-09-02T11:38:20.215663Z |
| Image-byte verification | enabled; 15,557/15,557 rows verified |
| Rows | 15,557 |
| Leakage-locked groups | 15,160 |
| Sources | 3 |
| Field images | 13,218 |
| Non-field images | 2,339 |
| Near-duplicate pHash distance | 4 bits |
| Derivative rows admitted | 0 |

The receipt is
`ml/data/prepared/audit_receipt_8bb7dc0355d1.json`. The snapshot currently
contains absolute Windows paths, so the manifest is reproducible on this
workstation but is not portable by itself. Future manifests should use the
repository-relative path mode already supported by the preparation tool.

### Split composition

| Split | Purpose | Field | Lab/non-field | Total |
|---|---|---:|---:|---:|
| train | Gradient updates only | 8,549 | 2,339 | 10,888 |
| validation | Early stopping and architecture selection | 1,234 | 0 | 1,234 |
| calibration | Temperature and refusal-threshold fitting | 1,234 | 0 | 1,234 |
| test | Frozen in-domain report | 1,213 | 0 | 1,213 |
| external_test | Whole-source domain-shift report | 988 | 0 | 988 |
| **Total** |  | **13,218** | **2,339** | **15,557** |

Unlocked groups are deterministically stratified by source, crop, condition,
and validity, then apportioned 70/10/10/10. A connected component formed by a
source group, exact SHA-256 duplicate, or pHash-near-duplicate is assigned to
one split only. Derivatives are train-only. Source locks override the regular
split, and `farmer_chat_india` is locked to `external_test`.

This split policy controls known image-copy leakage. It does **not** prove farm,
plant, cultivar, or capture-session independence when the upstream data does
not provide those identifiers.

### Source composition in the audited snapshot

| Source id | Train | Validation | Calibration | Test | External | Total | Independent groups |
|---|---:|---:|---:|---:|---:|---:|---:|
| `tom2024-original` | 8,549 | 1,234 | 1,234 | 1,213 | 0 | 12,230 | 11,848 |
| `maize-figshare-29298275` | 2,339 | 0 | 0 | 0 | 0 | 2,339 | 2,338 |
| `farmer_chat_india` | 0 | 0 | 0 | 0 | 988 | 988 | 974 |

### Crop and validity composition

| Crop value | Rows |
|---|---:|
| maize | 6,403 |
| potato | 97 |
| tomato | 4,496 |
| unknown/other crop | 4,561 |

| Validity label | Rows |
|---|---:|
| usable target leaf | 8,809 |
| unsuitable target-crop view | 2,187 |
| wrong-crop leaf | 2,165 |
| other plant | 2,396 |
| non-plant | **0** |

The absence of non-plant photographs is a critical coverage gap. A validity
head trained from this snapshot has no direct supervised examples of hands,
tools, soil-only frames, documents, animals, buildings, or arbitrary camera
content.

### Condition composition by source

The counts below are manifest labels after repository aliasing; they are not a
fresh pathological re-annotation.

| Source | Crop / condition label | Rows |
|---|---|---:|
| TOM2024 | maize common rust | 99 |
| TOM2024 | maize healthy | 585 |
| TOM2024 | maize other/unknown | 2,833 |
| TOM2024 | maize view with no condition target | 1,220 |
| TOM2024 | tomato early blight | 322 |
| TOM2024 | tomato late blight | 74 |
| TOM2024 | tomato healthy | 782 |
| TOM2024 | tomato other/unknown | 2,304 |
| TOM2024 | tomato view with no condition target | 967 |
| TOM2024 | other crop / no condition target | 3,044 |
| Figshare maize | Cercospora/gray leaf spot | 282 |
| Figshare maize | common rust | 538 |
| Figshare maize | healthy | 430 |
| Figshare maize | northern leaf blight | 342 |
| Figshare maize | pepper / other plant | 747 |
| Digital Green external | maize healthy | 10 |
| Digital Green external | maize northern leaf blight | 4 |
| Digital Green external | maize other/unknown | 60 |
| Digital Green external | potato early blight | 11 |
| Digital Green external | potato late blight | 8 |
| Digital Green external | potato healthy | 27 |
| Digital Green external | potato other/unknown | 51 |
| Digital Green external | tomato early blight | 2 |
| Digital Green external | tomato late blight | 2 |
| Digital Green external | tomato healthy | 11 |
| Digital Green external | tomato other/unknown | 32 |
| Digital Green external | other crops / other plant | 770 |

Known-label field support in the internal test is small: maize rust 9, maize
healthy 57, tomato early blight 31, tomato late blight 7, and tomato healthy
75. There is no internal field test support for maize Cercospora/gray leaf spot
or northern leaf blight. No potato image is available for gradient updates,
validation, calibration, or the internal test in this snapshot.

## Source-level provenance

### 1. TOM2024 Category A English — admitted

- **Upstream:** [TOM2024, version 1](https://data.mendeley.com/datasets/3d4yg89rtr/1),
  DOI `10.17632/3d4yg89rtr.1`.
- **Declared licence:** CC BY 4.0.
- **Geography/domain:** field images from West Africa; the record specifically
  identifies Burkina Faso among its categories. It covers maize, tomato, and
  onion under varied field conditions.
- **Local artifact:** `TOM2024-CATEGORYA-English.zip`, 134,833,774 bytes,
  SHA-256
  `6c110be15bc8bcdd4bc58aed277b3b81d66d8e2497505edb19639a60a8b76747`.
- **Local content:** 12,230 images, all admitted as field data.
- **Role:** primary public field training, validation, calibration, and
  in-domain test source.

Only Category A is acquired. Category B is derived and is excluded. Onion,
pests, fruit views, abiotic injury, and unsupported conditions are used only
for validity or open-set exposure where the alias mapping explicitly permits
it.

The upstream record says there are 12,227 labelled images, while the immutable
Category A English archive contains and the manifest admits 12,230. The
three-image discrepancy must be reconciled with the publisher before a release
dataset is frozen. TOM2024 also lacks stable farm, plant, and capture-session
IDs, so pHash grouping reduces but cannot eliminate burst leakage.

### 2. Maize Leaf Dataset on Figshare — admitted, lab-only

- **Upstream:** [Maize Leaf Dataset](https://figshare.com/articles/dataset/Maize_Leaf_Dataset/29298275),
  article `29298275`.
- **Declared licence:** CC BY 4.0.
- **Local artifact:** `Maize_Dataset.zip`, 35,189,395 bytes, SHA-256
  `2631a4ae9e336506119c9d090a20db52a1c56ca1cbbc1e27e4971785c885835f`.
- **Local content:** 2,339 images: 1,592 maize and 747 unexpected pepper.
- **Role:** train-only representation warm start and wrong-crop exposure. It
  is not field validation evidence.

Although the upstream description presents the images as field-oriented, the
downloaded files have PlantVillage-style names, isolated backgrounds, and
256x256 content. The archive also contains 301 pepper disease and 446 pepper
healthy images not disclosed in the headline maize counts. Its exact upstream
image lineage is unresolved. The Figshare record's licence statement therefore
does not, by itself, resolve rights in every repackaged upstream image. Keep
this source internal-only until lineage and attribution are reviewed.

### 3. Digital Green Crop Disease Images — admitted external benchmark

- **Upstream:** [DigiGreen/Crop_Disease_Images](https://huggingface.co/datasets/DigiGreen/Crop_Disease_Images).
- **Pinned revision:** Git commit
  `2b18be861bddeb525c83cf2d7e07eb7f649dfed9`; Git tree
  `1e1763706ae0eb82d1f79218ee5846f50fb7be7d`.
- **Declared licence:** CC BY 4.0; attribution target is Digital Green.
- **Upstream content:** 1,026 agronomist reviews over 989 farmer photographs
  across 74 crop types. The record says 988 images are from India and one is
  from Ethiopia; Bihar accounts for 738 images.
- **Local/admitted content:** all 989 image LFS objects are present; 988 images
  are admitted to `external_test`.
- **Role:** whole-source farmer-photo domain-shift benchmark only.

The one omitted image (`images/00266.jpg`) has expert rows that identify
different crops (Groundnut and Potato). The fail-closed metadata adapter rejects
that target-versus-nontarget crop conflict. Other multi-review rows that map to
the same non-target validity role can remain grouped.

This source is not Nepal evidence. It is heavily concentrated in one Indian
state and one Rabi-season window. Its location fields describe the registered
farmer location, not verified capture coordinates. The publisher reports a
privacy-screening process and removal of EXIF and direct identifiers, but also
warns that faint overlays could remain.

The source has now been consumed in architecture and data decisions. Its
immutable canonical-manifest value remains `external_test` for provenance, but
its evidence role is now `external_development`; it is not an independent test
and is never promotion-eligible. A deterministic sidecar assigns all 988
admitted images / 974 indivisible groups to five development folds of
197--198 images. It preserves source crop, diagnosis, state, and review count,
and flags expert disagreements without visually adjudicating them. The one
unadmitted, crop-conflicting image remains an orphaned-annotation record in the
report rather than being reintroduced.

Generate the ignored local sidecar and its exact imbalance report with
`ml/scripts/assign_development_folds.py`. The current sidecar SHA-256 is
`2689d8bfff21c68acfad260a2f50702fb7a1261ecc31a38d99b6f20e980b087a`;
it binds canonical manifest SHA-256
`ae51bad46aa258fe7877ecbbeb36bc0a3815c7f4c76485ed2ad967668be26751`
and raw annotation SHA-256
`48aba8948b3e59888cb489784153fd493b0f4b43e9ed3147d97ef7cb9330d715`.
The schema is `datasets/development_fold_schema_v1.json`. Another locked,
independently labelled source is required for an unbiased final domain-shift
report.

### 4. Central Java potato dataset — v3 training-only open-set source

- **Upstream:** [Potato Leaf Disease Dataset in Uncontrolled Environment,
  version 1](https://data.mendeley.com/datasets/ptz377bwb8/1), DOI
  `10.17632/ptz377bwb8.1`.
- **Declared licence:** CC BY 4.0.
- **Geography/domain:** potato farms in Central Java, Indonesia; uncontrolled
  backgrounds and multiple smartphone cameras.
- **Verified artifact:** `ptz377bwb8-v1-direct.zip`, 753,317,238 bytes,
  SHA-256
  `8a80f7b891f91b2c4e1fe44066b3c78a7c79986f2a4fb1ad34c232a04b815154`;
  ZIP CRC passed.
- **Local content:** 3,076 JPEGs: Bacteria 569, Fungi 748, Healthy 201,
  Nematode 68, Pest 611, `Phytopthora` 347, and Virus 532.
- **Role after admission:** potato field representation; broad classes are
  open-set exposure, not disease-name targets.

Only Healthy maps to a reviewed named condition target. The publisher's
misspelled `Phytopthora` directory does not establish late blight, and the
repository has no image-level expert evidence that would justify that narrower
diagnosis. In the versioned v2 alias policy, `Phytopthora`, Bacteria, Fungi,
Nematode, Pest, and Virus all map to `potato_other_unknown`.

Filename inspection shows rapid camera sequences in both Unix-millisecond and
`YYYYMMDD_HHMMSS` forms. Before splitting, the repository groups recognized
timestamps into parent-scoped ten-minute buckets using UTC+07:00. The source is
also locked entirely to training, so no Central Java image can become internal
validation, calibration, test, or promotion evidence. This is a conservative
proxy, not a proven farm/plant identity.

An earlier 999,683,446-byte resumed archive failed CRC and is quarantined as
`ml/cache/quarantine/ptz377bwb8-1.corrupt.zip`; 203 separately fetched partial
Bacteria files are also quarantined. Neither is eligible for any manifest.

### 5. Bangladesh potato dataset — staged, count conflict unresolved

- **Upstream:** [Potato Leaf Disease Dataset, version 1](https://data.mendeley.com/datasets/d5b3fzpw3g/1),
  DOI `10.17632/d5b3fzpw3g.1`.
- **Declared licence:** CC BY 4.0.
- **Geography/domain:** Bangladesh Agricultural Research Institute field site
  in Chattogram; iPhone 15 under natural light/background.
- **Verified artifact:** 38,393,565 bytes, SHA-256
  `549c7f3343422fa2b77b6fb2c5009a52215aa00626b2646435ba19f4826f8192`.
- **Local content:** 2,351 images across six directories.
- **Role after resolution:** original field images only; derivatives excluded.

The landing record reports 804 originals and a 2,400-image balanced augmented
dataset. The downloaded versioned archive instead contains 84 filenames marked
`orig_` and 2,267 marked `aug_`:

| Class | Identifiable originals | Augmented |
|---|---:|---:|
| Bacterial Soft Rot | 7 | 390 |
| Fungal Late Blight | 20 | 372 |
| Healthy | 16 | 376 |
| Viral Leaf Roll | 33 | 361 |
| Viral PVX | 6 | 381 |
| Viral PVY | 2 | 387 |
| **Total** | **84** | **2,267** |

The repository's `**/aug_*` exclusion prevents the 2,267 identifiable
derivatives from entering a manifest. The 720-original shortfall and 49-image
overall shortfall against the publisher description require clarification; do
not infer that unmarked files are originals. Until resolved, none of this
source should be admitted. The broad bacterial and virus categories would be
open-set exposure even if provenance is cleared; only fungal late blight and
healthy have current reviewed condition mappings.

### 6. PLDD-UP — verified; provisional sanitized admission only

- **Upstream:** [PLDD-UP, version 1](https://data.mendeley.com/datasets/3j4nfkvp2n/1),
  DOI `10.17632/3j4nfkvp2n.1`.
- **Declared licence:** CC BY 4.0.
- **Geography/domain:** operational fields in Mainpuri, Etawah, and
  Jaswantnagar, Uttar Pradesh, India; Rabi season from October 2025 through
  March 2026; cameras and smartphones under natural light.
- **Publisher counts:** early blight 4,803; late blight 6,116; healthy 4,600;
  total 15,519.
- **Local status at snapshot:** the versioned download-all archive is complete
  at 8,773,735,553 bytes with SHA-256
  `3b990af3664510397c4a2732caf1face34c10a95e205b1bec8176ccff44db7ae`.
  The outer ZIP and all three nested archives passed CRC reads. Transactional
  safe extraction produced exactly 4,803 early-blight, 6,116 late-blight, and
  4,600 healthy images (15,519 total), reconciling exactly to the publisher
  counts. The local evidence receipt is
  `ml/data/raw/pldd-up/.direct-recovery-receipt.json`.
- **Role:** provisional potato field representation only, subject to the
  contradiction quarantine, session grouping, duplicate audit, and label
  review below.

No PLDD-UP image is admitted to the original frozen `8bb7dc...` manifest.
Acquisition and extraction are complete. The first successor manifest, v2,
was rejected after a stricter post-build audit found contradictory labels;
only the separately named, sanitized v2.1 snapshot may be used for a new
provisional run after its full audit passes.

The next-manifest builder now has a source-specific grouping contract, without
regenerating that frozen manifest. All filenames match one of three numeric
forms. There are 4,509 distinct early-blight numbers with 294 extension
collisions, 4,520 healthy numbers with 80 collisions, and 6,015 late-blight
numbers with 101 collisions. A collision is locked as one lineage group.
That is deliberately conservative: all 475 cross-extension collision pairs
have different SHA-256 values and visual sampling found unrelated scenes, so
the lock prevents leakage under unresolved lineage rather than asserting that
the files are duplicate photos.
Immediate numeric neighbours are joined only when a 64-bit pHash distance of
at most 12 corroborates the filename adjacency, and the grouping key includes
source, canonical class, parent, prefix, and exact case-sensitive filename
suffix (`.JPG`, `.jpeg`, or `.jpg`). Numeric adjacency by itself is
unsafe because the class sequences are largely continuous. This heuristic
can miss bursts across an upstream rename/import boundary and cannot recover
farm, plant, or true session identity; it does not make PLDD-UP
an external or Nepal validation set.

The rejected v2 snapshot has SHA-256
`6005e4828b1c3f9f0edc314c123755e9707f6d08faf7cbf5cc6ff2f3c75059b9`.
It contained 87 groups / 293 rows with multiple canonical condition labels:
65 PLDD-UP groups / 249 rows and 22 TOM2024 groups / 44 rows. Five PLDD-UP
pairs are byte-identical images labelled both early blight and healthy; the
remaining PLDD conflicts are pHash-connected components requiring review.
The v2 run was stopped before its first checkpoint.

The deterministic whole-component quarantine records every excluded group,
input row number, path, SHA-256, pHash, label, and original manifest row in
`ml/data/prepared/quarantine_field_v2_1_pldd_up.json`. It removes all 293 rows,
not individual duplicates, so no leakage component is split. The resulting
`manifest_field_v2_1_pldd_up.csv` contains 30,783 rows / 26,867 groups. This is
exclusion rather than expert adjudication and remains non-promotable. Its
image-verifying fail-closed audit passed all 30,783 retained files with zero
mixed-condition groups; the receipt is
`ml/data/prepared/audit_receipt_field_v2_1_pldd_up.json`. The sanitized
manifest SHA-256 is
`ae51bad46aa258fe7877ecbbeb36bc0a3815c7f4c76485ed2ad967668be26751`.

Retrospective application of the same invariant found 21 exact-byte TOM2024
groups / 42 rows in the original frozen manifest: 9 maize groups and 12 tomato
groups. One is a direct tomato early-blight vs
healthy condition-supervision contradiction; another puts byte-identical
tomato healthy and open-set-unknown rows into calibration. Therefore older
maize/tomato results remain provisional and their legacy receipts are not
promotion evidence under the current audit contract.

## Licence and release obligations

Each source above declares CC BY 4.0 on its primary landing record. The
[CC BY 4.0 deed](https://creativecommons.org/licenses/by/4.0/) permits sharing
and adaptation, including commercial use, subject to appropriate credit, a
licence link, and an indication of changes. It does not guarantee that privacy,
publicity, moral, trademark, or other third-party rights are cleared.

For any shipped model or redistributed dataset, maintain a reviewed attribution
file containing, for each admitted source:

1. dataset title and creators/attribution party;
2. exact version, DOI or pinned commit, and landing URL;
3. `CC BY 4.0` and the canonical licence link;
4. a statement that labels were mapped, images transformed, and a model was
   trained from the data;
5. no suggestion that the dataset creators endorse KrishiDoc.

The current source-level record is sufficient for internal reproducibility,
not a final legal opinion. Figshare maize needs upstream-lineage review, and
all release attributions should be checked against the exact downloaded
version.

## Known hazards and controls

| Hazard | Current evidence | Required control |
|---|---|---|
| Augmentation leakage | Bangladesh archive is mostly pre-augmented; CCMT registry also exposes a much larger augmented branch. | Exclude offline derivatives or bind every derivative to its original group; never report them in evaluation. |
| Capture-burst leakage | Central Java filenames show rapid sequences; TOM2024 and PLDD-UP may also contain bursts. | Use session/farm/plant groups where recoverable, pHash clustering, and manual cluster review before freezing. |
| Lab-to-field domain gap | All Figshare maize images are non-field in the manifest. | Train-only role; never combine them into field validation/test metrics. |
| Geographic shift | Admitted data is West African, mostly Indian, or lab-style; staged potato data is Indian, Indonesian, and Bangladeshi. | Locked Nepal evaluation by district, season, altitude, cultivar, device, and farm. |
| Taxonomy ambiguity | Labels such as Fungi, Virus, Pest, and abiotic/pest mixtures are not disease species. | Map broad labels to unknown/OOD; require agronomy review for every disease-name alias. |
| Thin class support | Several field test classes have only 7–31 samples; potato has no internal train/test support. | Report confidence intervals and minimum class support; do not rely on point accuracy. |
| Non-plant blindness | Current manifest contains zero `non_plant` rows. | Add rights-cleared, manually reviewed non-plant and unsuitable-camera negatives before validity claims. |
| External holdout reuse | Digital Green has already been made available as an external benchmark. | Do not select models from its score; if that happens, retire it from final-holdout status. |
| Label noise | Path aliases and source annotations are not equivalent to pathology confirmation; some Digital Green images have multiple expert rows. | Double review disputed/mixed cases and record adjudication; keep raw source labels alongside canonical labels. |
| Metadata/archive mismatch | TOM2024 differs by 3 images; Bangladesh potato differs materially from published counts. | Reconcile with publishers and freeze exact receipts before admission. |
| Privacy | Farmer photographs can contain accidental identifying overlays even after screening. | Automated plus human PII checks, no EXIF, documented takedown and retraining process. |
| Manifest portability | Current frozen manifest uses absolute paths. | Use repository-relative paths for the next manifest and record its repository root contract. |

## Nepal validation gap

There are **zero Nepal images** in the audited or staged sources described
above. No evidence currently measures Nepal's crop varieties, pathogens,
altitude and agroecological zones, monsoon lighting, dust and soil backgrounds,
farmer camera habits, local treatment history, or device mix. Similar climate
or a neighboring country is not a substitute.

A release-grade Nepal evaluation should be collected under a protocol fixed
before model selection. It should:

- hold out whole farms and collection sessions;
- cover major production districts and agroecological/altitude bands for each
  supported crop across relevant seasons;
- record crop variety, growth stage, capture device, lighting, recent weather,
  and prior treatment without exposing farmer identity;
- include healthy, each supported disease, confusing unsupported diseases,
  abiotic stress, pests, mixed infections, whole-plant/fruit/stem views,
  wrong crops, other plants, and non-plant frames;
- use qualified agronomy/pathology review, with laboratory confirmation where
  visual diagnosis is not a defensible gold standard;
- preserve ambiguous cases rather than forcing them into a disease class;
- preregister model, thresholds, metrics, and per-class support before opening
  labels; and
- obtain informed collection consent, a retention/takedown policy, and a local
  governance review.

Until that test passes the recorded safety gates, every output remains a
possible visual match and the app must offer a clear uncertainty/referral path.

## Registered sources not present in this snapshot

The registry also names CCMT Ghana raw field images, Bangladesh tomato
classification images, Bangladesh tomato bounding-box images, a Bangladesh
binary tomato holdout, PlantDoc, a PlantVillage mirror, and PlantWild. None is
part of the audited corpus described here. PlantDoc and the PlantVillage mirror
require additional rights/provenance review; PlantWild is excluded because its
registered CC BY-NC-ND licence is incompatible with the intended training and
product workflow.

## Reproduction and update checklist

1. Verify the exact `sources.json`, `label_aliases.json`, taxonomy, config, and
   manifest hashes recorded in the audit receipt.
2. Accept only complete archives or pinned Git revisions with byte/tree
   receipts; quarantine failed or resumed-corrupt downloads.
3. Reconcile upstream and observed file/class counts before manifesting.
4. Preserve original source labels and provenance while applying reviewed
   canonical aliases.
5. Cluster exact duplicates, pHash-near-duplicates, derivatives, and known
   capture sessions before split assignment.
6. Audit image bytes and all split locks.
7. Create a new immutable manifest and audit receipt; never mutate this
   snapshot in place.
8. Update this card's timestamp, counts, hashes, licence review, and Nepal gap.

Primary machine-readable evidence lives in:

- `ml/datasets/sources.json`
- `ml/datasets/label_aliases.json`
- `ml/datasets/taxonomy_v1.json`
- `ml/datasets/manifest_schema_v1.json`
- `ml/data/prepared/manifest_8bb7dc0355d1.csv`
- `ml/data/prepared/audit_receipt_8bb7dc0355d1.json`
- `ml/data/raw/potato-bangladesh/.receipt.json`
- `ml/data/raw/potato-central-java/.direct-recovery-receipt.json`
