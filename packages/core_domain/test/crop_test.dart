import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

final class _Catalog implements CropCatalog {
  @override
  List<Crop> get available => const [Crop('tomato'), Crop('potato')];
}

void main() {
  final catalog = _Catalog();

  test('crops compare by key', () {
    expect(const Crop('tomato'), const Crop('tomato'));
    expect(const Crop('tomato'), isNot(const Crop('potato')));
  });

  group('catalog lookup', () {
    test('resolves a known key', () {
      expect(catalog.byKey('potato'), const Crop('potato'));
    });

    test('returns null for an unknown or absent key', () {
      expect(catalog.byKey('cardamom'), isNull, reason: 'pack not installed');
      expect(catalog.byKey(null), isNull);
    });

    test('fallback is the first available crop', () {
      expect(catalog.fallback, const Crop('tomato'));
    });
  });
}
