import 'dart:math' as math;
import 'dart:ui' show Rect;
import 'package:image/image.dart' as img;
import '../models/calibration_data.dart';
import 'ph_analyzer.dart';
import 'robust_extractor.dart';
import 'strip_validator_service.dart';

/// Finds a compact, approximately rectangular dye patch without inspecting the
/// surrounding surface. A color match alone is insufficient: unrelated objects
/// can share a calibration color, so callers must keep results unvalidated.
class AutomaticDyeDetector {
  static Rect? detect(img.Image image, CalibrationData calibration) {
    final scale = math.max(image.width, image.height) / 160;
    final width = math.max(1, (image.width / scale).round());
    final height = math.max(1, (image.height / scale).round());
    final small = img.copyResize(image, width: width, height: height);
    final anchors = calibration.anchors.map((a) => a.dyeRgb).toList();
    final mask = List<bool>.filled(width * height, false);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = small.getPixel(x, y);
        final r = p.r.toDouble(), g = p.g.toDouble(), b = p.b.toDouble();
        final luma = .299 * r + .587 * g + .114 * b;
        if (luma < 40 || luma > 230) continue;
        mask[y * width + x] = anchors.any((a) {
          final dr = r - a[0], dg = g - a[1], db = b - a[2];
          return dr * dr + dg * dg + db * db < 38 * 38;
        });
      }
    }

    final seen = List<bool>.filled(mask.length, false);
    Rect? best;
    var bestScore = double.negativeInfinity;
    for (var start = 0; start < mask.length; start++) {
      if (!mask[start] || seen[start]) continue;
      final queue = <int>[start];
      seen[start] = true;
      var left = width, top = height, right = 0, bottom = 0;
      for (var head = 0; head < queue.length; head++) {
        final index = queue[head], x = index % width, y = index ~/ width;
        left = math.min(left, x);
        top = math.min(top, y);
        right = math.max(right, x);
        bottom = math.max(bottom, y);
        for (final neighbor in [
          if (x > 0) index - 1,
          if (x + 1 < width) index + 1,
          if (y > 0) index - width,
          if (y + 1 < height) index + width,
        ]) {
          if (mask[neighbor] && !seen[neighbor]) {
            seen[neighbor] = true;
            queue.add(neighbor);
          }
        }
      }
      final boxWidth = right - left + 1, boxHeight = bottom - top + 1;
      final boxArea = boxWidth * boxHeight;
      final fraction = boxArea / mask.length;
      final aspect = boxWidth / boxHeight;
      if (fraction < .003 ||
          fraction > .3 ||
          aspect < .35 ||
          aspect > 3 ||
          queue.length / boxArea < .7 ||
          left == 0 ||
          top == 0 ||
          right == width - 1 ||
          bottom == height - 1) {
        continue;
      }

      // Sample inside the boundaries so the background and dark paper edges do
      // not dilute the dye color. The surface around the patch is unrestricted.
      final insetX = math.max(1, (boxWidth * .18).round());
      final insetY = math.max(1, (boxHeight * .18).round());
      if (boxWidth <= 2 * insetX || boxHeight <= 2 * insetY) continue;
      final rect = Rect.fromLTRB(
        (left + insetX) * image.width / width,
        (top + insetY) * image.height / height,
        (right + 1 - insetX) * image.width / width,
        (bottom + 1 - insetY) * image.height / height,
      );
      final patch = img.copyCrop(
        image,
        x: rect.left.floor(),
        y: rect.top.floor(),
        width: rect.width.floor(),
        height: rect.height.floor(),
      );
      try {
        StripValidatorService.checkPatch(patch);
        final analyzer = PHAnalyzer()..trainFromCalibrationData(calibration);
        analyzer.estimateFromRgb(RobustColorExtractor.extract(patch), const [
          245,
          245,
          240,
        ]);
      } on Exception {
        continue;
      }
      final centerX = (left + right) / (2 * width);
      final centerY = (top + bottom) / (2 * height);
      final score =
          queue.length / boxArea -
          .6 * math.sqrt(math.pow(centerX - .5, 2) + math.pow(centerY - .5, 2));
      if (score > bestScore) {
        bestScore = score;
        best = rect;
      }
    }
    return best;
  }
}

List<double>? detectDyePaper(Map<String, String> params) {
  final image = PHAnalyzer.loadAndNormalizeImage(params['path']!);
  final calibration = CalibrationData.fromJsonString(params['calibration']!);
  final rect = AutomaticDyeDetector.detect(image, calibration);
  return rect == null ? null : [rect.left, rect.top, rect.right, rect.bottom];
}
