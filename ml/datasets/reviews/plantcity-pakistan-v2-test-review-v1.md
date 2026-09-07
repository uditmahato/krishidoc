# PlantCity Pakistan v2 TEST-only review v1

- Review time: 2026-09-03 11:42:31 +05:45
- Source: PlantCity Pakistan, version 2, DOI `10.17632/w8kh2xkspx.2`
- Scope: completed `test.zip` and `extracted/Images/test/test` only
- Excluded: the live `train.zip.part`, cross-archive lineage, and all data admission
- Decision: `original_candidate_training_only_not_admitted`

Cross-archive lineage is now complete; see the
[versioned train/test lineage review](plantcity-pakistan-v2-lineage-review-v1.md).

## Immutable scope

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `Images/test.zip` | 1,128,347,591 | `db1bd5624f42aceebff4d8ff08f99257b0608ac712a8bf5bf7f1e676d68bfffa` |
| Extracted test tree | 1,132,646,255 | `c657238e1837a41b4352c603f79aafc06337bca5c041a4777af72979ef2ffdbe` |

The tree digest covers 10,667 files sorted by repository-relative POSIX path.
Each digest record is `path NUL decimal-size NUL lowercase-file-sha256 LF`.

## Inventory

All 10,667 files decode as RGB JPEG; there were no decode failures. The count
exactly matches the publisher's reported collected-image count, while the
publisher reports 52,219 images after augmentation. This makes TEST a plausible
**original-candidate collection**, not proof of untouched camera originals.

| Crop | Images | Classes and observed counts |
|---|---:|---|
| Apple | 573 | black spot 102; brown spot 265; normal 206 |
| Apricot | 461 | blight 90; normal 163; shot hole 208 |
| Bean | 639 | rust 124; fungal 194; normal 223; shot hole 98 |
| Cherry | 999 | brown spot 242; leaf scorch 282; normal 125; purple spot 240; shot hole 110 |
| Maize/corn | 465 | fungal 83; gray leaf spot 132; holcus spot 108; normal 142 |
| Fig | 573 | blight 191; brown spot 107; normal 150; rust 125 |
| Grape | 1,575 | anthracnose 249; brown spot 160; downy mildew 155; mites 125; normal 372; powdery mildew 301; shot hole 213 |
| Loquat | 327 | leaf spot 198; normal 129 |
| Pear | 512 | black spot 226; fire blight 95; normal 191 |
| Persimmon | 166 | brown spot 166 |
| Tomato | 3,369 | Fusarium 89; spider mites 127; Verticillium 105; bacterial spot 400; early blight 400; healthy 400; late blight 294; leaf curl 413; leaf miner 400; leaf mold 400; septoria 341 |
| Walnut | 1,008 | anthracnose 162; blotch 339; gall mite 98; normal 178; shot hole 231 |

Maize and tomato account for 3,834 images; the other 6,833 images could only
be considered as reviewed wrong-crop/OOD evidence for the current product.

## Encoding, resolution, and metadata

- Extensions: 8,415 `.jpg`, 1,904 `.JPG`, and 348 `.jpeg`; actual encoding is
  JPEG for every file.
- There are 28 dimension pairs, ranging from 573x717 to 3264x3264. Three
  standardized sizes contain 10,288 images (96.47%): 800x1000 (7,135),
  1200x800 (2,075), and 800x1200 (1,078).
- Only 115 images retain EXIF; 10,552 do not. All 115 name Adobe Photoshop 7.0.
  Four retain Canon EOS 1200D, GPS, artist, and copyright fields.
- Filename patterns are 9,449 per-class numeric counters, 1,156 `tomato_N`, 24
  `IMG_N`, and 38 `tomato_fusarium_N`. No augmentation token was found.

The count and visual appearance support an original-candidate interpretation,
and reviewed sequential maize frames show real parallax rather than simple
synthetic flips. However, standardized exports, Photoshop metadata, stripped
EXIF, recompressed repetitions, and renamed counters prevent a stronger raw-
original claim.

## Duplicate and contradiction evidence

| Check | Groups/components | Member images | Cross-class | Other |
|---|---:|---:|---:|---|
| Exact SHA-256 | 66 | 132 | 7 | All groups have size 2; 10,601 unique file hashes |
| Identical 64-bit DCT pHash | 194 | 392 | 9 | Largest group has 3 images |
| DCT pHash Hamming distance <= 4 | 344 | 713 | 16 | 384 matching pairs; largest component has 4 images |
| Distance <= 4, maize and tomato only | 183 | 382 | 9 | 208 pairs; 186 of 198 same-class pairs have numeric-name gap <= 3 |

Exact cross-label contradictions include:

- `Cherry brown_spot/17.jpg` = `Cherry Leaf Scorch/44.jpg`
- `Cherry Normal leaf/17.jpg` = `Cherry_shot hole disease/1.jpg`
- Tomato Verticillium `9`, `10`, `11`, `45`, and `99.JPG` equal tomato late
  blight `13`, `14`, `15`, `73`, and `190.JPG`, respectively.

Strong near-duplicate cross-label candidates include corn fungal 52 vs gray
leaf spot 132; corn holcus 35 vs normal 103; tomato Fusarium 34 vs septoria
243; and tomato spider-mites `IMG_3672` vs leaf-mold 327/328. pHash is a review
signal, not proof of label identity.

Manual review of at least 30 images also found repeated leaves and sessions,
including Corn Normal 109-112, Apple Brown spot 1-3, Walnut blotch 1-2, and
Tomato Fusarium 1-2. Capture domains mix field/canopy scenes, handheld leaves,
white paper, rugs, concrete, black tire-like material, and tree stumps. No
watermark was visible in the sample; no corpus-wide absence claim is made.

## Decision and required remediation

The completed TEST tree is **not admitted**. It must not be used as locked
internal test, independent external test, Nepal evidence, or promotion data.
Its only potential role is training-only or development-diagnostic public data
after all of the following:

1. Finish and integrity-check `train.zip`, then establish cross-archive
   original/derivative lineage with SHA, pHash, and geometric/photometric
   matching. Exclude derivatives or bind them to an original's train-only group.
2. Quarantine whole mixed-label exact and near-duplicate components; restore
   nothing without agronomist adjudication.
3. Group same-leaf, same-plant, and capture-burst sequences before splitting.
   Sequential filenames are supporting evidence, not a grouping rule alone.
4. Discard the publisher train/test boundary. This already-inspected source is
   never a pristine external holdout.
5. Map only reviewed maize and tomato folders to canonical labels. Vague or
   unsupported folders remain explicit unknowns; other species are wrong-crop/OOD.
6. Complete representative agronomy, rights, watermark, and privacy review;
   strip unnecessary GPS/EXIF from derived inputs while retaining attribution.
7. Run the fail-closed manifest audit and freeze a new manifest hash before
   starting any experiment.

The complete machine-readable evidence is in
`plantcity-pakistan-v2-test-review-v1.json`.
