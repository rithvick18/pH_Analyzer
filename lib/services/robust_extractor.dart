import 'package:image/image.dart' as img;

class RobustColorExtractor {
  /// Extracts the robust mean RGB color of [patch] by filtering out intensity
  /// outliers outside the 5th and 95th percentiles of grayscale intensity.
  /// Returns [R, G, B] as integers in [0..255].
  static List<int> extract(img.Image patch) {
    if (patch.width <= 0 || patch.height <= 0) {
      return [0, 0, 0];
    }

    final int totalPixels = patch.width * patch.height;
    final List<double> grays = [];
    final List<_PixelData> allPixels = [];

    for (final p in patch) {
      final num r = p.r;
      final num g = p.g;
      final num b = p.b;
      final double gray = 0.299 * r + 0.587 * g + 0.114 * b;
      grays.add(gray);
      allPixels.add(_PixelData(r.toDouble(), g.toDouble(), b.toDouble(), gray));
    }

    grays.sort();
    final double p5 = grays[(totalPixels * 0.05).floor().clamp(0, totalPixels - 1)];
    final double p95 = grays[(totalPixels * 0.95).floor().clamp(0, totalPixels - 1)];

    double sumR = 0;
    double sumG = 0;
    double sumB = 0;
    int count = 0;

    // Filter pixels within [p5, p95]
    for (final pd in allPixels) {
      if (pd.gray >= p5 && pd.gray <= p95) {
        sumR += pd.r;
        sumG += pd.g;
        sumB += pd.b;
        count++;
      }
    }

    // Fallback to simple mean of the whole patch if mask contains no pixels or p5 == p95
    if (count == 0) {
      sumR = 0;
      sumG = 0;
      sumB = 0;
      for (final pd in allPixels) {
        sumR += pd.r;
        sumG += pd.g;
        sumB += pd.b;
      }
      count = totalPixels;
    }

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
