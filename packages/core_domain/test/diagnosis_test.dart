import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

void main() {
  group('TopPrediction', () {
    test('rejects out-of-range confidence', () {
      expect(
        () => TopPrediction(label: 'x', confidence: 1.2),
        throwsArgumentError,
      );
      expect(
        () => TopPrediction(label: 'x', confidence: -0.1),
        throwsArgumentError,
      );
      expect(
        () => TopPrediction(label: 'x', confidence: double.nan),
        throwsArgumentError,
      );
    });

    test('rejects empty label and survives a JSON round trip', () {
      expect(
        () => TopPrediction(label: '  ', confidence: 0.5),
        throwsArgumentError,
      );
      final original = TopPrediction(label: 'late_blight', confidence: 0.91);
      expect(TopPrediction.fromJson(original.toJson()), equals(original));
    });
  });

  group('DiagnosisRecord invariants (D-17)', () {
    DateTime utcNow() => DateTime.now().toUtc();

    List<TopPrediction> predictions(int count) => [
      for (var i = 0; i < count; i++)
        TopPrediction(label: 'label_$i', confidence: 0.5),
    ];

    test('confident requires at least one prediction', () {
      expect(
        () => DiagnosisRecord(
          id: 'a',
          state: ResultState.confident,
          predictions: const [],
          modelVersion: 'm1',
          createdAt: utcNow(),
        ),
        throwsArgumentError,
      );
    });

    test('uncertain requires at least two predictions', () {
      expect(
        () => DiagnosisRecord(
          id: 'a',
          state: ResultState.uncertain,
          predictions: predictions(1),
          modelVersion: 'm1',
          createdAt: utcNow(),
        ),
        throwsArgumentError,
      );
    });

    test('out-of-scope allows zero predictions', () {
      final record = DiagnosisRecord(
        id: 'a',
        state: ResultState.outOfScope,
        predictions: const [],
        modelVersion: 'm1',
        createdAt: utcNow(),
      );
      expect(record.predictions, isEmpty);
    });

    test('createdAt must be UTC', () {
      expect(
        () => DiagnosisRecord(
          id: 'a',
          state: ResultState.confident,
          predictions: predictions(1),
          modelVersion: 'm1',
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });
  });
}
