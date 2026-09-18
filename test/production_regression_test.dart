import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:ph_analyzer/models/calibration_data.dart';
import 'package:ph_analyzer/models/measurement.dart';
import 'package:ph_analyzer/models/prediction_record.dart';
import 'package:ph_analyzer/services/analyzer_isolate.dart';
import 'package:ph_analyzer/services/export_service.dart';
import 'package:ph_analyzer/services/history_service.dart';
import 'package:ph_analyzer/services/image_geometry.dart';
import 'package:ph_analyzer/services/image_preparation.dart';
import 'package:ph_analyzer/services/ph_analyzer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late String photo;
  late String calibration;
  final measuredAt = DateTime.utc(2026, 9, 1, 12);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ph_regression_');
    calibration = File('assets/calibration.json').readAsStringSync();
    final image = img.Image(width: 120, height: 80);
    img.fill(image, color: img.ColorRgb8(245, 245, 240));
    img.fillRect(
      image,
      x1: 10,
      y1: 10,
      x2: 49,
      y2: 39,
      color: img.ColorRgb8(96, 87, 68),
    );
    photo = '${directory.path}/input.png';
    File(photo).writeAsBytesSync(img.encodePng(image));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => directory.path,
        );
    Hive.init(directory.path);
    Hive.registerAdapter(PredictionRecordAdapter(), override: true);
  });
  tearDown(() async {
    await Hive.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await directory.delete(recursive: true);
  });

  AnalysisResult analyze({String source = 'gallery', bool reference = true}) =>
      AnalyzerService.analyzeWithCalibration(
        imagePath: photo,
        dyeRect: const Rect.fromLTWH(10, 10, 40, 30),
        bgRect: reference ? const Rect.fromLTWH(70, 10, 30, 30) : null,
        source: source,
        measuredAt: measuredAt,
        calibrationJson: calibration,
      );

  test(
    'restricted and non-grid calibration endpoints never return pH zero',
    () {
      final data = CalibrationData(
        anchors: [
          CalibrationAnchor(
            ph: 4.05,
            dyeRgb: [100, 80, 60],
            bgRgb: [245, 245, 240],
          ),
          CalibrationAnchor(
            ph: 10.05,
            dyeRgb: [80, 100, 60],
            bgRgb: [245, 245, 240],
          ),
        ],
      );
      final analyzer = PHAnalyzer()..trainFromCalibrationData(data);
      expect(analyzer.predictFromRgb([100, 80, 60], [245, 245, 240]), 4.05);
      expect(analyzer.predictFromRgb([80, 100, 60], [245, 245, 240]), 10.05);
    },
  );

  test(
    'malformed calibration is rejected and cannot damage the trained model',
    () {
      final analyzer = PHAnalyzer()..trainFromJsonString(calibration);
      for (final json in [
        '{}',
        '[]',
        '{"anchors":[]}',
        '{"anchors":[{"ph":7,"dye_rgb":[1.5,2,3],"bg_rgb":[4,5,6]}]}',
        '{"anchors":[{"ph":15,"dye_rgb":[1,2,3],"bg_rgb":[4,5,6]}]}',
        '{"anchors":[{"ph":4,"dye_rgb":[1,2],"bg_rgb":[4,5,6]}]}',
        '{"anchors":[{"ph":4,"dye_rgb":[256,2,3],"bg_rgb":[4,5,6]}]}',
      ]) {
        expect(() => analyzer.trainFromJsonString(json), throwsFormatException);
      }
      final duplicate = jsonDecode(calibration) as Map<String, dynamic>;
      duplicate['anchors'][1]['ph'] = duplicate['anchors'][0]['ph'];
      expect(
        () => analyzer.trainFromJsonString(jsonEncode(duplicate)),
        throwsFormatException,
      );
      expect(analyzer.predictFromRgb([96, 87, 68], [245, 245, 240]), 7);
      expect(
        () => CalibrationAnchor(
          ph: double.nan,
          dyeRgb: [1, 2, 3],
          bgRgb: [4, 5, 6],
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'out-of-calibration colors reject, rather than returning plausible pH',
    () {
      final analyzer = PHAnalyzer()..trainFromJsonString(calibration);
      expect(
        () => analyzer.predictFromRgb([40, 200, 60], [245, 245, 240]),
        throwsA(isA<MeasurementQualityException>()),
      );
    },
  );

  test(
    'landscape snapshot is lossless and ROI selects the displayed pixels',
    () {
      final prepared = prepareImage({
        'path': photo,
        'tempDirPath': directory.path,
      });
      expect(prepared['width'], 120);
      expect(prepared['height'], 80);
      final image = PHAnalyzer.loadAndNormalizeImage(
        prepared['path'] as String,
      );
      expect(image.width, 120);
      final pixel = ImageGeometry.crop(
        image,
        const Rect.fromLTWH(10, 10, 40, 30),
      ).getPixel(0, 0);
      expect([pixel.r, pixel.g, pixel.b], [96, 87, 68]);
    },
  );

  test(
    'EXIF rotation is baked once and round-trip normalization is stable',
    () {
      final original = img.Image(width: 40, height: 20);
      img.fill(original, color: img.ColorRgb8(96, 87, 68));
      original.exif.imageIfd.orientation = 6;
      final path = '${directory.path}/rotated.jpg';
      File(path).writeAsBytesSync(img.encodeJpg(original, quality: 100));
      final normalized = PHAnalyzer.loadAndNormalizeImage(path);
      expect(normalized.width, 20);
      expect(normalized.height, 40);
      final png = '${directory.path}/normalized.png';
      File(png).writeAsBytesSync(img.encodePng(normalized));
      final again = PHAnalyzer.loadAndNormalizeImage(png);
      expect(again.width, 20);
      expect(again.height, 40);
    },
  );

  test('contain and cover transforms round-trip across viewport changes', () {
    const region = Rect.fromLTWH(30, 20, 20, 20);
    for (final viewport in [
      const Size(200, 400),
      const Size(400, 200),
      const Size(300, 300),
    ]) {
      for (final cover in [true, false]) {
        final geometry = ImageGeometry(
          const Size(120, 80),
          viewport,
          cover: cover,
        );
        final actual = geometry.toImage(geometry.toScreen(region));
        expect(actual.left, closeTo(region.left, 1e-8));
        expect(actual.top, closeTo(region.top, 1e-8));
        expect(actual.width, closeTo(region.width, 1e-8));
      }
    }
    expect(
      () => ImageGeometry.crop(
        img.Image(width: 10, height: 10),
        const Rect.fromLTWH(-1, 0, 3, 3),
      ),
      throwsArgumentError,
    );
  });

  test(
    'camera gallery and demo share numerical behavior and retain provenance',
    () {
      final gallery = analyze();
      final camera = analyze(source: 'camera');
      final demo = analyze(source: 'demo');
      expect(gallery.measurement.ph, 7);
      expect(camera.measurement.ph, 7);
      expect(demo.measurement.ph, 7);
      expect(demo.measurement.isDemo, isTrue);
      expect(gallery.measurement.validationStatus, 'not_validated');
      expect(gallery.measurement.calibrationHash.length, 64);
      expect(gallery.measurement.measuredAt, measuredAt);
      expect(() => gallery.measurement.dyeRgb[0] = 0, throwsUnsupportedError);
      expect(
        analyze(reference: false).measurement.warnings.join(' '),
        contains('fixed background'),
      );
    },
  );

  test(
    'snapshot survives a real disk round trip and single-dye export',
    () async {
      final measurement = analyze(source: 'demo', reference: false).measurement;
      final record = await HistoryService.savePrediction(
        phValue: measurement.ph,
        tempImagePath: photo,
        dyeRect: const Rect.fromLTWH(10, 10, 40, 30),
        measurement: measurement,
        note: 'Sample',
      );
      expect(record.storedImagePath, startsWith('ph_measurements/'));
      expect(File(record.imagePath).existsSync(), isTrue);
      await Hive.close();
      final restored = (await HistoryService.getAllRecords()).single;
      expect(restored.measurement!.toJson(), measurement.toJson());
      expect(restored.timestamp, measuredAt);
      final bytes = await ExportService.createReport(
        imagePath: restored.imagePath,
        dyeRect: const Rect.fromLTWH(10, 10, 40, 30),
        phValue: restored.phValue,
        measurement: restored.measurement,
        measuredAt: restored.timestamp,
        generatedAt: DateTime.utc(2026, 9, 18),
      );
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      // Keep a report fixture only when explicitly requested for visual QA.
      final output = Platform.environment['PH_REPORT_QA_PATH'];
      if (output != null) await File(output).writeAsBytes(bytes);
      await HistoryService.deleteRecord(restored);
      expect(await HistoryService.getAllRecords(), isEmpty);
      expect(File(restored.imagePath).existsSync(), isFalse);
    },
  );

  test(
    'missing image save fails and does not create a history record',
    () async {
      await expectLater(
        HistoryService.savePrediction(
          phValue: 7,
          tempImagePath: '${directory.path}/missing.png',
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await HistoryService.getAllRecords(), isEmpty);
    },
  );

  test(
    'legacy records load with unknown validation rather than invented metadata',
    () async {
      Hive.registerAdapter(_LegacyAdapter(), override: true);
      var box = await Hive.openBox<PredictionRecord>(HistoryService.boxName);
      await box.put(
        'old',
        PredictionRecord(
          id: 'old',
          phValue: 7,
          imagePath: photo,
          timestamp: measuredAt,
        ),
      );
      await box.close();
      Hive.registerAdapter(PredictionRecordAdapter(), override: true);
      box = await Hive.openBox<PredictionRecord>(HistoryService.boxName);
      expect(box.get('old')!.measurement, isNull);
      expect(box.get('old')!.statusLabel, contains('unknown'));
    },
  );

  test('corrupted database is an error, not an empty history', () async {
    final box = await HistoryService.getBox();
    await box.close();
    // A valid Hive box containing a value of the wrong type is not an empty history.
    final raw = await Hive.openBox<dynamic>(HistoryService.boxName);
    await raw.put('bad', 'not a PredictionRecord');
    await raw.close();
    await expectLater(HistoryService.getAllRecords(), throwsA(anything));
  });
}

class _LegacyAdapter extends TypeAdapter<PredictionRecord> {
  @override
  int get typeId => 0;
  @override
  PredictionRecord read(BinaryReader reader) => throw UnimplementedError();
  @override
  void write(BinaryWriter writer, PredictionRecord record) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(record.id)
      ..writeByte(1)
      ..write(record.phValue)
      ..writeByte(2)
      ..write(record.imagePath)
      ..writeByte(3)
      ..write(record.timestamp)
      ..writeByte(4)
      ..write(record.note);
  }
}
