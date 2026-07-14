import 'dart:convert';

class CalibrationAnchor {
  final double ph;
  final List<int> dyeRgb;
  final List<int> bgRgb;

  const CalibrationAnchor({
    required this.ph,
    required this.dyeRgb,
    required this.bgRgb,
  });

  factory CalibrationAnchor.fromJson(Map<String, dynamic> json) {
    return CalibrationAnchor(
      ph: (json['ph'] as num).toDouble(),
      dyeRgb: (json['dye_rgb'] as List<dynamic>).map((e) => (e as num).toInt()).toList(),
      bgRgb: (json['bg_rgb'] as List<dynamic>).map((e) => (e as num).toInt()).toList(),
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

  const CalibrationData({required this.anchors});

  factory CalibrationData.fromJson(Map<String, dynamic> json) {
    final list = json['anchors'] as List<dynamic>? ?? [];
    return CalibrationData(
      anchors: list.map((e) => CalibrationAnchor.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  factory CalibrationData.fromJsonString(String jsonString) {
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    return CalibrationData.fromJson(decoded);
  }

  Map<String, dynamic> toJson() => {
        'anchors': anchors.map((e) => e.toJson()).toList(),
      };
}
