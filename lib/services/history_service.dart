import 'dart:async';
import 'dart:io';
import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/measurement.dart';
import '../models/prediction_record.dart';

class HistoryService {
  static const String boxName = 'ph_predictions';
  static const _uuid = Uuid();
  static final ValueNotifier<int> revision = ValueNotifier(0);
  static Future<void> _writeQueue = Future.value();

  static Future<T> _serial<T>(Future<T> Function() action) {
    final next = _writeQueue.then((_) => action());
    _writeQueue = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  static Future<Box<PredictionRecord>> getBox() async {
    PredictionRecord.storageDirectory =
        (await getApplicationDocumentsDirectory()).path;
    return Hive.isBoxOpen(boxName)
        ? Hive.box<PredictionRecord>(boxName)
        : await Hive.openBox<PredictionRecord>(boxName);
  }

  /// Copy first, commit the record, roll back a failed commit. UUID names avoid collisions.
  static Future<PredictionRecord> savePrediction({
    required double phValue,
    required String tempImagePath,
    String? note,
    Rect? dyeRect,
    Rect? bgRect,
    Measurement? measurement,
  }) => _serial(() async {
    if (!phValue.isFinite ||
        phValue < 0 ||
        phValue > 14 ||
        (measurement != null && measurement.ph != phValue)) {
      throw ArgumentError('Invalid measurement.');
    }
    final source = File(tempImagePath);
    if (!await source.exists()) {
      throw const FileSystemException(
        'The measurement image is missing. Retake the sample before saving.',
      );
    }
    final box = await getBox();
    final id = _uuid.v4();
    final relativePath = 'ph_measurements/$id.png';
    final target = File('${PredictionRecord.storageDirectory}/$relativePath');
    await target.parent.create(recursive: true);
    final record = PredictionRecord(
      id: id,
      phValue: phValue,
      imagePath: relativePath,
      timestamp: measurement?.measuredAt ?? DateTime.now(),
      note: note,
      measurement: measurement,
      dyeLeft: dyeRect?.left,
      dyeTop: dyeRect?.top,
      dyeWidth: dyeRect?.width,
      dyeHeight: dyeRect?.height,
      bgLeft: bgRect?.left,
      bgTop: bgRect?.top,
      bgWidth: bgRect?.width,
      bgHeight: bgRect?.height,
    );
    try {
      await source.copy(target.path);
      await box.put(record.id, record);
    } catch (_) {
      // A partially completed write must not cause an image referenced by a record to disappear.
      if (!box.containsKey(id) && await target.exists()) await target.delete();
      rethrow;
    }
    revision.value++;
    return record;
  });

  static Future<List<PredictionRecord>> getAllRecords() async {
    final box = await getBox();
    final records = box.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return records;
  }

  static Future<void> _deleteOwnedImage(PredictionRecord record) async {
    final path = record.imagePath;
    final root = PredictionRecord.storageDirectory!;
    // Never delete arbitrary external paths carried by legacy records.
    if (!path.startsWith('$root/ph_measurements/') &&
        !path.startsWith('$root/ph_img_')) {
      return;
    }
    final file = File(path);
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      /* An orphan can be retried by cleanup on next startup. */
    }
  }

  static Future<void> deleteRecord(PredictionRecord record) =>
      _serial(() async {
        final box = await getBox();
        await box.delete(record.id);
        await _deleteOwnedImage(record);
        revision.value++;
      });

  static Future<void> clearAll() => _serial(() async {
    final box = await getBox();
    final records = box.values.toList();
    await box.clear();
    for (final record in records) {
      await _deleteOwnedImage(record);
    }
    revision.value++;
  });

  /// Runs only at startup. Do not delete any file until the database was read successfully.
  static Future<void> cleanupOrphans() => _serial(() async {
    final records = await getAllRecords();
    final referenced = records.map((r) => r.imagePath).toSet();
    final root = Directory(PredictionRecord.storageDirectory!);
    final directory = Directory('${root.path}/ph_measurements');
    if (await directory.exists()) {
      await for (final entry in directory.list(followLinks: false)) {
        if (entry is File &&
            !referenced.contains(entry.path) &&
            DateTime.now().difference(await entry.lastModified()).inHours >=
                24) {
          await entry.delete();
        }
      }
    }
  });
}
