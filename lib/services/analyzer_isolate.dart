import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import '../models/measurement.dart';
import '../models/calibration_data.dart';
import 'image_geometry.dart';
import 'ph_analyzer.dart';
import 'robust_extractor.dart';
import 'strip_validator_service.dart';

class AnalyzerService {
  /// Shared camera/gallery workflow: one decode and one extraction per ROI.
  static Future<AnalysisResult> analyze({
    required String imagePath,
    required Rect dyeRect,
    Rect? bgRect,
    String source = 'gallery',
    DateTime? capturedAt,
    CalibrationData? calibration,
    String? validationReason,
    bool manualMode = false,
  }) async {
    final calibrationJson = calibration == null
        ? await rootBundle.loadString('assets/calibration.json')
        : await Future.value(calibration.toJsonString());
    final measuredAt = capturedAt ?? DateTime.now();
    return Isolate.run(
      () => analyzeWithCalibration(
        imagePath: imagePath,
        dyeRect: dyeRect,
        bgRect: bgRect,
        source: source,
        measuredAt: measuredAt,
        calibrationJson: calibrationJson,
        validationReason: validationReason,
        manualMode: manualMode,
      ),
    );
  }

  static AnalysisResult analyzeWithCalibration({
    required String imagePath,
    required Rect dyeRect,
    Rect? bgRect,
    required String source,
    required DateTime measuredAt,
    required String calibrationJson,
    String? validationReason,
    bool manualMode = false,
  }) {
    if (!const ['camera', 'gallery', 'demo'].contains(source)) {
      throw ArgumentError('Unknown capture source.');
    }
    final image = PHAnalyzer.loadAndNormalizeImage(imagePath);
    final dye = ImageGeometry.crop(image, dyeRect);
    StripValidatorService.checkPatch(dye);
    final background = bgRect == null
        ? null
        : ImageGeometry.crop(image, bgRect);
    if (background != null && (background.width < 4 || background.height < 4)) {
      throw const MeasurementQualityException(
        'Select a larger reference paper region.',
      );
    }
    final dyeRgb = RobustColorExtractor.extract(dye);
    final bgRgb = background == null
        ? const [245, 245, 240]
        : RobustColorExtractor.extract(background);
    final analyzer = PHAnalyzer()..trainFromJsonString(calibrationJson);
    final estimate = analyzer.estimateFromRgb(dyeRgb, bgRgb);
    final reference = background ?? img.Image(width: 32, height: 32);
    if (background == null) {
      img.fill(reference, color: img.ColorRgb8(245, 245, 240));
    }
    Uint8List thumbnail(img.Image patch) {
      final resized = patch.width > 256 || patch.height > 256
          ? img.copyResize(
              patch,
              width: patch.width >= patch.height ? 256 : null,
              height: patch.height > patch.width ? 256 : null,
            )
          : patch;
      return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    }

    return AnalysisResult(
      measurement: Measurement(
        ph: estimate.ph,
        measuredAt: measuredAt,
        calibrationId: analyzer.calibrationId,
        calibrationHash: analyzer.calibrationHash,
        calibrationProfileId: analyzer.calibrationProfileId,
        calibrationVersion: analyzer.calibrationVersion,
        dyeRgb: dyeRgb,
        backgroundRgb: bgRgb,
        deltaLab: estimate.deltaLab,
        colorDistance: estimate.colorDistance,
        source: source,
        validationStatus: validationReason != null
            ? 'gemini_validated'
            : manualMode
            ? 'manual_unvalidated'
            : 'not_validated',
        validationReason:
            validationReason ??
            (manualMode
                ? 'Manual mode: no AI dye-pad identity check was performed. pH accuracy is not independently validated.'
                : 'Strip identity and measurement accuracy have not been independently validated.'),
        imageWidth: image.width,
        imageHeight: image.height,
        warnings: [
          ...estimate.warnings,
          if (bgRect == null)
            'Reference paper was not measured; a fixed background color was assumed.',
          if (source == 'demo')
            'Bundled demo image; this is not a measurement of your sample.',
        ],
      ),
      dyeThumbnail: thumbnail(dye),
      backgroundThumbnail: thumbnail(reference),
    );
  }
}
