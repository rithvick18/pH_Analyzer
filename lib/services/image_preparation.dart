import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import 'ph_analyzer.dart';

/// Creates an owned, lossless snapshot. Preview and analysis use these same pixels.
Map<String, dynamic> prepareImage(Map<String, String> params) {
  var image = PHAnalyzer.loadAndNormalizeImage(params['path']!);
  if (image.width < 4 || image.height < 4) {
    throw const MeasurementQualityException('Choose a larger photo.');
  }
  const maxPixels = 6 * 1000 * 1000;
  if (image.width * image.height > maxPixels) {
    final scale = math.sqrt(maxPixels / (image.width * image.height));
    image = img.copyResize(
      image,
      width: (image.width * scale).floor(),
      height: (image.height * scale).floor(),
      interpolation: img.Interpolation.average,
    );
  }
  final directory = Directory('${params['tempDirPath']!}/ph_analysis')
    ..createSync(recursive: true);
  final path = '${directory.path}/${const Uuid().v4()}.png';
  final bytes = Uint8List.fromList(img.encodePng(image));
  File(path).writeAsBytesSync(bytes, flush: true);
  return {
    'bytes': bytes,
    'width': image.width,
    'height': image.height,
    'path': path,
  };
}
