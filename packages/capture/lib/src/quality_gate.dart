import 'dart:typed_data';

/// Why a frame is not good enough to classify. The app maps these to
/// localized coaching text ("move closer", "find better light"); this layer
/// stays language-free.
enum CaptureIssue { tooBlurry, tooDark, tooBright }

/// Outcome of assessing one camera frame.
final class CaptureQuality {
  const CaptureQuality({
    required this.issues,
    required this.edgeEnergy,
    required this.meanLuminance,
  });

  /// Empty when the frame is good enough to capture.
  final List<CaptureIssue> issues;

  /// Mean absolute Laplacian across sampled pixels: average edge strength in
  /// luminance units. Flat or out-of-focus frames trend toward zero.
  final double edgeEnergy;

  /// Mean luminance across sampled pixels, 0 to 255.
  final double meanLuminance;

  bool get isAcceptable => issues.isEmpty;
}

/// Assesses camera preview frames against blur and exposure floors.
///
/// Works on the luminance (Y) plane straight from the camera, so no image
/// decoding is involved: that is what keeps this inside the per-frame budget
/// on low-end devices (D-16). [stride] samples every Nth pixel in both axes;
/// the Laplacian kernel still reads immediate neighbours, so detail is not
/// smoothed away by sampling.
///
/// Blur is scored as the mean *absolute* Laplacian rather than its variance.
/// The textbook recipe uses variance, but it computes that over every pixel;
/// once frames are subsampled for the frame budget, a regular texture (a
/// woven mat, a mesh screen, a checkerboard) can alias so that every sampled
/// Laplacian carries the same sign, driving variance to zero and declaring a
/// perfectly sharp frame blurry. Mean absolute Laplacian has no such
/// cancellation, and is cheaper.
///
/// Thresholds are provisional and must be calibrated in the reference-device
/// lab against real field photos before launch (open question in
/// PROJECT_MEMORY); they are deliberately lenient so that a real diseased
/// leaf is never refused for being slightly soft.
final class QualityGate {
  const QualityGate({
    this.minEdgeEnergy = 8,
    this.minMeanLuminance = 40,
    this.maxMeanLuminance = 220,
    this.stride = 2,
  }) : assert(stride >= 1, 'stride must be at least 1');

  final double minEdgeEnergy;
  final double minMeanLuminance;
  final double maxMeanLuminance;
  final int stride;

  /// Assesses one frame.
  ///
  /// [bytesPerRow] defaults to [width] but must be passed through from the
  /// camera when it differs: Android pads YUV plane rows up to an alignment
  /// boundary, so a 1284-wide frame commonly arrives with a 1312-byte row.
  /// Assuming tight packing reads each row shifted a little further than the
  /// last, which turns a sharp frame into diagonal noise and quietly breaks
  /// every measurement taken from it.
  CaptureQuality assess(
    Uint8List luminance, {
    required int width,
    required int height,
    int? bytesPerRow,
  }) {
    final rowStride = bytesPerRow ?? width;
    if (width < 3 || height < 3) {
      throw ArgumentError('frame must be at least 3x3, got ${width}x$height');
    }
    if (rowStride < width) {
      throw ArgumentError(
        'bytesPerRow ($rowStride) cannot be smaller than width ($width)',
      );
    }
    if (luminance.length < rowStride * height) {
      throw ArgumentError(
        'luminance plane holds ${luminance.length} bytes, '
        'expected at least ${rowStride * height}',
      );
    }

    var samples = 0;
    var luminanceSum = 0.0;
    var absLaplacianSum = 0.0;

    // Interior pixels only: the kernel needs all four neighbours.
    for (var y = 1; y < height - 1; y += stride) {
      final rowStart = y * rowStride;
      for (var x = 1; x < width - 1; x += stride) {
        final centre = luminance[rowStart + x];
        final laplacian =
            4 * centre -
            luminance[rowStart - rowStride + x] -
            luminance[rowStart + rowStride + x] -
            luminance[rowStart + x - 1] -
            luminance[rowStart + x + 1];

        samples++;
        luminanceSum += centre;
        absLaplacianSum += laplacian.abs();
      }
    }

    final mean = luminanceSum / samples;
    final edgeEnergy = absLaplacianSum / samples;

    final issues = <CaptureIssue>[
      if (edgeEnergy < minEdgeEnergy) CaptureIssue.tooBlurry,
      if (mean < minMeanLuminance) CaptureIssue.tooDark,
      if (mean > maxMeanLuminance) CaptureIssue.tooBright,
    ];

    return CaptureQuality(
      issues: issues,
      edgeEnergy: edgeEnergy,
      meanLuminance: mean,
    );
  }
}
