import 'calibration_data.dart';

class CalibrationProfile {
  final String id;
  final int version;
  final String name;
  final String brand;
  final String product;
  final String lot;
  final String notes;
  final double lowerPh;
  final double upperPh;
  final CalibrationData calibration;

  CalibrationProfile({
    required this.id,
    required this.version,
    required this.name,
    this.brand = '',
    this.product = '',
    this.lot = '',
    this.notes = '',
    required this.lowerPh,
    required this.upperPh,
    required List<CalibrationAnchor> anchors,
    double maxColorDistance = 15,
  }) : calibration = CalibrationData(
         anchors: anchors,
         id: id,
         version: version,
         maxColorDistance: maxColorDistance,
       ) {
    if (id.trim().isEmpty ||
        id == 'bundled-experimental' ||
        version < 1 ||
        name.trim().isEmpty ||
        !lowerPh.isFinite ||
        !upperPh.isFinite ||
        lowerPh < 0 ||
        upperPh > 14 ||
        lowerPh >= upperPh ||
        calibration.lowerPh != lowerPh ||
        calibration.upperPh != upperPh) {
      throw const FormatException(
        'Profile needs a name, valid pH range, and anchors at both range endpoints.',
      );
    }
  }

  String get hash => calibration.hash;

  Map<String, dynamic> toJson() => {
    'schema': 1,
    'id': id,
    'version': version,
    'name': name,
    'brand': brand,
    'product': product,
    'lot': lot,
    'notes': notes,
    'lower_ph': lowerPh,
    'upper_ph': upperPh,
    'calibration': calibration.toJson(),
  };

  factory CalibrationProfile.fromJson(Map<String, dynamic> json) {
    if (json['schema'] != 1 || json['calibration'] is! Map<String, dynamic>) {
      throw const FormatException('Unsupported calibration profile format.');
    }
    final data = CalibrationData.fromJson(
      json['calibration'] as Map<String, dynamic>,
    );
    if (json['id'] is! String ||
        json['version'] is! int ||
        json['name'] is! String ||
        json['brand'] is! String ||
        json['product'] is! String ||
        json['lot'] is! String ||
        json['notes'] is! String ||
        json['lower_ph'] is! num ||
        json['upper_ph'] is! num ||
        data.id != json['id'] ||
        data.version != json['version']) {
      throw const FormatException('Invalid calibration profile fields.');
    }
    return CalibrationProfile(
      id: json['id'] as String,
      version: json['version'] as int,
      name: json['name'] as String,
      brand: json['brand'] as String,
      product: json['product'] as String,
      lot: json['lot'] as String,
      notes: json['notes'] as String,
      lowerPh: (json['lower_ph'] as num).toDouble(),
      upperPh: (json['upper_ph'] as num).toDouble(),
      anchors: data.anchors,
      maxColorDistance: data.maxColorDistance,
    );
  }
}
