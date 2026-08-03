import 'dart:async';

/// A photograph a farmer chose to keep, with a date and nothing else claimed.
///
/// This is deliberately NOT a [DiagnosisRecord] with the answer left out, and
/// the separation is the whole point. A diagnosis asserts something about a
/// plant; an observation asserts only that this photograph was taken on this
/// day, of this crop, by this person. Nothing about it is a statement the app
/// could be wrong about.
///
/// That distinction is what lets the notebook ship before a trained model
/// exists. ADR-0052 forbids distributing a build that can render a sample
/// diagnosis, and forbids advice attached to one; an observation creates no
/// diagnosis, so it sits outside those prohibitions entirely rather than
/// needing an exemption from them.
///
/// It also means the sealed tri-state [ResultState] stays about diagnoses. A
/// fourth "no answer yet" state would have made every exhaustive switch in the
/// app carry a case that is not a certainty at all.
final class Observation {
  Observation({
    required this.id,
    required this.imagePath,
    required this.createdAt,
    this.cropKey,
    String? note,
  }) : note = _normaliseNote(note) {
    if (imagePath.trim().isEmpty) {
      throw ArgumentError.value(
        imagePath,
        'imagePath',
        'an observation without its photograph is not an observation',
      );
    }
    if (!createdAt.isUtc) {
      throw ArgumentError.value(createdAt, 'createdAt', 'must be UTC');
    }
  }

  /// Client-generated UUIDv7 (D-11): identity exists offline at birth, and
  /// the timestamp prefix means insertion order survives a clock change.
  final String id;

  /// Device-local path of the prepared derivative (D-12): oriented,
  /// downscaled, and with every EXIF tag cleared before it was written.
  final String imagePath;

  final DateTime createdAt;

  /// Null when the crop catalogue could not name it, which is a real state on
  /// a device whose remembered crop came from an uninstalled pack.
  final String? cropKey;

  /// One line in the farmer's own words. Null rather than empty, so "no note"
  /// has exactly one representation in the database and in every comparison.
  final String? note;

  /// Trimmed, emptied-to-null, and capped.
  ///
  /// The cap is not a UI concern duplicated here: it is the guarantee that one
  /// pathological paste cannot make a row unbounded on a device where storage
  /// is the scarce resource.
  static const int maxNoteLength = 500;

  static String? _normaliseNote(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length <= maxNoteLength
        ? trimmed
        : trimmed.substring(0, maxNoteLength);
  }
}

/// Port for the field notebook (D-42 severability: the domain owns the
/// contract, core_data owns the Drift implementation).
abstract interface class ObservationStore {
  Future<void> upsert(Observation observation);

  Future<Observation?> byId(String id);

  /// Newest first.
  Future<List<Observation>> recent({int limit = 50});

  /// Reactive newest-first window, so a new photograph appears in the
  /// notebook without the screen being told to look again.
  Stream<List<Observation>> watchRecent({int limit = 50});

  /// Removes the row. The photo file is the caller's to delete: the store
  /// owns rows, and a port that reached into the filesystem would be a second
  /// owner of the same bytes.
  Future<void> delete(String id);
}
