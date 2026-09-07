/// Consent scopes (D-31, D-44, D-45).
///
/// Scopes are independent grants, not an ordered ladder: [research] does not
/// imply [preciseLocation] and vice versa. [baseline] is always present for a
/// functioning install and is not revocable separately from deleting the app.
/// The authoritative consent state lives server-side behind compare-and-set
/// versioning (D-44); client code treats granted scopes as a read model and
/// must re-verify server-side at execution time for consent-dependent work
/// (D-45).
enum ConsentScope {
  /// Operational telemetry, crash reporting, coarse region.
  baseline,

  /// Research linkage: image derivatives/originals and longitudinal pseudonym.
  research,

  /// Plot-level location for referrals and future locality-aware advisories.
  preciseLocation,
}
