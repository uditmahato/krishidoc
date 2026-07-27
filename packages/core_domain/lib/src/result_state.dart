/// Diagnosis outcome states (D-17).
///
/// Every rendered diagnosis carries exactly one of these; UI components that
/// display a diagnosis without a state do not exist by design.
enum ResultState {
  /// Top-1 prediction cleared its calibrated per-class threshold.
  confident,

  /// Below threshold or tiers disagreed: show top-3 and escalation.
  uncertain,

  /// Failed the crop-plausibility or capture-quality gate: no diagnosis.
  outOfScope;

  /// Whether the plant-clinic escalation path must be surfaced (D-07, D-17).
  bool get requiresEscalation => this != confident;

  /// Whether advisory content may be attached to this result (D-21: advice
  /// attaches only to a confident diagnosis; uncertain shows alternatives).
  bool get allowsAdvisory => this == confident;
}
