import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Jurisdiction.fromCode', () {
    test('parses ISO codes case-insensitively', () {
      expect(Jurisdiction.fromCode('NP'), Jurisdiction.nepal);
      expect(Jurisdiction.fromCode('np'), Jurisdiction.nepal);
      expect(Jurisdiction.fromCode(' in '), Jurisdiction.india);
    });

    test('returns null for unknown codes: no silent fallback jurisdiction', () {
      expect(Jurisdiction.fromCode('BD'), isNull);
      expect(Jurisdiction.fromCode('both'), isNull);
      expect(Jurisdiction.fromCode(null), isNull);
    });
  });
}
