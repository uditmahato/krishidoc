# PlantCity Pakistan v2 cross-archive lineage review v1

- Review time: 2026-09-03 12:14:30 +05:45
- Source: [PlantCity Pakistan version 2](https://data.mendeley.com/datasets/w8kh2xkspx/2)
- DOI: `10.17632/w8kh2xkspx.2`
- Licence: CC BY 4.0
- Scope: completed provider `test.zip`, completed provider `train.zip`, and both extracted trees
- Source admission: `not_admitted`
- Provider partition decision: `rejected_lineage_leaked_not_evaluation`
- Train decision: `derivative_archive_excluded_not_admitted`
- Test decision: `original_candidate_training_only_not_admitted`
- Nepal evidence: `false`
- Evaluation or promotion evidence: `false`

This review completes the cross-archive work that was explicitly deferred in
the earlier [TEST-only review](plantcity-pakistan-v2-test-review-v1.md). It does
not admit, move, delete, relabel, or train on either archive.

## Immutable scope and integrity

| Artifact | ZIP bytes | Members (files + dirs) | Extracted files | Extracted bytes | SHA-256 |
|---|---:|---:|---:|---:|---|
| `Images/test.zip` | 1,128,347,591 | 10,719 (10,667 + 52) | 10,667 | 1,132,646,255 | `db1bd5624f42aceebff4d8ff08f99257b0608ac712a8bf5bf7f1e676d68bfffa` |
| `Images/train.zip` | 6,127,208,194 | 41,658 (41,606 + 52) | 41,606 | 6,174,435,200 | `aaa016487407f0c5c1ed2c02fad189bd7945c46a15553e5ac6e67419bccaccea` |
| Combined | 7,255,555,785 | 52,377 (52,273 + 104) | 52,273 | 7,307,081,455 | not applicable |

- MD5: test `d14401ded054bfd21208fdeb111e5fc2`; train
  `0da4b022d68f6c0d8ad80ab2aada52dc`.
- Extracted-tree inventory SHA-256: test
  `c657238e1837a41b4352c603f79aafc06337bca5c041a4777af72979ef2ffdbe`;
  train `b84a7d1eeac85e7f2aa56235a492305b44c3dff70ad0c99ea05ea3cd5b2e9761`.
- The tree digest is `sha256(sorted UTF-8 relative-POSIX-path + NUL +
  decimal-byte-size + NUL + lowercase-file-SHA256 + LF), v1`.
- Archive-to-extraction comparison found no missing, extra, duplicate-name,
  unsafe-path, encrypted, or size-mismatched members.
- All 52,273 files fully decoded as single-frame RGB JPEGs; decode failures: 0.

The publisher reports 10,667 collected images and 52,219 after augmentation.
The test tree is exactly 10,667 images, but the combined trees contain 52,273,
which is 54 above the reported augmented total.

## Folder and encoding parity

The two archives have the same 52 case-sensitive class folders.

| Crop family | Train | Test |
|---|---:|---:|
| Apple | 2,353 | 573 |
| Apricot | 1,796 | 461 |
| Bean | 2,568 | 639 |
| Cherry | 3,996 | 999 |
| Maize/corn | 1,860 | 465 |
| Fig | 2,291 | 573 |
| Grape | 6,305 | 1,575 |
| Loquat | 1,293 | 327 |
| Pear | 2,048 | 512 |
| Persimmon | 663 | 166 |
| Tomato | 12,411 | 3,369 |
| Walnut | 4,022 | 1,008 |

Train contains 40,246 `.jpg` and 1,360 `.jpeg` files. Test contains 8,415
`.jpg`, 1,904 `.JPG`, and 348 `.jpeg` files. Train has only six dimensions:
800x1000 (27,014), 1200x800 (7,610), 800x1200 (3,975), 1000x800
(2,181), 800x800 (810), and 1500x1000 (16). Test has 28 dimensions,
including camera-resolution files.

Train has no EXIF, progressive JPEG, or ICC profile. Test has 115 EXIF-bearing
files, 43 progressive JPEGs, and four ICC profiles; four test files retain GPS
and camera metadata. This standardized-versus-original-candidate encoding
boundary is both an augmentation signature and a possible model shortcut.

Train filenames are entirely renumbered numeric counters or `tomato_N`.
Twenty-nine of 52 classes have exactly four train files per test file; this
includes all four maize classes. No filename records an augmentation operation
or parent identity.

## Deterministic augmentation lineage

Twenty-seven clean numeric classes provide an unambiguous sequence covering
4,353 test originals and 17,412 train files. For test image `n`:

- train `4n-3` is a horizontal mirror;
- train `4n-2` is a vertical mirror;
- train `4n-1` is a noisy or recompressed identity;
- train `4n` is a rotated derivative in the manually reviewed sequences.

After applying the inverse operation to the first two slots, all 13,059 tested
slot-1/2/3 descendants were within DCT-pHash Hamming distance 8 of their exact
indexed parent; 13,041 were within distance 4. For 4,347 of 4,353 originals,
all three descendants were within distance 4. The remaining six originals were
distance 6 or 8. Slot-level pHash identity counts were 4,246 horizontal-mirror,
4,220 vertical-mirror, and 3,565 noisy-identity descendants.

For example, `test/test/Corn Normal leaf/1.jpg` is the parent of
`train/train/Corn Normal leaf/1.jpg` through `4.jpg`: mirror, vertical flip,
noise/recompression, and rotation respectively. This is direct lineage
evidence, not an inference from class ratios alone.

## Exact and perceptual relationships

The pHash method is the repository's conventional 64-bit grayscale DCT hash.
Distance-at-most-four links are candidate visual-dependence edges; the
deterministic index mapping and inspected transformations provide the stronger
parent/derivative evidence.

### Within train

| Check | Groups/components | Member images | Pairs | Cross-class |
|---|---:|---:|---:|---:|
| Exact SHA-256 | 120 | 240 | 120 | 2 groups |
| Identical pHash | 2,899 | 6,618 | not reported | 26 groups |
| pHash distance <= 4 | 3,922 | 9,000 | 6,307 | 85 components |

Exact contradictory train duplicates include:

- `Cherry brown_spot/65.jpg` = `Cherry Leaf Scorch/173.jpg`
- `Cherry brown_spot/66.jpg` = `Cherry Leaf Scorch/174.jpg`

### Across train and test

| Check | Shared values/pairs | Train images touched | Test images touched | Cross-class pairs |
|---|---:|---:|---:|---:|
| Exact SHA-256 | 102 / 102 | 102 | 102 | 0 |
| Identical pHash | 9,025 / 12,611 | 12,169 | 9,212 | 31 |
| pHash distance <= 4 | 15,326 pairs | 14,436 | 10,604 | 64 |

All 102 exact cross-archive pairs are in `Apple black_spot`; every one of that
folder's 102 test files occurs byte-for-byte in train. Examples include train
`395.jpg` = test `28.jpg`, and train `466.jpg` = test `99.jpg`.

The distance-at-most-four links touch 99.41% of the test tree. Within the
KrishiDoc-relevant maize and tomato subset they produce 7,787 pairs and touch
3,807 of 3,834 test images (99.30%): all 465 maize test images and 3,342 of
3,369 tomato test images. Thirty-eight product-scope pairs cross class,
including:

- train `Corn Fungal leaf/207.jpg` vs test `Corn gray leaf spot/132.jpg`, distance 2;
- train `Corn Normal leaf/411.jpg` vs test `Corn holcus_ leaf spot/35.jpg`, distance 4;
- train `tomato verticillium wilt/tomato_035.jpg` vs test
  `tomato_late_blight/13.JPG`, distance 0.

These links reproduce and multiply contradictions already found inside the
test-original candidate tree.

## Decision and safe handling

The provider boundary separates originals or original candidates from their
generated descendants; it is not an independent train/test partition.

1. Preserve both provider archives unchanged for provenance, but exclude every
   train-tree image from prepared manifests and model runs.
2. Never use either provider partition as validation, calibration, test,
   external, Nepal, promotion, or deployment evidence.
3. Keep test-tree images only as original candidates. They remain unadmitted
   until exact/pHash/capture-burst grouping, whole-component quarantine,
   privacy review, rights review, and representative agronomist adjudication
   are complete.
4. If originals are later admitted, assign groups and a training-only split
   before generating new augmentations. Generate reproducible transformations
   on the fly; do not reuse the publisher derivative archive.
5. Map only adjudicated maize and tomato conditions to KrishiDoc labels. Other
   species may only become reviewed wrong-crop/OOD evidence.
6. Quarantine every mixed-label exact or perceptual component in full. Do not
   resolve contradictions by majority folder name.
7. Preserve raw metadata for audit, but strip unnecessary EXIF/GPS from any
   derived training asset.

Pakistan imagery may improve future training diversity after remediation, but
it is not evidence of Nepal performance. No admission, experiment, model
selection, promotion, or phone installation is authorized by this review.
