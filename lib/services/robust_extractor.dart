import 'package:image/image.dart' as img;

class RobustColorExtractor {
  /// Extracts the robust mean RGB color of [patch] by sorting pixels by relative
  /// luminance (0.299*R + 0.587*G + 0.114*B), discarding the top 5% brightest
  /// (specular glare) and bottom 5% darkest (shadows), and computing the mean
  /// RGB of the remaining middle 90%.
  /// Returns [R, G, B] as integers in [0..255].
  static List<int> extract(img.Image patch) {
    if (patch.width <= 0 || patch.height <= 0 || patch.isEmpty) {
      return [0, 0, 0];
    }

    final List<_PixelData> allPixels = [];

    for (final p in patch) {
      final num r = p.r;
      final num g = p.g;
      final num b = p.b;
      final double gray = 0.299 * r + 0.587 * g + 0.114 * b;
      allPixels.add(_PixelData(r.toDouble(), g.toDouble(), b.toDouble(), gray));
    }

    if (allPixels.isEmpty) {
      return [0, 0, 0];
    }

    // Sort pixels by relative luminance
    allPixels.sort((a, b) => a.gray.compareTo(b.gray));

    final int totalPixels = allPixels.length;
    final int startIdx = (totalPixels * 0.05).floor().clamp(0, totalPixels - 1);
    final int endIdx = (totalPixels * 0.95).floor().clamp(startIdx + 1, totalPixels);

    final List<_PixelData> trimmedPixels = allPixels.sublist(startIdx, endIdx);
    final List<_PixelData> targetPixels = trimmedPixels.isNotEmpty ? trimmedPixels : allPixels;

    double sumR = 0;
    double sumG = 0;
    double sumB = 0;

    for (final pd in targetPixels) {
      sumR += pd.r;
      sumG += pd.g;
      sumB += pd.b;
    }

    final int count = targetPixels.length;
    return [
      (sumR / count).round().clamp(0, 255),
      (sumG / count).round().clamp(0, 255),
      (sumB / count).round().clamp(0, 255),
    ];
  }
}

class _PixelData {
  final double r;
  final double g;
  final double b;
  final double gray;

  _PixelData(this.r, this.g, this.b, this.gray);
}
