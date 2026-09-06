import 'package:inference/inference.dart';
import 'package:test/test.dart';

void main() {
  test('pins the trained potato label and tensor order', () {
    expect(PotatoFieldResearchPack.validityLabelKeys, const [
      'usable_target_leaf',
      'unsuitable_target_crop_view',
      'wrong_crop_leaf',
      'other_plant',
      'non_plant',
    ]);
    expect(PotatoFieldResearchPack.conditionLabelKeys, const [
      'potato_early_blight',
      'potato_late_blight',
      'potato_healthy',
    ]);
    expect(
      PotatoFieldResearchPack.pack.labels.map((label) => label.key),
      PotatoFieldResearchPack.conditionLabelKeys,
    );
  });

  test('cannot produce a confirmed diagnosis before Nepal validation', () {
    expect(
      PotatoFieldResearchPack.pack.decisionMode,
      ModelDecisionMode.possibleMatchOnly,
    );
    expect(
      isExperimentalModelVersion(PotatoFieldResearchPack.modelVersion),
      isTrue,
    );
  });

  test('pins artifact, checkpoint, calibration, and manifest identities', () {
    expect(PotatoFieldResearchPack.artifactSha256, hasLength(64));
    expect(PotatoFieldResearchPack.checkpointSha256, hasLength(64));
    expect(PotatoFieldResearchPack.calibrationSha256, hasLength(64));
    expect(PotatoFieldResearchPack.manifestSha256, hasLength(64));
  });
}
