import 'dart:math' as math;
import 'dart:ui';
import 'package:image/image.dart' as img;

/// All stored ROIs are in EXIF-normalized image pixels, not screen pixels.
class ImageGeometry {
  final Size imageSize;
  final Size viewport;
  late final double scale;
  late final Offset offset;
  ImageGeometry(this.imageSize, this.viewport, {bool cover = false}) {
    if (imageSize.isEmpty ||
        viewport.isEmpty ||
        !imageSize.width.isFinite ||
        !imageSize.height.isFinite ||
        !viewport.width.isFinite ||
        !viewport.height.isFinite) {
      throw ArgumentError(
        'Image and viewport dimensions must be positive and finite.',
      );
    }
    final sx = viewport.width / imageSize.width;
    final sy = viewport.height / imageSize.height;
    scale = cover ? math.max(sx, sy) : math.min(sx, sy);
    offset = Offset(
      (viewport.width - imageSize.width * scale) / 2,
      (viewport.height - imageSize.height * scale) / 2,
    );
  }
  Rect toImage(Rect screen) => Rect.fromLTRB(
    ((screen.left - offset.dx) / scale).clamp(0, imageSize.width),
    ((screen.top - offset.dy) / scale).clamp(0, imageSize.height),
    ((screen.right - offset.dx) / scale).clamp(0, imageSize.width),
    ((screen.bottom - offset.dy) / scale).clamp(0, imageSize.height),
  );
  Rect toScreen(Rect image) => Rect.fromLTRB(
    image.left * scale + offset.dx,
    image.top * scale + offset.dy,
    image.right * scale + offset.dx,
    image.bottom * scale + offset.dy,
  );

  static Rect pixelBounds(img.Image image, Rect roi) {
    if (!roi.isFinite ||
        roi.isEmpty ||
        roi.left < 0 ||
        roi.top < 0 ||
        roi.right > image.width ||
        roi.bottom > image.height) {
      throw ArgumentError(
        'Region must be entirely inside the normalized image.',
      );
    }
    return Rect.fromLTRB(
      roi.left.floorToDouble(),
      roi.top.floorToDouble(),
      roi.right.ceilToDouble(),
      roi.bottom.ceilToDouble(),
    );
  }

  static img.Image crop(img.Image image, Rect roi) {
    final r = pixelBounds(image, roi);
    return img.copyCrop(
      image,
      x: r.left.toInt(),
      y: r.top.toInt(),
      width: r.width.toInt(),
      height: r.height.toInt(),
    );
  }
}
