# Digital Green development rotations

`compose_development_rotation.py` creates a new manifest for one diagnostic
five-fold rotation. It never changes the sanitized base manifest or fold
sidecar. By default, every group carrying a review, disagreement, missing-data,
or quarantine flag is excluded in full.

For rotation `i`, `dev_fold_i` becomes `external_test`, the next fold (wrapping
after five) becomes `calibration`, and the other three folds become `train`.
Rotated rows use source ID `farmer_chat_india_development_v1`. Every rotated
row has a blank `source_locked_split`: the source intentionally spans training,
calibration, and diagnostic evaluation and must never claim source independence.
The technical split name remains `external_test` for evaluator compatibility,
but it is only a **diagnostic external-development fold**. All other manifest
rows and their hashes are copied unchanged.

```powershell
.\.venv\Scripts\python.exe ml\scripts\compose_development_rotation.py `
  --manifest ml\data\prepared\manifest_field_v3_sanitized.csv `
  --fold-sidecar ml\data\prepared\farmer_chat_india_development_folds_v1.csv `
  --fold-report ml\data\prepared\farmer_chat_india_development_folds_v1.report.json `
  --source-policy ml\datasets\source_evidence_policy_v2.json `
  --rotation 1 `
  --output ml\data\prepared\manifest_field_v3_dg_rotation_1.csv `
  --receipt ml\data\prepared\manifest_field_v3_dg_rotation_1.receipt.json
```

Repeat with separately named outputs for rotations 2 through 5. Never use one
rotation to claim independent external or promotion evidence: Digital Green was
already consumed in product and model decisions. The receipt binds the base,
sidecar, fold report, evidence policy, and generated manifest by SHA-256. It
records exclusions by fold/class plus exact SHA and pHash leakage checks at the
auditor's default Hamming distance of four.

The future v3 fold sidecar **and its report must be regenerated together from
the final sanitized v3 base**. A v2 report cannot authorize a v3 base: hash
verification fails closed. Outputs and receipts must be new paths unless the
operator explicitly supplies `--overwrite`.

The manifest is replaced first and the receipt is written last as its commit
marker. If the second replacement fails, a manifest can remain without a
receipt; it is incomplete and must not be used. The protocol guarantees that a
receipt is never left attesting a different manifest, and temporary files are
cleaned on failure.

`--include-flagged` exists only for explicit diagnostics. It is not the default
and never admits a quarantined group, including a group where a quarantined row
piggybacks beside an otherwise clean row.
