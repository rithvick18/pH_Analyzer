import 'dart:io';
import 'dart:ui' show Rect;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/prediction_record.dart';

class HistoryService {
  static const String boxName = 'ph_predictions';
  static const _uuid = Uuid();

  static Future<Box<PredictionRecord>> getBox() async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<PredictionRecord>(boxName);
    }
    return await Hive.openBox<PredictionRecord>(boxName);
  }

  /// Saves a prediction record, copying the temp image to permanent documents storage.
  static Future<PredictionRecord> savePrediction({
    required double phValue,
    required String tempImagePath,
    String? note,
    Rect? dyeRect,
    Rect? bgRect,
  }) async {
    final box = await getBox();
    final docDir = await getApplicationDocumentsDirectory();

    String permanentImagePath = tempImagePath;
    final tempFile = File(tempImagePath);
    if (await tempFile.exists()) {
      final String fileName = 'ph_img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String targetPath = '${docDir.path}/$fileName';
      await tempFile.copy(targetPath);
      permanentImagePath = targetPath;
    }

    final record = PredictionRecord(
      id: _uuid.v4(),
      phValue: phValue,
      imagePath: permanentImagePath,
      timestamp: DateTime.now(),
      note: note,
      dyeLeft: dyeRect?.left,
      dyeTop: dyeRect?.top,
      dyeWidth: dyeRect?.width,
      dyeHeight: dyeRect?.height,
      bgLeft: bgRect?.left,
      bgTop: bgRect?.top,
      bgWidth: bgRect?.width,
      bgHeight: bgRect?.height,
    );

    await box.put(record.id, record);
    return record;
  }

  /// Retrieves all saved prediction records ordered newest first.
  static Future<List<PredictionRecord>> getAllRecords() async {
    final box = await getBox();
    final records = box.values.toList();
    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return records;
  }

  /// Deletes a record from Hive and removes the associated image file.
  static Future<void> deleteRecord(PredictionRecord record) async {
    final imageFile = File(record.imagePath);
    if (await imageFile.exists()) {
      try {
        await imageFile.delete();
      } catch (_) {
        // Ignore file delete errors if system cleaned up
      }
    }
    await record.delete();
  }

  /// Clears all records.
  static Future<void> clearAll() async {
    final box = await getBox();
    for (final record in box.values) {
      final imageFile = File(record.imagePath);
      if (await imageFile.exists()) {
        try {
          await imageFile.delete();
        } catch (_) {}
      }
    }
    await box.clear();
  }
}
