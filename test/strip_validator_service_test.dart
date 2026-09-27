import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ph_analyzer/services/strip_validator_service.dart';
import 'package:ph_analyzer/services/ph_analyzer.dart';

void main() {
  test(
    'local acquisition checks accept a usable patch without claiming identity',
    () {
      final patch = img.Image(width: 10, height: 10);
      img.fill(patch, color: img.ColorRgb8(96, 87, 68));
      expect(() => StripValidatorService.checkPatch(patch), returnsNormally);
    },
  );
  test('tiny regions and clipped dye patches are rejected', () {
    expect(
      () => StripValidatorService.checkPatch(img.Image(width: 2, height: 2)),
      throwsA(isA<MeasurementQualityException>()),
    );
    for (final value in [0, 255]) {
      final patch = img.Image(width: 10, height: 10);
      img.fill(patch, color: img.ColorRgb8(value, value, value));
      expect(
        () => StripValidatorService.checkPatch(patch),
        throwsA(isA<MeasurementQualityException>()),
      );
    }
  });
  test('small glare area does not invalidate otherwise usable pixels', () {
    final patch = img.Image(width: 10, height: 10);
    img.fill(patch, color: img.ColorRgb8(96, 87, 68));
    patch.setPixelRgb(0, 0, 255, 255, 255);
    expect(() => StripValidatorService.checkPatch(patch), returnsNormally);
  });
}
