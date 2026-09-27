import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:ph_analyzer/models/calibration_data.dart';
import 'package:ph_analyzer/models/calibration_profile.dart';
import 'package:ph_analyzer/models/measurement.dart';
import 'package:ph_analyzer/screens/calibration_manager_screen.dart';
import 'package:ph_analyzer/services/analyzer_isolate.dart';
import 'package:ph_analyzer/services/calibration_profile_service.dart';
import 'package:ph_analyzer/services/ph_analyzer.dart';
import 'package:ph_analyzer/services/robust_extractor.dart';

CalibrationAnchor point(double ph, List<int> dye) =>
    CalibrationAnchor(ph: ph, dyeRgb: dye, bgRgb: const [245, 245, 240]);

CalibrationProfile profile({
  String id = 'dye-a',
  int version = 1,
  List<CalibrationAnchor>? anchors,
}) => CalibrationProfile(
  id: id,
  version: version,
  name: 'Dye A',
  brand: 'Example',
  product: 'Strip',
  lot: 'L1',
  notes: 'Even light',
  lowerPh: 4,
  upperPh: 8,
  anchors:
      anchors ??
      [
        point(4, [120, 80, 70]),
        point(8, [180, 140, 90]),
      ],
);

void main() {
  test('valid profile round trips with stable hash and metadata', () {
    final original = profile();
    final decoded = CalibrationProfile.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.id, original.id);
    expect(decoded.version, 1);
    expect(decoded.lot, 'L1');
    expect(decoded.hash, original.hash);
    final altered = original.toJson();
    (altered['calibration'] as Map<String, dynamic>)['max_color_distance'] = 12;
    final restored = CalibrationProfile.fromJson(altered);
    expect(restored.calibration.maxColorDistance, 12);
    expect(restored.hash, CalibrationProfile.fromJson(restored.toJson()).hash);
  });

  test('rejects insufficient, duplicate, unsorted, invalid RGB and bounds', () {
    expect(
      () => profile(
        anchors: [
          point(4, [120, 80, 70]),
        ],
      ),
      throwsFormatException,
    );
    expect(
      () => profile(
        anchors: [
          point(4, [120, 80, 70]),
          point(4, [180, 140, 90]),
        ],
      ),
      throwsFormatException,
    );
    expect(
      () => profile(
        anchors: [
          point(8, [180, 140, 90]),
          point(4, [120, 80, 70]),
        ],
      ),
      throwsFormatException,
    );
    expect(() => point(double.nan, [120, 80, 70]), throwsFormatException);
    expect(() => point(4, [256, 80, 70]), throwsFormatException);
    expect(
      () => CalibrationProfile(
        id: 'x',
        version: 1,
        name: 'X',
        lowerPh: 3,
        upperPh: 8,
        anchors: [
          point(4, [120, 80, 70]),
          point(8, [180, 140, 90]),
        ],
      ),
      throwsFormatException,
    );
    final invalid = profile().toJson();
    final calibration = invalid['calibration'] as Map<String, dynamic>;
    calibration['anchors'] = [
      calibration['anchors'][1],
      calibration['anchors'][0],
    ];
    expect(() => CalibrationProfile.fromJson(invalid), throwsFormatException);
  });

  test(
    'separate profile store preserves provenance across edit and delete',
    () async {
      final directory = Directory.systemTemp.createTempSync('ph_profiles_');
      Hive.init(directory.path);
      try {
        final first = profile();
        await CalibrationProfileService.save(first);
        await CalibrationProfileService.select(first.id);
        expect(
          (await CalibrationProfileService.activeSnapshot()).$1.hash,
          first.hash,
        );
        final prior = Measurement(
          ph: 4,
          measuredAt: DateTime.utc(2026),
          calibrationId: 'dye-a:v1',
          calibrationHash: first.hash,
          calibrationProfileId: first.id,
          calibrationVersion: first.version,
          dyeRgb: const [120, 80, 70],
          backgroundRgb: const [245, 245, 240],
          deltaLab: const [1, 2, 3],
          colorDistance: 0,
          warnings: const [],
          source: 'gallery',
          imageWidth: 20,
          imageHeight: 20,
        );
        final edited = profile(
          version: 2,
          anchors: [
            point(4, [121, 80, 70]),
            point(8, [180, 140, 90]),
          ],
        );
        await CalibrationProfileService.save(edited);
        expect(
          (await CalibrationProfileService.activeSnapshot()).$1.hash,
          edited.hash,
        );
        expect(edited.hash, isNot(first.hash));
        await CalibrationProfileService.delete(first.id);
        expect(
          await CalibrationProfileService.activeId(),
          CalibrationProfileService.bundledId,
        );
        final restored = Measurement.fromJson(prior.toJson());
        expect(restored.calibrationProfileId, first.id);
        expect(restored.calibrationVersion, 1);
        expect(restored.calibrationHash, first.hash);
        expect(await CalibrationProfileService.getAll(), isEmpty);
      } finally {
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'corrupted profile storage fails without touching legacy measurements',
    () async {
      final directory = Directory.systemTemp.createTempSync('ph_corrupt_');
      Hive.init(directory.path);
      try {
        final box = await CalibrationProfileService.getBox();
        await box.put('broken', '{bad json');
        await expectLater(
          CalibrationProfileService.getAll(),
          throwsFormatException,
        );
        final legacy = Measurement.fromJson({
          'schema': 1,
          'ph': 7,
          'measuredAt': DateTime.utc(2026).toIso8601String(),
          'calibrationId': 'bundled-experimental:v1',
          'calibrationHash': 'old',
          'algorithmVersion': Measurement.algorithm,
          'dyeRgb': [100, 90, 80],
          'backgroundRgb': [245, 245, 240],
          'deltaLab': [1, 2, 3],
          'colorDistance': 0,
          'warnings': <String>[],
          'source': 'gallery',
          'validationStatus': 'not_validated',
          'validationReason': 'unknown',
          'imageWidth': 10,
          'imageHeight': 10,
        });
        expect(legacy.calibrationProfileId, isNull);
        expect(legacy.calibrationHash, 'old');
      } finally {
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('selected anchors drive analysis and never extrapolate', () async {
    final directory = Directory.systemTemp.createTempSync('ph_analyze_');
    Hive.init(directory.path);
    final image = img.Image(width: 40, height: 40);
    img.fill(image, color: img.ColorRgb8(120, 80, 70));
    final imagePath = '${directory.path}/sample.png';
    File(imagePath).writeAsBytesSync(img.encodePng(image));
    try {
      await CalibrationProfileService.save(profile());
      await CalibrationProfileService.select('dye-a');
      final data = (await CalibrationProfileService.activeSnapshot()).$1;
      final result = await AnalyzerService.analyze(
        imagePath: imagePath,
        dyeRect: const Rect.fromLTWH(0, 0, 40, 40),
        source: 'gallery',
        capturedAt: DateTime.utc(2026),
        calibration: data,
      );
      expect(result.measurement.ph, 4);
      expect(result.measurement.calibrationProfileId, 'dye-a');
      expect(result.measurement.calibrationVersion, 1);
      expect(result.measurement.calibrationHash, data.hash);
      final analyzer = PHAnalyzer()..trainFromCalibrationData(data);
      expect(
        analyzer.predictFromRgb([120, 80, 70], [245, 245, 240]),
        inInclusiveRange(4, 8),
      );
      expect(
        analyzer.predictFromRgb([180, 140, 90], [245, 245, 240]),
        inInclusiveRange(4, 8),
      );
      expect(
        () => analyzer.predictFromRgb([50, 200, 180], [245, 245, 240]),
        throwsA(isA<MeasurementQualityException>()),
      );
    } finally {
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });

  test('photo color extraction uses selected region', () {
    final image = img.Image(width: 20, height: 10);
    img.fill(image, color: img.ColorRgb8(245, 245, 240));
    for (var y = 0; y < 10; y++) {
      for (var x = 0; x < 10; x++) {
        image.setPixelRgb(x, y, 120, 80, 70);
      }
    }
    expect(
      RobustColorExtractor.extract(
        img.copyCrop(image, x: 0, y: 0, width: 10, height: 10),
      ),
      [120, 80, 70],
    );
    expect(
      RobustColorExtractor.extract(
        img.copyCrop(image, x: 10, y: 0, width: 10, height: 10),
      ),
      [245, 245, 240],
    );
  });

  testWidgets('manual RGB entry returns a point', (tester) async {
    CalibrationAnchor? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                captured = await showDialog<CalibrationAnchor>(
                  context: context,
                  builder: (_) => const CalibrationPointDialog(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Known pH *'), '6.5');
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), '120');
    await tester.enterText(fields.at(2), '80');
    await tester.enterText(fields.at(3), '70');
    await tester.tap(find.text('Use point'));
    await tester.pumpAndSettle();
    expect(captured?.ph, 6.5);
    expect(captured?.dyeRgb, [120, 80, 70]);
  });
}
