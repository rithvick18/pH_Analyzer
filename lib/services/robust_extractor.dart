import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class RobustColorExtractor {
  /// Luminance-histogram trimmed mean with bounded memory, discarding 5% at
  /// either end. Partial boundary bins are weighted evenly (no scan-order bias).
  static List<int> extract(img.Image patch) {
    if (patch.isEmpty) {
      throw ArgumentError('Cannot extract color from an empty patch.');
    }
    const bins = 4096;
    final counts = Uint32List(bins);
    final reds = Float64List(bins);
    final greens = Float64List(bins);
    final blues = Float64List(bins);
    for (final pixel in patch) {
      final r = pixel.r.toDouble();
      final g = pixel.g.toDouble();
      final b = pixel.b.toDouble();
      final index = ((0.299 * r + 0.587 * g + 0.114 * b) * 16).floor().clamp(
        0,
        bins - 1,
      );
      counts[index]++;
      reds[index] += r;
      greens[index] += g;
      blues[index] += b;
    }
    final total = patch.width * patch.height;
    final start = (total * .05).floor();
    final end = math.max(start + 1, (total * .95).floor());
    var position = 0;
    var kept = 0;
    double red = 0, green = 0, blue = 0;
    for (var i = 0; i < bins; i++) {
      final count = counts[i];
      if (count == 0) continue;
      final overlap = math.max(
        0,
        math.min(position + count, end) - math.max(position, start),
      );
      if (overlap > 0) {
        final weight = overlap / count;
        red += reds[i] * weight;
        green += greens[i] * weight;
        blue += blues[i] * weight;
        kept += overlap.toInt();
      }
      position += count;
      if (position >= end) break;
    }
    return [
      (red / kept).round().clamp(0, 255),
      (green / kept).round().clamp(0, 255),
      (blue / kept).round().clamp(0, 255),
    ];
  }
}
