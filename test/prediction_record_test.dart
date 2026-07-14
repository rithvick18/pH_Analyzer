import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:ph_analyzer/models/prediction_record.dart';

void main() {
  group('PredictionRecord Hive Tests', () {
    late Directory tempDir;
    late Box<PredictionRecord> box;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_test_box');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(PredictionRecordAdapter());
      }
      box = await Hive.openBox<PredictionRecord>('test_predictions');
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('test_predictions');
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Creates, saves, and reads back a PredictionRecord accurately', () async {
      final now = DateTime.now();
      final record = PredictionRecord(
        id: 'test-uuid-1234',
        phValue: 6.85,
        imagePath: '/path/to/test_image.jpg',
        timestamp: now,
        note: 'Well water sample #1',
        dyeLeft: 10.0,
        dyeTop: 20.0,
        dyeWidth: 50.0,
        dyeHeight: 50.0,
        bgLeft: 100.0,
        bgTop: 120.0,
        bgWidth: 60.0,
        bgHeight: 60.0,
      );

      await box.put(record.id, record);

      final retrieved = box.get('test-uuid-1234');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('test-uuid-1234'));
      expect(retrieved.phValue, closeTo(6.85, 0.001));
      expect(retrieved.imagePath, equals('/path/to/test_image.jpg'));
      expect(retrieved.note, equals('Well water sample #1'));
      expect(retrieved.dyeLeft, equals(10.0));
      expect(retrieved.dyeWidth, equals(50.0));
      expect(retrieved.bgTop, equals(120.0));
    });
  });
}
