# ADR-0059: Gallery import and confirmed crop suggestions

- Status: accepted for the user-requested development build
- Date: 2026-09-06
- Amends: D-16's remembered-crop capture interaction
- Preserves: D-56/D-58 experimental possible-match boundary

## Decision

Both capture screens expose a system gallery picker, including the camera
permission-denied state. Disease imports are prepared with the shared image
processor, then assessed for blur and exposure before model execution. Picker
cancellation, rejected photo quality, and dismissed photo review save no
diagnosis. Camera pause/resume follows picker, review, route and app lifecycle.
An Android selection recovered after process reclamation is reviewed when the
farmer next opens capture. Only the explicitly selected image is imported.

Disease capture defaults to automatic crop suggestion, using the existing
global 38-class model. Unsupported crop classes stay in the scoring tensor.
The global winning condition must belong to tomato, potato or maize; summed
probability for that crop must be at least 0.70 and exceed the strongest other
crop by at least 0.15. These are provisional usability heuristics, not calibrated
confidence or field-accuracy measurements. The model has no reliable non-plant
class, so even a passing crop suggestion always needs user confirmation.

The review shows the photo and a suggested crop that can be corrected. An
ambiguous/unsupported output or failed identification leaves all crops
unselected and disables analysis until the farmer chooses. Confirmation routes
potato to the calibrated dual-head EfficientNet model and tomato/maize to the
existing crop-scoped global classifier. Crop-specific rejection remains intact.
Manual selection remains available; automatic suggestions do not silently
overwrite the remembered crop used by other app features.

## Verification and limits

Tests cover correction, unknown crops, cancellation, recovery, camera denial,
unusable photos, malformed model output and layouts at 320px with 2x text in
en/ne/hi. Realme runtime tests exercise both bundled models. That confirms
native execution, not agricultural accuracy. Nepal field evaluation and native
review of new ne/hi strings remain outstanding. This change does not add an iOS
build target or claim iPhone testing.
