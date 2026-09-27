import 'dart:convert';

void validateRgb(List<int> rgb, String name) {
  if (rgb.length != 3 || rgb.any((v) => v < 0 || v > 255)) {
    throw FormatException(
      '$name must contain three RGB channels from 0 to 255.',
    );
  }
}

List<int> _readRgb(Object? value, String name) {
  if (value is! List || value.length != 3 || value.any((v) => v is! int)) {
    throw FormatException('$name must contain three integer RGB channels.');
  }
  final rgb = List<int>.unmodifiable(value.cast<int>());
  validateRgb(rgb, name);
  return rgb;
}

class CalibrationAnchor {
  final double ph;
  final List<int> dyeRgb;
  final List<int> bgRgb;

  CalibrationAnchor({
    required this.ph,
    required List<int> dyeRgb,
    required List<int> bgRgb,
  }) : dyeRgb = List.unmodifiable(dyeRgb),
       bgRgb = List.unmodifiable(bgRgb) {
    if (!ph.isFinite || ph < 0 || ph > 14) {
      throw const FormatException(
        'Calibration pH must be finite and between 0 and 14.',
      );
    }
    validateRgb(this.dyeRgb, 'dye_rgb');
    validateRgb(this.bgRgb, 'bg_rgb');
  }

  factory CalibrationAnchor.fromJson(Map<String, dynamic> json) {
    if (json['ph'] is! num) {
      throw const FormatException('Calibration pH is required.');
    }
    return CalibrationAnchor(
      ph: (json['ph'] as num).toDouble(),
      dyeRgb: _readRgb(json['dye_rgb'], 'dye_rgb'),
      bgRgb: _readRgb(json['bg_rgb'], 'bg_rgb'),
    );
  }

  Map<String, dynamic> toJson() => {
    'ph': ph,
    'dye_rgb': dyeRgb,
    'bg_rgb': bgRgb,
  };
}

class CalibrationData {
  final List<CalibrationAnchor> anchors;
  final String id;
  final int version;

  /// An experimental rejection guard, not a validated accuracy threshold.
  final double maxColorDistance;

  CalibrationData({
    required List<CalibrationAnchor> anchors,
    this.id = 'custom',
    this.version = 1,
    this.maxColorDistance = 15,
  }) : anchors = List.unmodifiable(
         List<CalibrationAnchor>.from(anchors)
           ..sort((a, b) => a.ph.compareTo(b.ph)),
       ) {
    if (this.anchors.length < 2) {
      throw const FormatException(
        'At least two calibration anchors are required.',
      );
    }
    if (id.trim().isEmpty ||
        version < 1 ||
        !maxColorDistance.isFinite ||
        maxColorDistance <= 0) {
      throw const FormatException('Invalid calibration metadata.');
    }
    for (var i = 1; i < this.anchors.length; i++) {
      if (this.anchors[i].ph == this.anchors[i - 1].ph) {
        throw const FormatException('Calibration pH anchors must be unique.');
      }
    }
  }

  factory CalibrationData.fromJson(Map<String, dynamic> json) {
    if (json['anchors'] is! List || (json['schema_version'] ?? 1) != 1) {
      throw const FormatException(
        'Unsupported calibration schema or missing anchors.',
      );
    }
    final id = json['id'] ?? 'custom';
    final version = json['version'] ?? 1;
    final distance = json['max_color_distance'] ?? 15;
    if (id is! String || version is! int || distance is! num) {
      throw const FormatException('Invalid calibration metadata types.');
    }
    return CalibrationData(
      anchors: (json['anchors'] as List).map((e) {
        if (e is! Map<String, dynamic>) {
          throw const FormatException('Invalid calibration anchor.');
        }
        return CalibrationAnchor.fromJson(e);
      }).toList(),
      id: id,
      version: version,
      maxColorDistance: distance.toDouble(),
    );
  }

  factory CalibrationData.fromJsonString(String jsonString) {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Calibration must be a JSON object.');
    }
    return CalibrationData.fromJson(decoded);
  }

  Map<String, dynamic> toJson() => {
    'schema_version': 1,
    'id': id,
    'version': version,
    'max_color_distance': maxColorDistance,
    'anchors': anchors.map((e) => e.toJson()).toList(),
  };
}
