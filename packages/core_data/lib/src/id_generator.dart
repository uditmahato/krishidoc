import 'package:uuid/uuid.dart';

/// UUIDv7 minting (D-11): time-ordered for index locality, born offline.
final class IdGenerator {
  const IdGenerator();

  static const Uuid _uuid = Uuid();

  String newId() => _uuid.v7();
}
