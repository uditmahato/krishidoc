# ADR-0060: Visible capture controls and training-compatible preprocessing

- Status: accepted for the user-requested experimental development build
- Date: 2026-09-06
- Amends: D-59 gallery quality handling and control placement
- Preserves: D-56/D-58 possible-match-only and no-treatment boundaries

## Evidence and decision

The [237-input audit](../MOBILE_MODEL_AUDIT_2026-09-06.md) found a training/mobile
resize mismatch and a whole-image blur gate that vetoed source-labelled usable
leaves. It did not establish deployable field accuracy.

Place labelled Gallery and Capture buttons beside each other in a fixed bottom
bar, including camera denial. Keep import failures visible there. For gallery
blur alone, display an explicit warning and allow user-confirmed checking;
automatic crop inference is skipped before this warning. Exposure failures,
invalid dimensions and undecodable photos still stop the flow. A warning does
not save a record or assert that the photo is suitable. Dismissal saves nothing.

Use a training-compatible antialiased RGB triangle resampler for the potato
model, guarded by exact numerical fixtures. Keep model weights and calibration
fixed; do not exploit aliasing as an accidental rejection filter or tune on this
diagnostic set. False acceptance remains a material limitation.

Native diagnostic targets use a distinct application ID, verified from the
built APK. Audit assets must never appear in the normal release. Device tests
that stop early are incomplete, not passed accuracy evaluations. Further field
data and native parity testing are required before stronger claims.
