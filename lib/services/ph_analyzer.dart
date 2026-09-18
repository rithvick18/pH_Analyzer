import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Rect;
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import '../models/calibration_data.dart';
import 'color_converter.dart';
import 'cubic_spline.dart';
import 'image_geometry.dart';
import 'robust_extractor.dart';

class LuminanceException implements Exception {
  final String message;
  final double luma;
  LuminanceException(this.message, {required this.luma});
  @override
  String toString() => message;
}

class MeasurementQualityException implements Exception {
  final String message;
  const MeasurementQualityException(this.message);
  @override
  String toString() => message;
}

class PhEstimate {
  final double ph;
  final double colorDistance;
  final List<double> deltaLab;
  final List<String> warnings;
  PhEstimate(
    this.ph,
    this.colorDistance,
    List<double> deltaLab,
    List<String> warnings,
  ) : deltaLab = List.unmodifiable(deltaLab),
      warnings = List.unmodifiable(warnings);
}

class PHAnalyzer {
  CalibrationData? _calibration;
  CubicSpline? _splineL;
  CubicSpline? _splineA;
  CubicSpline? _splineB;
  String get calibrationId => '${_calibration!.id}:v${_calibration!.version}';
  String get calibrationHash => sha256
      .convert(utf8.encode(jsonEncode(_calibration!.toJson())))
      .toString();

  Future<void> trainFromAssets() async => trainFromJsonString(
    await rootBundle.loadString('assets/calibration.json'),
  );
  void trainFromJsonString(String jsonString) =>
      trainFromCalibrationData(CalibrationData.fromJsonString(jsonString));

  void trainFromCalibrationData(CalibrationData data) {
    // Build a complete replacement first; a failed update leaves the old model usable.
    final ph = data.anchors.map((a) => a.ph).toList();
    final deltas = data.anchors
        .map((a) => ColorConverter.deltaLab(a.dyeRgb, a.bgRgb))
        .toList();
    final l = CubicSpline(ph, deltas.map((d) => d[0]).toList());
    final a = CubicSpline(ph, deltas.map((d) => d[1]).toList());
    final b = CubicSpline(ph, deltas.map((d) => d[2]).toList());
    _calibration = data;
    _splineL = l;
    _splineA = a;
    _splineB = b;
  }

  static const maxImageBytes = 25 * 1024 * 1024;
  static const maxImagePixels = 24 * 1000 * 1000;

  /// Normalize only EXIF orientation. Landscape images stay landscape.
  static img.Image loadAndNormalizeImage(String imagePath) {
    final file = File(imagePath);
    if (!file.existsSync()) {
      throw const FileSystemException(
        'The selected image is no longer available. Please select it again.',
      );
    }
    if (file.lengthSync() > maxImageBytes) {
      throw const MeasurementQualityException(
        'Image exceeds 25 MB. Choose a smaller photo.',
      );
    }
    final bytes = file.readAsBytesSync();
    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info == null || info.width <= 0 || info.height <= 0) {
      throw const MeasurementQualityException(
        'This image format could not be read. Use a JPEG or PNG photo.',
      );
    }
    if (info.width * info.height > maxImagePixels || info.numFrames != 1) {
      throw const MeasurementQualityException(
        'Choose a single-frame image no larger than 24 megapixels.',
      );
    }
    final decoded = decoder!.decodeFrame(0);
    if (decoded == null) {
      throw const MeasurementQualityException(
        'The image is damaged or unreadable.',
      );
    }
    final normalized = img
        .bakeOrientation(decoded)
        .convert(format: img.Format.uint8);
    if (!normalized.hasAlpha) return normalized;
    final opaque = img.Image(
      width: normalized.width,
      height: normalized.height,
    );
    img.fill(opaque, color: img.ColorRgb8(255, 255, 255));
    return img.compositeImage(opaque, normalized);
  }

  double predict(
    String imagePath,
    Rect dyeRect, [
    Rect? bgRect,
    List<int> referenceRgb = const [245, 245, 240],
  ]) => predictFromImage(
    loadAndNormalizeImage(imagePath),
    dyeRect,
    bgRect,
    referenceRgb,
  );

  double predictFromImage(
    img.Image image,
    Rect dyeRect, [
    Rect? bgRect,
    List<int> referenceRgb = const [245, 245, 240],
  ]) => predictFromRgb(
    RobustColorExtractor.extract(ImageGeometry.crop(image, dyeRect)),
    bgRect == null
        ? referenceRgb
        : RobustColorExtractor.extract(ImageGeometry.crop(image, bgRect)),
  );

  double predictFromRgb(List<int> dyeRgb, List<int> bgRgb) =>
      estimateFromRgb(dyeRgb, bgRgb).ph;

  PhEstimate estimateFromRgb(List<int> dyeRgb, List<int> bgRgb) {
    final calibration = _calibration;
    if (calibration == null) {
      throw StateError('Calibration has not been loaded.');
    }
    validateRgb(dyeRgb, 'Dye RGB');
    validateRgb(bgRgb, 'Reference RGB');
    final luma = 0.299 * dyeRgb[0] + 0.587 * dyeRgb[1] + 0.114 * dyeRgb[2];
    if (luma < 40 || luma > 230) {
      throw LuminanceException(
        'The dye region is too dark or bright for this experimental calibration. Retake under even lighting.',
        luma: luma,
      );
    }
    final target = ColorConverter.deltaLab(dyeRgb, bgRgb);
    final lower = calibration.anchors.first.ph;
    final upper = calibration.anchors.last.ph;
    // Include endpoints and anchors even when their pH is not on the 0.1 grid.
    final candidates = <double>{
      lower,
      upper,
      ...calibration.anchors.map((a) => a.ph),
    };
    for (var i = (lower * 10).ceil(); i <= (upper * 10).floor(); i++) {
      candidates.add(i / 10);
    }
    final distances = <double, double>{};
    var best = lower;
    var minDistance = double.infinity;
    for (final ph in candidates.toList()..sort()) {
      final dl = target[0] - _splineL!.interpolate(ph);
      final da = target[1] - _splineA!.interpolate(ph);
      final db = target[2] - _splineB!.interpolate(ph);
      final distance = math.sqrt(dl * dl + da * da + db * db);
      distances[ph] = distance;
      if (distance < minDistance) {
        minDistance = distance;
        best = ph;
      }
    }
    if (minDistance > calibration.maxColorDistance) {
      throw const MeasurementQualityException(
        'Cannot determine pH: this color is too far from the calibration. Check the strip, selected regions, and lighting.',
      );
    }
    // A heuristic warning only, never a confidence percentage.
    final ambiguous = distances.entries.any(
      (e) => (e.key - best).abs() >= 1 && e.value <= minDistance + 1,
    );
    return PhEstimate(best, minDistance, target, [
      'Experimental calibration; accuracy and quality thresholds have not been independently validated.',
      if (ambiguous)
        'Ambiguous color match: substantially different pH values have similar colors.',
      if (best == lower || best == upper)
        'At the calibration boundary; the sample may be outside the supported range.',
    ]);
  }
}
