import 'dart:io';
import 'dart:ui' show Rect;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import '../models/calibration_data.dart';
import 'color_converter.dart';
import 'cubic_spline.dart';
import 'robust_extractor.dart';

class LuminanceException implements Exception {
  final String message;
  final double luma;

  LuminanceException(this.message, {required this.luma});

  @override
  String toString() => 'LuminanceException: $message (Luma Y: ${luma.toStringAsFixed(1)})';
}

class PHAnalyzer {
  final Map<double, List<int>> dyeColors = {};
  final Map<double, List<int>> bgColors = {};
  CubicSpline? splineL;
  CubicSpline? splineA;
  CubicSpline? splineB;

  /// Loads calibration.json from assets and trains the splines.
  Future<void> trainFromAssets() async {
    final String jsonString = await rootBundle.loadString('assets/calibration.json');
    trainFromJsonString(jsonString);
  }

  /// Trains splines from raw JSON string representation of calibration data.
  void trainFromJsonString(String jsonString) {
    final data = CalibrationData.fromJsonString(jsonString);
    trainFromCalibrationData(data);
  }

  /// Trains splines from [CalibrationData] model.
  void trainFromCalibrationData(CalibrationData data) {
    if (data.anchors.length < 2) {
      throw ArgumentError('Calibration data must contain at least 2 anchors.');
    }

    final anchors = List<CalibrationAnchor>.from(data.anchors)
      ..sort((a, b) => a.ph.compareTo(b.ph));

    dyeColors.clear();
    bgColors.clear();

    final List<double> phList = [];
    final List<double> deltaLList = [];
    final List<double> deltaAList = [];
    final List<double> deltaBList = [];

    for (final anchor in anchors) {
      dyeColors[anchor.ph] = anchor.dyeRgb;
      bgColors[anchor.ph] = anchor.bgRgb;

      final delta = ColorConverter.deltaLab(anchor.dyeRgb, anchor.bgRgb);
      phList.add(anchor.ph);
      deltaLList.add(delta[0]);
      deltaAList.add(delta[1]);
      deltaBList.add(delta[2]);
    }

    splineL = CubicSpline(phList, deltaLList);
    splineA = CubicSpline(phList, deltaAList);
    splineB = CubicSpline(phList, deltaBList);
  }

  /// Helper to load an image from file path and normalize its orientation.
  static img.Image loadAndNormalizeImage(String imagePath) {
    final file = File(imagePath);
    if (!file.existsSync()) {
      throw FileSystemException('Image file not found', imagePath);
    }
    final bytes = file.readAsBytesSync();
    img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw ArgumentError('Failed to decode image from path: $imagePath');
    }
    decoded = img.bakeOrientation(decoded);
    if (decoded.width > decoded.height) {
      decoded = img.copyRotate(decoded, angle: 90);
    }
    return decoded;
  }

  /// Predicts the pH value for the given [imagePath] and ROI rects in original image coordinates.
  double predict(
    String imagePath,
    Rect dyeRect, [
    Rect? bgRect,
    List<int> referenceRgb = const [245, 245, 240],
  ]) {
    if (splineL == null || splineA == null || splineB == null) {
      throw StateError(
        'PHAnalyzer is not trained. Call trainFromAssets or trainFromJsonString first.',
      );
    }

    final image = loadAndNormalizeImage(imagePath);
    return predictFromImage(image, dyeRect, bgRect, referenceRgb);
  }

  /// Predicts the pH value directly from an [img.Image] and ROI rects.
  double predictFromImage(
    img.Image image,
    Rect dyeRect, [
    Rect? bgRect,
    List<int> referenceRgb = const [245, 245, 240],
  ]) {
    if (splineL == null || splineA == null || splineB == null) {
      throw StateError(
        'PHAnalyzer is not trained. Call trainFromAssets or trainFromJsonString first.',
      );
    }

    final croppedDye = _cropPatchSafe(image, dyeRect);
    final dyeRgb = RobustColorExtractor.extract(croppedDye);

    final bgRgb = bgRect != null
        ? RobustColorExtractor.extract(_cropPatchSafe(image, bgRect))
        : referenceRgb;

    return predictFromRgb(dyeRgb, bgRgb);
  }

  /// Predicts the pH given mean [dyeRgb] and [bgRgb].
  double predictFromRgb(List<int> dyeRgb, List<int> bgRgb) {
    if (splineL == null || splineA == null || splineB == null) {
      throw StateError('PHAnalyzer is not trained.');
    }

    final double lumaY = 0.299 * dyeRgb[0] + 0.587 * dyeRgb[1] + 0.114 * dyeRgb[2];
    if (lumaY < 40 || lumaY > 230) {
      throw LuminanceException(
        'Lighting condition out of bounds. Average ROI Luma Y = ${lumaY.toStringAsFixed(1)} (must be between 40 and 230). Please adjust lighting.',
        luma: lumaY,
      );
    }

    final targetDeltaLab = ColorConverter.deltaLab(dyeRgb, bgRgb);

    double minDistanceSq = double.infinity;
    double bestPh = 0.0;

    // Generate 141 evenly spaced pH values from 0.0 to 14.0 (step 0.1)
    for (int i = 0; i <= 140; i++) {
      final double ph = i * 0.1;
      final double curveL = splineL!.interpolate(ph);
      final double curveA = splineA!.interpolate(ph);
      final double curveB = splineB!.interpolate(ph);

      final double diffL = targetDeltaLab[0] - curveL;
      final double diffA = targetDeltaLab[1] - curveA;
      final double diffB = targetDeltaLab[2] - curveB;

      final double distSq = diffL * diffL + diffA * diffA + diffB * diffB;
      if (distSq < minDistanceSq) {
        minDistanceSq = distSq;
        bestPh = ph;
      }
    }

    final double clampedPh = bestPh.clamp(0.0, 14.0);
    return double.parse(clampedPh.toStringAsFixed(2));
  }

  img.Image _cropPatchSafe(img.Image image, Rect rect) {
    final int left = rect.left.floor().clamp(0, image.width - 1);
    final int top = rect.top.floor().clamp(0, image.height - 1);
    final int right = rect.right.ceil().clamp(left + 1, image.width);
    final int bottom = rect.bottom.ceil().clamp(top + 1, image.height);

    final int width = right - left;
    final int height = bottom - top;

    if (width <= 0 || height <= 0) {
      throw ArgumentError('Invalid ROI dimensions: width=$width, height=$height');
    }

    return img.copyCrop(image, x: left, y: top, width: width, height: height);
  }
}
