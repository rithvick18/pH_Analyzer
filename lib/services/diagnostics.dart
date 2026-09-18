import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Local, bounded diagnostics. Never stores image data, paths, notes, or exception messages.
class Diagnostics {
  static final List<Map<String, Object>> _events = [];
  static File? _file;
  static Future<void> _writes = Future.value();

  static Future<void> initialize() async {
    try {
      _file = File(
        '${(await getApplicationSupportDirectory()).path}/ph_diagnostics.json',
      );
      if (await _file!.exists()) {
        final entries = jsonDecode(await _file!.readAsString());
        if (entries is List) {
          for (final e in entries.take(30)) {
            if (e is Map &&
                e['time'] is String &&
                e['stage'] is String &&
                e['type'] is String) {
              _events.add({
                'time': e['time'],
                'stage': e['stage'],
                'type': e['type'],
              });
            }
          }
        }
      }
    } catch (_) {
      _file = null;
    }
  }

  static void record(String stage, Object error) {
    _events.add({
      'time': DateTime.now().toUtc().toIso8601String(),
      'stage': stage,
      'type': error.runtimeType.toString(),
    });
    while (_events.length > 30) {
      _events.removeAt(0);
    }
    debugPrint('pH diagnostic: $stage (${error.runtimeType})');
    final file = _file;
    if (file == null) return;
    final data = jsonEncode(_events);
    _writes = _writes.then((_) async {
      try {
        await file.parent.create(recursive: true);
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(data, flush: true);
        await temporary.rename(file.path);
      } catch (_) {
        /* Diagnostics must not interrupt a measurement. */
      }
    });
    unawaited(_writes);
  }

  static String get summary => const JsonEncoder.withIndent(
    '  ',
  ).convert({'platform': defaultTargetPlatform.name, 'events': _events});
}
