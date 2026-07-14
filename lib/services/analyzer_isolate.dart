import 'dart:isolate';
import 'dart:ui' show Rect;
import 'package:flutter/services.dart' show rootBundle;
import 'ph_analyzer.dart';

/// Top-level function executed in the secondary Isolate.
double _isolatePredict(Map<String, dynamic> params) {
  final String calibrationJson = params['calibrationJson'] as String;
  final String imagePath = params['imagePath'] as String;

  final Map<String, dynamic> dyeMap = params['dyeRect'] as Map<String, dynamic>;
  final Map<String, dynamic> bgMap = params['bgRect'] as Map<String, dynamic>;

  final Rect dyeRect = Rect.fromLTWH(
    (dyeMap['left'] as num).toDouble(),
    (dyeMap['top'] as num).toDouble(),
    (dyeMap['width'] as num).toDouble(),
    (dyeMap['height'] as num).toDouble(),
  );

  final Rect bgRect = Rect.fromLTWH(
    (bgMap['left'] as num).toDouble(),
    (bgMap['top'] as num).toDouble(),
    (bgMap['width'] as num).toDouble(),
    (bgMap['height'] as num).toDouble(),
  );

  final analyzer = PHAnalyzer();
  analyzer.trainFromJsonString(calibrationJson);
  return analyzer.predict(imagePath, dyeRect, bgRect);
}

class AnalyzerService {
  /// Runs heavy pH prediction inside a separate Isolate using `Isolate.run`.
  static Future<double> predictFromPath(
    String imagePath,
    Rect dyeRect,
    Rect bgRect,
  ) async {
    final String calibrationJson = await rootBundle.loadString(
      'assets/calibration.json',
    );

    final Map<String, dynamic> params = {
      'calibrationJson': calibrationJson,
      'imagePath': imagePath,
      'dyeRect': {
        'left': dyeRect.left,
        'top': dyeRect.top,
        'width': dyeRect.width,
        'height': dyeRect.height,
      },
      'bgRect': {
        'left': bgRect.left,
        'top': bgRect.top,
        'width': bgRect.width,
        'height': bgRect.height,
      },
    };

    return await Isolate.run(() => _isolatePredict(params));
  }
}
