import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/calibration_data.dart';
import '../models/calibration_profile.dart';

class CalibrationProfileService {
  static const boxName = 'calibration_profiles';
  static const bundledId = 'bundled-experimental';
  static const _activeKey = '__active_profile_id__';
  static final revision = ValueNotifier<int>(0);
  static Future<void> _queue = Future.value();

  static Future<T> _serial<T>(Future<T> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  static Future<Box<String>> getBox() async => Hive.isBoxOpen(boxName)
      ? Hive.box<String>(boxName)
      : Hive.openBox<String>(boxName);

  static String newId() => const Uuid().v4();

  static Future<CalibrationData> bundled() async =>
      CalibrationData.fromJsonString(
        await rootBundle.loadString('assets/calibration.json'),
      );

  static Future<List<CalibrationProfile>> getAll() async {
    final box = await getBox();
    final profiles = <CalibrationProfile>[];
    for (final key in box.keys) {
      if (key == _activeKey) continue;
      try {
        final decoded = jsonDecode(box.get(key)!);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Invalid profile.');
        }
        final profile = CalibrationProfile.fromJson(decoded);
        if (profile.id != key) {
          throw const FormatException('Profile ID mismatch.');
        }
        profiles.add(profile);
      } catch (_) {
        throw FormatException(
          'A saved calibration profile is damaged or incompatible ($key). History was not changed.',
        );
      }
    }
    profiles.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return profiles;
  }

  static Future<String> activeId() async {
    final box = await getBox();
    return box.get(_activeKey) ?? bundledId;
  }

  static Future<void> select(String id) => _serial(() async {
    if (id != bundledId && !(await getAll()).any((p) => p.id == id)) {
      throw const FormatException(
        'Selected profile is unavailable. Choose another calibration.',
      );
    }
    final box = await getBox();
    await box.put(_activeKey, id);
    revision.value++;
  });

  static Future<(CalibrationData, String)> activeSnapshot() async {
    final id = await activeId();
    if (id == bundledId) return (await bundled(), 'Bundled experimental');
    final profiles = await getAll();
    for (final profile in profiles) {
      if (profile.id == id) return (profile.calibration, profile.name);
    }
    throw const FormatException(
      'The selected calibration profile is missing. Choose another calibration.',
    );
  }

  static Future<void> save(CalibrationProfile profile) => _serial(() async {
    // Validate the serialized form before writing; editing increments version in the UI.
    CalibrationProfile.fromJson(profile.toJson());
    final box = await getBox();
    final prior = box.get(profile.id);
    if (prior != null) {
      final decoded = jsonDecode(prior);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Existing profile is damaged.');
      }
      final old = CalibrationProfile.fromJson(decoded);
      if (profile.version <= old.version) {
        throw const FormatException('Edited profile version must increase.');
      }
    }
    await box.put(profile.id, jsonEncode(profile.toJson()));
    revision.value++;
  });

  static Future<void> delete(String id) => _serial(() async {
    if (id == bundledId) {
      throw const FormatException('Bundled calibration cannot be deleted.');
    }
    final box = await getBox();
    if (box.get(_activeKey) == id) {
      await box.put(_activeKey, bundledId);
    }
    await box.delete(id);
    revision.value++;
  });
}
