# V6: preserve the validity path, adapt disease recognition

Status: **COMPLETED AND REJECTED for app replacement**. Neither V5 nor V6 was
silently substituted into the app.

Preflight completed: all 34,001 current image hashes matched the pinned full
audit; structural checks passed. The full ML suite passed **256 tests**, with
one existing ONNX deprecation warning. With the two new subgroup-reporting tests,
the final full suite passed **258 tests**, with the same warning. Run started
2026-09-07 07:36:18 UTC and finished 07:49:19 UTC (13:34:19 Nepal time).
Source snapshots and stage receipts are retained under
`ml/artifacts/potato_field_v6_condition_only_20260907/`.

## Outcome

The controlled experiment preserved the validity path exactly but did not improve
disease recognition overall. Do not deploy it or keep extending its epochs on
the strength of its improving validation monitor.

| Diagnostic measure | Original V3 | Rejected V5 | V6 |
| --- | ---: | ---: | ---: |
| Correct accepted predictions | 457 | 470 | 447 |
| Wrong accepted predictions | 43 | 70 | 53 |
| Unsupported inputs falsely accepted, /220 | 13 | 32 | 13 |
| False healthy outputs, including unsupported inputs | 15 | 15 | 9 |
| PlantSeg early: correct accepted, /22 | 6 | 13 | 8 |
| PlantSeg late: correct accepted, /22 | 16 | 19 | 14 |
| Holeta healthy: correct accepted, /331 | 325 | 328 | 324 |
| Holeta late: correct accepted, /66 | 58 | 56 | 49 |
| Google disease: correct accepted, /8 | 3 | 4 | 3 |
| PLDD internal: correct accepted, /45 | 42 | 43 | 43 |

These are paired counts from 749 diagnostic inputs, not deployment accuracy.
The totals exclude three unverified healthy-looking Google controls; all three
were refused by every model. There are 526 remaining supported-condition inputs
and 220 unsupported inputs. All photographs are now consumed development data.

- Across all 749 inputs, the maximum validity-logit difference from V3 was
  **0.0**. Calibration independently verified all non-condition-head state tensors
  were bit-identical. All acceptance decisions also happened to remain identical.
- Among accepted predictions, V6 corrected four formerly incorrect cases but
  broke fourteen formerly correct cases: net ten fewer correct answers. Lower
  false-healthy counts therefore do **not** establish a safer overall classifier.
  For supported diseased leaves alone, false healthy outputs fell from 11 to 5.
- In Holeta, eleven late-blight photographs changed from a raw late prediction
  to early blight, while one raw healthy error changed to late blight. This
  illustrates the early/late tradeoff; these raw counts also include refusals.
- The Google failure cases remain: `eb02` is predicted healthy; `lb02` and `lb04`
  are predicted early blight. There is no Google disease-recognition improvement.
- Of 59 usable potato leaves with unsupported conditions, 8 were falsely accepted
  by both V3 and V6 (13.6%), versus 17 by V5 (28.8%). Other-plant acceptance was
  4/139 for V3/V6 and 13/139 for V5; wrong-crop acceptance was 1/22 versus 2/22.
  There are **no non-plant examples in this particular challenge**, so these
  numbers say nothing about its non-plant rejection quality.

## Execution and reproducibility

- Two epochs completed on the RTX 4060 Laptop GPU, CUDA 11.8 and AMP enabled;
  CPU fallback was forbidden. Standard image decoding and loading remain CPU
  operations. Optimization/validation elapsed time: 523.80 seconds; full train
  stage including setup: 612.39 seconds.
- Validation source-balanced recall increased from 0.801816 to 0.821846. This is
  a selection metric, not an 82% app accuracy claim. Epoch 2 was selected under
  the predeclared rule. PlantSeg validation early remained 5/10; late rose from
  10/13 to 11/13. No test outputs selected an epoch or threshold.
- Calibration used 2,944 rows, inherited validity temperature
  `0.653050816470007` and kept validity minimum `0.5`. Condition temperature was
  `0.5672121643702974`, condition minimum `0.33644003089011953`, energy maximum
  `0.39701815041787447`. Pooled calibration FAR was 1.22%; this did not predict
  adequate unsupported-condition rejection in the diagnostic domain.
- Checkpoint SHA-256:
  `8906b37cbcbfee8579bdefb643e5473eaaf723adbaa09795c26e258b18ca6225`.
- Calibration SHA-256:
  `55197cf91d09b7376a1c9379e1a28cf4c4a11406473218843f93dc04bdd58f1d`.
- Evaluation SHA-256:
  `b208c6447668035b56cbaf27e290241289b5ef7df86c8fb96d6d6a11b8ffd8b3`.
- Machine-readable comparison and paired changes:
  `ml/artifacts/potato_field_v6_condition_only_20260907/comparison.json` and
  `paired_changes.csv`. Reproduction script:
  `ml/scripts/compare_condition_only_v6.py`; it checks identities, paired inputs,
  gate replay and frozen validity outputs before reporting. Preserve the existing
  outputs; the script refuses to overwrite them.
- New V6 runner/comparison/test files pass targeted Ruff checks; `git diff
  --check` passes. This is not a claim that the whole repository is lint-clean.
- No model export or native parity test was performed for V6. ADB reported no
  device after training. The app's unchanged TFLite SHA-256 remains
  `90875fad84d33e06884466030e2dfe18fedc2fd89b5e71a9d61835b837891c69`.

V5 added useful disease-source recognition but worsened unsupported-image
acceptance from 13/220 to 32/220. Replaying its stored logits shows all 19 new
unsupported acceptances crossed the validity gate. Both models' condition and
energy gates passed all 220 unsupported examples. Thus a changed energy cutoff
does not explain those 19 new errors. This experiment isolates changes to that
path; it does not assume all those validity classifications were wrong.

The 19 new unsupported acceptances comprise nine labelled other-plant images,
one wrong-crop leaf, and **nine usable potato leaves with unsupported conditions**.
For the latter, accepting the image as a usable leaf is semantically appropriate;
the disease head's failure to reject an unknown condition is the problem.
Freezing the validity path is therefore a conservative ablation, not a complete
open-set recognition solution. It cannot recover true leaves that V3 rejected.

## Predeclared experiment

- Initialize from the unchanged V3 parent, not the rejected V5.
- Freeze the backbone, shared layers, validity head, batch-normalization running
  statistics and dropout behavior. Train only the 3,843 disease-head parameters.
  A regression test checks all other state tensors and validity outputs remain
  identical after optimizer steps and training-mode transitions.
- Same audited 34,001-row manifest as V5, no additional images or relabelling.
  Reverify every image SHA and all structural checks, reusing only the pinned
  full-decode/pHash evidence for these exact unchanged bytes.
- Two CUDA/AMP epochs, 12,000 draws per epoch, seed 20260908 (a seed identifier,
  not the run date), learning rate 0.0003, existing augmentation/outlier loss.
- Select by equal-source mean condition recall over PLDD and PlantSeg validation.
  Each source must contain at least two classes with ten examples per class.
  The existing aggregate coverage checks still run. This avoids allowing the
  large source to overwhelm the small-source failures observed in V5.
- Verify every non-disease-head tensor against V3 again before calibration.
  Inherit V3's validity temperature from its pinned calibration; never lower its
  validity-probability threshold. Fit the remaining calibration parameters using
  only the unchanged 2,944-image calibration split.
- Compare all 749 photos against the parent and V5. These photos are now
  **consumed diagnostic data**, not an independent V6 validation claim.

This can preserve the existing validity path, not prove that path is correct.
The parent already has false acceptances and source-dependent failures. No
calibration or training result authorizes automatic app promotion, and no phone
is currently connected for native verification.

## Additional calibration limitation

Only nine usable potato leaves with unsupported conditions occur in the current
calibration split, compared with 1,396 total unsupported inputs. A pooled 5% FAR
cap permits all nine to be falsely accepted while still passing overall. The
validation split has no explicit `potato_other_unknown` usable-leaf examples.
Training contains 2,901 such examples, but 2,874 come from one Central Java
source. This is a subgroup-coverage and domain-shift problem, not evidence that
a pooled calibration score is an adequate disease-unknown safety gate.

Do not retrofit thresholds to the 749-photo challenge. A future release needs
separate reporting and adequate calibration coverage for unknown potato
conditions, wrong-crop leaves and non-plant/other-plant inputs, with new untouched
field evaluation. V6 intentionally leaves this calibration design unchanged
apart from preserving the parent validity path, so the ablation stays interpretable.

## What this changes about the next attempt

1. Reject **this** condition-head-only recipe. Its frozen-validity safeguard works,
   but that is not evidence that its disease classifier improved. This one run
   does not prove all linear-head adaptations or architectures must fail.
2. Do not keep selecting checkpoints against the now-consumed 749 photos. Use
   them for failure analysis; obtain a genuinely new, source/group-independent
   field evaluation set before making a release claim.
3. Prioritize expert-reviewed early/late contrast cases, healthy natural-background
   leaves, and unsupported potato disorders. The current new source supplies no
   healthy training examples. Tanzania samples remain quarantined, not relabelled
   by the model or silently used as ground truth.
4. Require unknown-condition subgroup coverage and reporting in validation and
   calibration, not just an aggregate OOD cap. The new comparison tests show that
   a 1% overall unsupported error can conceal 100% failure in a small subgroup.
5. A future representation-adaptation experiment must check both disease-source
   tradeoffs and validity drift. Any successful candidate still needs native
   TFLite parity, real-device capture/gallery checks and untouched Nepal evidence.

The user's model-quality objective remains **unresolved**. This work supplies
completed experiments and falsifiable failure evidence, not a production-ready
model or a promise that additional epochs alone will solve the problem.
