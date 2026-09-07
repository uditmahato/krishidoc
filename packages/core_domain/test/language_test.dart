import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

void main() {
  group('AppLanguage.fromCode', () {
    test('parses launch languages case-insensitively with whitespace', () {
      expect(AppLanguage.fromCode('en'), AppLanguage.en);
      expect(AppLanguage.fromCode(' NE '), AppLanguage.ne);
      expect(AppLanguage.fromCode('Hi'), AppLanguage.hi);
    });

    test('returns null for unknown or cut languages (D-06)', () {
      expect(AppLanguage.fromCode('ar'), isNull);
      expect(AppLanguage.fromCode('fr'), isNull);
      expect(AppLanguage.fromCode('de'), isNull);
      expect(AppLanguage.fromCode(''), isNull);
      expect(AppLanguage.fromCode(null), isNull);
    });

    test('codes are unique', () {
      final codes = AppLanguage.values.map((l) => l.code).toSet();
      expect(codes.length, AppLanguage.values.length);
    });
  });
}
