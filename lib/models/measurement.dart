import 'dart:typed_data';

/// Immutable provenance stored with the estimate, never recomputed on export.
class Measurement {
  static const algorithm = 'cielab-natural-spline-v2';
  final double ph;
  final DateTime measuredAt;
  final String calibrationId;
  final String calibrationHash;
  final String algorithmVersion;
  final List<int> dyeRgb;
  final List<int> backgroundRgb;
  final List<double> deltaLab;
  final double colorDistance;
  final List<String> warnings;
  final String source;
  final String validationStatus;
  final String validationReason;
  final int imageWidth;
  final int imageHeight;

  Measurement({
    required this.ph,
    required this.measuredAt,
    required this.calibrationId,
    required this.calibrationHash,
    this.algorithmVersion = algorithm,
    required List<int> dyeRgb,
    required List<int> backgroundRgb,
    required List<double> deltaLab,
    required this.colorDistance,
    required List<String> warnings,
    required this.source,
    this.validationStatus = 'not_validated',
    this.validationReason =
        'Strip identity and measurement accuracy have not been independently validated.',
    required this.imageWidth,
    required this.imageHeight,
  }) : dyeRgb = List.unmodifiable(dyeRgb),
       backgroundRgb = List.unmodifiable(backgroundRgb),
       deltaLab = List.unmodifiable(deltaLab),
       warnings = List.unmodifiable(warnings);

  bool get isDemo => source == 'demo';
  String get statusLabel =>
      isDemo ? 'DEMO • Not a sample measurement' : 'Unvalidated estimate';

  Map<String, dynamic> toJson() => {
    'schema': 1,
    'ph': ph,
    'measuredAt': measuredAt.toUtc().toIso8601String(),
    'calibrationId': calibrationId,
    'calibrationHash': calibrationHash,
    'algorithmVersion': algorithmVersion,
    'dyeRgb': dyeRgb,
    'backgroundRgb': backgroundRgb,
    'deltaLab': deltaLab,
    'colorDistance': colorDistance,
    'warnings': warnings,
    'source': source,
    'validationStatus': validationStatus,
    'validationReason': validationReason,
    'imageWidth': imageWidth,
    'imageHeight': imageHeight,
  };

  factory Measurement.fromJson(Map<dynamic, dynamic> json) {
    if (json['schema'] != 1) {
      throw const FormatException('Unsupported measurement schema.');
    }
    return Measurement(
      ph: (json['ph'] as num).toDouble(),
      measuredAt: DateTime.parse(json['measuredAt'] as String),
      calibrationId: json['calibrationId'] as String,
      calibrationHash: json['calibrationHash'] as String,
      algorithmVersion: json['algorithmVersion'] as String,
      dyeRgb: (json['dyeRgb'] as List).cast<int>(),
      backgroundRgb: (json['backgroundRgb'] as List).cast<int>(),
      deltaLab: (json['deltaLab'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
      colorDistance: (json['colorDistance'] as num).toDouble(),
      warnings: (json['warnings'] as List).cast<String>(),
      source: json['source'] as String,
      validationStatus: json['validationStatus'] as String,
      validationReason: json['validationReason'] as String,
      imageWidth: json['imageWidth'] as int,
      imageHeight: json['imageHeight'] as int,
    );
  }
}

class AnalysisResult {
  final Measurement measurement;
  final Uint8List dyeThumbnail;
  final Uint8List backgroundThumbnail;
  const AnalysisResult({
    required this.measurement,
    required this.dyeThumbnail,
    required this.backgroundThumbnail,
  });
}
