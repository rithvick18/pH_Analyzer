import 'dart:ui' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ph_analyzer/services/color_converter.dart';
import 'package:ph_analyzer/services/cubic_spline.dart';
import 'package:ph_analyzer/services/ph_analyzer.dart';
import 'package:ph_analyzer/services/robust_extractor.dart';

void main() {
  const String sampleCalibrationJson = '''
{
  "anchors": [
    { "ph": 0.0,  "dye_rgb": [255, 240, 200], "bg_rgb": [250, 250, 245] },
    { "ph": 1.5,  "dye_rgb": [248, 230, 190], "bg_rgb": [250, 250, 245] },
    { "ph": 2.3,  "dye_rgb": [240, 210, 170], "bg_rgb": [250, 250, 245] },
    { "ph": 2.9,  "dye_rgb": [230, 180, 150], "bg_rgb": [250, 250, 245] },
    { "ph": 7.0,  "dye_rgb": [200, 140, 100], "bg_rgb": [250, 250, 245] },
    { "ph": 9.5,  "dye_rgb": [160, 160, 200], "bg_rgb": [250, 250, 245] },
    { "ph": 11.5, "dye_rgb": [120, 190, 220], "bg_rgb": [250, 250, 245] },
    { "ph": 14.0, "dye_rgb": [60, 60, 180],  "bg_rgb": [250, 250, 245] }
  ]
}
''';

  group('ColorConverter Tests', () {
    test('rgbToLab converts pure white to L=100', () {
      final lab = ColorConverter.rgbToLab([255, 255, 255]);
      expect(lab[0], closeTo(100.0, 0.01));
      expect(lab[1], closeTo(0.0, 0.01));
      expect(lab[2], closeTo(0.0, 0.01));
    });

    test('deltaLab computes correct difference', () {
      final delta = ColorConverter.deltaLab([200, 140, 100], [250, 250, 245]);
      expect(delta.length, 3);
    });
  });

  group('RobustColorExtractor Tests', () {
    test('Extracts mean RGB correctly from synthetic patch with outliers', () {
      final patch = img.Image(width: 10, height: 10);
      // Fill patch with [200, 140, 100]
      for (int y = 0; y < 10; y++) {
        for (int x = 0; x < 10; x++) {
          patch.setPixelRgb(x, y, 200, 140, 100);
        }
      }
      // Add extreme noise at corners
      patch.setPixelRgb(0, 0, 0, 0, 0); // dark outlier
      patch.setPixelRgb(9, 9, 255, 255, 255); // bright outlier

      final rgb = RobustColorExtractor.extract(patch);
      expect(rgb[0], 200);
      expect(rgb[1], 140);
      expect(rgb[2], 100);
    });
  });

  group('CubicSpline Tests', () {
    test('Interpolates exact nodes and smooth interior points', () {
      final spline = CubicSpline([0.0, 1.0, 2.0], [0.0, 1.0, 0.0]);
      expect(spline.interpolate(0.0), closeTo(0.0, 1e-6));
      expect(spline.interpolate(1.0), closeTo(1.0, 1e-6));
      expect(spline.interpolate(2.0), closeTo(0.0, 1e-6));
      // Midpoint between 0 and 1 should be > 0
      expect(spline.interpolate(0.5), greaterThan(0.0));
    });
  });

  group('PHAnalyzer End-to-End Pipeline Tests', () {
    test('Predicts pH within +-0.1 for known anchor point (pH 7.0)', () {
      final analyzer = PHAnalyzer();
      analyzer.trainFromJsonString(sampleCalibrationJson);

      // Create a 200x300 synthetic image
      final syntheticImg = img.Image(width: 200, height: 300);

      // Fill background with [250, 250, 245]
      for (int y = 0; y < 300; y++) {
        for (int x = 0; x < 200; x++) {
          syntheticImg.setPixelRgb(x, y, 250, 250, 245);
        }
      }

      // Fill dye pad region at Rect(50, 50, 100, 100) with pH 7.0 dye_rgb [200, 140, 100]
      for (int y = 50; y < 150; y++) {
        for (int x = 50; x < 150; x++) {
          syntheticImg.setPixelRgb(x, y, 200, 140, 100);
        }
      }

      final Rect dyeRect = const Rect.fromLTRB(50, 50, 150, 150);
      final Rect bgRect = const Rect.fromLTRB(10, 200, 190, 280);

      final double predictedPh = analyzer.predictFromImage(syntheticImg, dyeRect, bgRect);
      expect(predictedPh, closeTo(7.0, 0.1));
    });

    test('Predicts pH within +-0.1 for known anchor point (pH 2.3)', () {
      final analyzer = PHAnalyzer();
      analyzer.trainFromJsonString(sampleCalibrationJson);

      final syntheticImg = img.Image(width: 200, height: 300);

      // Fill background with [250, 250, 245]
      for (int y = 0; y < 300; y++) {
        for (int x = 0; x < 200; x++) {
          syntheticImg.setPixelRgb(x, y, 250, 250, 245);
        }
      }

      // Fill dye pad region with pH 2.3 dye_rgb [240, 210, 170]
      for (int y = 50; y < 150; y++) {
        for (int x = 50; x < 150; x++) {
          syntheticImg.setPixelRgb(x, y, 240, 210, 170);
        }
      }

      final Rect dyeRect = const Rect.fromLTRB(50, 50, 150, 150);
      final Rect bgRect = const Rect.fromLTRB(10, 200, 190, 280);

      final double predictedPh = analyzer.predictFromImage(syntheticImg, dyeRect, bgRect);
      expect(predictedPh, closeTo(2.3, 0.1));
    });
  });
}
