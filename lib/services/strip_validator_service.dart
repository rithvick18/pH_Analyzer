import 'package:image/image.dart' as img;
import 'ph_analyzer.dart';

/// Local acquisition checks. These do not establish strip identity or pH accuracy.
class StripValidatorService {
  static void checkPatch(img.Image patch) {
    if (patch.width < 4 || patch.height < 4) {
      throw const MeasurementQualityException(
        'Selected region is too small. Select at least a 4 by 4 pixel patch.',
      );
    }
    var clipped = 0;
    for (final p in patch) {
      if ((p.r >= 250 && p.g >= 250 && p.b >= 250) ||
          (p.r <= 5 && p.g <= 5 && p.b <= 5)) {
        clipped++;
      }
    }
    if (clipped / (patch.width * patch.height) > 0.2) {
      throw const MeasurementQualityException(
        'Too much glare or deep shadow in the selected dye region. Retake under even lighting.',
      );
    }
  }
}
