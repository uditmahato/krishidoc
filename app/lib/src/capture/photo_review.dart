import 'dart:isolate';
import 'dart:typed_data';

import 'package:capture/capture.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../l10n/gen/app_localizations.dart';
import 'capture_screen.dart' show cropName;

typedef GalleryQualityCheck = Future<CaptureQuality> Function(Uint8List image);
final galleryQualityProvider = Provider<GalleryQualityCheck>(
  (ref) =>
      (bytes) => Isolate.run(() => assessGalleryPhoto(bytes)),
);

CaptureQuality assessGalleryPhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width < 32 || decoded.height < 32) {
    throw const FormatException('Image is missing or too small');
  }
  final image = img.copyResize(
    decoded,
    width: decoded.width >= decoded.height ? 256 : null,
    height: decoded.height > decoded.width ? 256 : null,
    interpolation: img.Interpolation.average,
  );
  final luminance = Uint8List(image.width * image.height);
  var index = 0;
  for (final pixel in image) {
    luminance[index++] = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
        .round();
  }
  return const QualityGate().assess(
    luminance,
    width: image.width,
    height: image.height,
  );
}

/// Photo and crop are confirmed together; dismissal never saves a diagnosis.
class PhotoReviewSheet extends StatefulWidget {
  const PhotoReviewSheet({
    required this.image,
    required this.initialCrop,
    required this.automatic,
    this.blurWarning = false,
    super.key,
  });

  final Uint8List image;
  final String? initialCrop;
  final bool automatic;
  final bool blurWarning;

  @override
  State<PhotoReviewSheet> createState() => _PhotoReviewSheetState();
}

class _PhotoReviewSheetState extends State<PhotoReviewSheet> {
  late String? _crop = widget.initialCrop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.reviewLeafPhoto,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                widget.image,
                height: 180,
                fit: BoxFit.contain,
                errorBuilder: (_, error, stack) => const SizedBox(height: 32),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.blurWarning) ...[
              Text(
                l10n.galleryBlurWarning,
                key: const Key('review.qualityWarning'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
            ],
            Text(
              widget.automatic
                  ? widget.initialCrop == null
                        ? l10n.cropNotRecognized
                        : l10n.cropSuggested(
                            cropName(l10n, Crop(widget.initialCrop!)),
                          )
                  : l10n.confirmCrop,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in ['tomato', 'potato', 'maize'])
                  ChoiceChip(
                    key: Key('review.crop.$key'),
                    label: Text(cropName(l10n, Crop(key))),
                    selected: _crop == key,
                    onSelected: (_) => setState(() => _crop = key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('review.analyze'),
              onPressed: _crop == null
                  ? null
                  : () => Navigator.of(context).pop(_crop),
              child: Text(
                widget.blurWarning ? l10n.analyzeAnyway : l10n.analyzeLeaf,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.chooseAnotherPhoto),
            ),
          ],
        ),
      ),
    );
  }
}
