import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

/// The notebook's invariants, enforced at construction so an invalid entry is
/// unrepresentable at rest as well as on screen.
void main() {
  Observation build({
    String imagePath = '/data/photos/a.jpg',
    DateTime? createdAt,
    String? note,
    String? cropKey = 'tomato',
  }) => Observation(
    id: 'id',
    imagePath: imagePath,
    createdAt: createdAt ?? DateTime.utc(2026, 8, 2),
    cropKey: cropKey,
    note: note,
  );

  group('a photograph is not optional', () {
    test('an empty path is refused', () {
      expect(() => build(imagePath: ''), throwsArgumentError);
      expect(() => build(imagePath: '   '), throwsArgumentError);
    });
  });

  group('time is UTC or it is a bug', () {
    test('a local timestamp is refused', () {
      // Same rule as DiagnosisRecord. A notebook sorted by a mixture of local
      // and UTC stamps reorders itself when the farmer crosses a timezone or
      // the phone corrects its clock.
      expect(() => build(createdAt: DateTime(2026, 8, 2)), throwsArgumentError);
    });

    test('UTC is accepted', () {
      expect(build(createdAt: DateTime.utc(2026)).createdAt.isUtc, isTrue);
    });
  });

  group('the note has exactly one representation of "nothing"', () {
    test('null, empty and whitespace all become null', () {
      expect(build(note: null).note, isNull);
      expect(build(note: '').note, isNull);
      expect(build(note: '    ').note, isNull);
      expect(build(note: '\n\t ').note, isNull);
    });

    test('surrounding whitespace is trimmed', () {
      expect(build(note: '  wilting  ').note, 'wilting');
    });

    test('a pathological paste is capped rather than stored whole', () {
      // Storage is the scarce resource on the devices this app targets, and
      // one unbounded row is enough to matter. The cap lives here rather than
      // in a text field's maxLength so that every writer inherits it.
      final long = 'क' * (Observation.maxNoteLength + 500);
      expect(build(note: long).note!.length, Observation.maxNoteLength);
    });

    test('a note exactly at the cap is untouched', () {
      final exact = 'a' * Observation.maxNoteLength;
      expect(build(note: exact).note, exact);
    });
  });

  test('an uncatalogued crop is a normal state, not an error', () {
    // The remembered crop can come from a pack that is no longer installed.
    // Refusing to save the photograph over that would lose the one thing the
    // farmer actually did.
    expect(build(cropKey: null).cropKey, isNull);
  });
}
