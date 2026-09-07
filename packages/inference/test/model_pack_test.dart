import 'package:inference/inference.dart';
import 'package:test/test.dart';

const _manifest = '''
{
  "cropKey": "tomato",
  "modelVersion": "tomato-v1.2.0",
  "thresholdSetVersion": "ts-2026-07",
  "temperature": 2.0,
  "rejectionFloor": 0.40,
  "minMargin": 0.10,
  "labels": [
    {"key": "tomato_late_blight", "kind": "disease", "threshold": 0.72},
    {"key": "tomato_early_blight", "kind": "disease", "threshold": 0.75},
    {"key": "tomato_healthy", "kind": "healthy", "threshold": 0.80}
  ]
}
''';

ModelPack packWith({
  double temperature = 1,
  List<LabelSpec>? labels,
  double rejectionFloor = 0.6,
  double minMargin = 0.1,
}) => ModelPack(
  cropKey: 'tomato',
  modelVersion: 'm1',
  thresholdSetVersion: 't1',
  temperature: temperature,
  rejectionFloor: rejectionFloor,
  minMargin: minMargin,
  labels:
      labels ??
      const [
        LabelSpec(key: 'a', kind: LabelKind.disease, threshold: 0.7),
        LabelSpec(key: 'b', kind: LabelKind.disease, threshold: 0.7),
      ],
);

void main() {
  group('parsing', () {
    test('reads a complete manifest', () {
      final pack = ModelPack.parse(_manifest);

      expect(pack.cropKey, 'tomato');
      expect(pack.modelVersion, 'tomato-v1.2.0');
      expect(pack.thresholdSetVersion, 'ts-2026-07');
      expect(pack.temperature, 2.0);
      expect(pack.labelCount, 3);
      expect(pack.labels.last.kind, LabelKind.healthy);
      expect(pack.labels.first.threshold, closeTo(0.72, 1e-9));
    });

    test('applies documented defaults for optional calibration fields', () {
      final pack = ModelPack.parse('''
      {
        "cropKey": "maize",
        "modelVersion": "m1",
        "thresholdSetVersion": "t1",
        "labels": [
          {"key": "a", "kind": "disease", "threshold": 0.7},
          {"key": "b", "kind": "disease", "threshold": 0.7}
        ]
      }
      ''');

      expect(pack.temperature, 1);
      expect(pack.rejectionFloor, closeTo(0.75, 1e-9)); // 1.5 / 2 labels
      expect(pack.minMargin, closeTo(0.1, 1e-9));
    });

    test('rejects malformed manifests rather than loading them partially', () {
      const cases = <String, String>{
        'not json': 'nonsense',
        'not an object': '[1, 2, 3]',
        'missing modelVersion':
            '{"cropKey":"c","thresholdSetVersion":"t",'
            '"labels":[{"key":"a","kind":"disease","threshold":0.7}]}',
        'empty labels':
            '{"cropKey":"c","modelVersion":"m","thresholdSetVersion":"t",'
            '"labels":[]}',
        'unknown kind':
            '{"cropKey":"c","modelVersion":"m","thresholdSetVersion":"t",'
            '"labels":[{"key":"a","kind":"mystery","threshold":0.7},'
            '{"key":"b","kind":"disease","threshold":0.7}]}',
        'threshold missing':
            '{"cropKey":"c","modelVersion":"m","thresholdSetVersion":"t",'
            '"labels":[{"key":"a","kind":"disease"},'
            '{"key":"b","kind":"disease","threshold":0.7}]}',
        'single label is not a classifier':
            '{"cropKey":"c","modelVersion":"m","thresholdSetVersion":"t",'
            '"labels":[{"key":"a","kind":"disease","threshold":0.7}]}',
        'rejection floor at or below chance level can never fire':
            '{"cropKey":"c","modelVersion":"m","thresholdSetVersion":"t",'
            '"rejectionFloor":0.5,'
            '"labels":[{"key":"a","kind":"disease","threshold":0.7},'
            '{"key":"b","kind":"disease","threshold":0.7}]}',
        'threshold out of range':
            '{"cropKey":"c","modelVersion":"m","thresholdSetVersion":"t",'
            '"labels":[{"key":"a","kind":"disease","threshold":1.5},'
            '{"key":"b","kind":"disease","threshold":0.7}]}',
        'duplicate labels':
            '{"cropKey":"c","modelVersion":"m","thresholdSetVersion":"t",'
            '"labels":[{"key":"a","kind":"disease","threshold":0.7},'
            '{"key":"a","kind":"disease","threshold":0.8}]}',
      };

      for (final entry in cases.entries) {
        expect(
          () => ModelPack.parse(entry.value),
          throwsA(isA<ModelPackFormatException>()),
          reason: entry.key,
        );
      }
    });

    test('rejects invalid calibration constants', () {
      expect(
        () => packWith(temperature: 0),
        throwsA(isA<ModelPackFormatException>()),
      );
      expect(
        () => packWith(rejectionFloor: 1),
        throwsA(isA<ModelPackFormatException>()),
      );
      expect(
        () => packWith(minMargin: -0.1),
        throwsA(isA<ModelPackFormatException>()),
      );
    });
  });

  group('calibration', () {
    test('softmax sums to one and preserves order', () {
      final probabilities = packWith().calibrate([2, 1]);

      expect(probabilities.reduce((a, b) => a + b), closeTo(1, 1e-9));
      expect(probabilities.first, greaterThan(probabilities.last));
    });

    test('temperature above one softens overconfidence', () {
      const logits = [4.0, 1.0];
      final sharp = packWith().calibrate(logits).first;
      final softened = packWith(temperature: 4).calibrate(logits).first;

      expect(softened, lessThan(sharp));
      expect(softened, greaterThan(0.5), reason: 'order must survive');
    });

    test('large logits do not overflow to NaN', () {
      final probabilities = packWith().calibrate([1000, 999]);

      expect(probabilities.every((p) => p.isFinite), isTrue);
      expect(probabilities.reduce((a, b) => a + b), closeTo(1, 1e-9));
    });

    test('rejects a logit count that disagrees with the pack', () {
      expect(
        () => packWith().calibrate([1, 2, 3]),
        throwsA(isA<ModelPackFormatException>()),
      );
    });

    test('rejects non-finite model output instead of ranking it', () {
      expect(
        () => packWith().calibrate([double.nan, 1]),
        throwsA(isA<ModelPackFormatException>()),
      );
      expect(
        () => packWith().calibrate([double.infinity, 1]),
        throwsA(isA<ModelPackFormatException>()),
      );
    });
  });
}
