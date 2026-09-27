import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ph_analyzer/models/calibration_data.dart';
import 'package:ph_analyzer/services/automatic_dye_detector.dart';

void main() {
  final calibration = CalibrationData.fromJsonString('''
  {"anchors": [
    {"ph": 0, "dye_rgb": [86,50,44], "bg_rgb": [245,245,240]},
    {"ph": 7, "dye_rgb": [96,87,68], "bg_rgb": [245,245,240]},
    {"ph": 14, "dye_rgb": [56,49,27], "bg_rgb": [245,245,240]}
  ]}''');

  test('finds a dye patch on a colored background', () {
    final image = img.Image(width: 320, height: 240);
    img.fill(image, color: img.ColorRgb8(30, 100, 160));
    for (var y = 80; y < 150; y++) {
      for (var x = 120; x < 200; x++) {
        image.setPixelRgb(x, y, 96, 87, 68);
      }
    }
    final rect = AutomaticDyeDetector.detect(image, calibration);
    expect(rect, isNotNull);
    expect(rect!.center.dx, closeTo(160, 5));
    expect(rect.center.dy, closeTo(115, 5));
  });

  test('rejects a view without a dye-colored patch', () {
    final image = img.Image(width: 320, height: 240);
    img.fill(image, color: img.ColorRgb8(30, 100, 160));
    expect(AutomaticDyeDetector.detect(image, calibration), isNull);
  });

  test('rejects a whole frame of dye-colored material', () {
    final image = img.Image(width: 320, height: 240);
    img.fill(image, color: img.ColorRgb8(96, 87, 68));
    expect(AutomaticDyeDetector.detect(image, calibration), isNull);
  });
}
