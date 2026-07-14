import 'package:hive/hive.dart';

class PredictionRecord extends HiveObject {
  String id;
  double phValue;
  String imagePath;
  DateTime timestamp;
  String? note;

  // Optional ROI fields for re-displaying overlays or generating reports
  double? dyeLeft;
  double? dyeTop;
  double? dyeWidth;
  double? dyeHeight;
  double? bgLeft;
  double? bgTop;
  double? bgWidth;
  double? bgHeight;

  PredictionRecord({
    required this.id,
    required this.phValue,
    required this.imagePath,
    required this.timestamp,
    this.note,
    this.dyeLeft,
    this.dyeTop,
    this.dyeWidth,
    this.dyeHeight,
    this.bgLeft,
    this.bgTop,
    this.bgWidth,
    this.bgHeight,
  });
}

class PredictionRecordAdapter extends TypeAdapter<PredictionRecord> {
  @override
  final int typeId = 0;

  @override
  PredictionRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PredictionRecord(
      id: fields[0] as String,
      phValue: (fields[1] as num).toDouble(),
      imagePath: fields[2] as String,
      timestamp: fields[3] as DateTime,
      note: fields[4] as String?,
      dyeLeft: fields[5] != null ? (fields[5] as num).toDouble() : null,
      dyeTop: fields[6] != null ? (fields[6] as num).toDouble() : null,
      dyeWidth: fields[7] != null ? (fields[7] as num).toDouble() : null,
      dyeHeight: fields[8] != null ? (fields[8] as num).toDouble() : null,
      bgLeft: fields[9] != null ? (fields[9] as num).toDouble() : null,
      bgTop: fields[10] != null ? (fields[10] as num).toDouble() : null,
      bgWidth: fields[11] != null ? (fields[11] as num).toDouble() : null,
      bgHeight: fields[12] != null ? (fields[12] as num).toDouble() : null,
    );
  }

  @override
  void write(BinaryWriter writer, PredictionRecord obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.phValue)
      ..writeByte(2)
      ..write(obj.imagePath)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.note)
      ..writeByte(5)
      ..write(obj.dyeLeft)
      ..writeByte(6)
      ..write(obj.dyeTop)
      ..writeByte(7)
      ..write(obj.dyeWidth)
      ..writeByte(8)
      ..write(obj.dyeHeight)
      ..writeByte(9)
      ..write(obj.bgLeft)
      ..writeByte(10)
      ..write(obj.bgTop)
      ..writeByte(11)
      ..write(obj.bgWidth)
      ..writeByte(12)
      ..write(obj.bgHeight);
  }
}
