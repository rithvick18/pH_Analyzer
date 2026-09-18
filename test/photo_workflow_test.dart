import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:ph_analyzer/models/prediction_record.dart';
import 'package:ph_analyzer/screens/roi_selector.dart';
import 'package:ph_analyzer/screens/history_screen.dart';
import 'package:ph_analyzer/services/history_service.dart';

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 60; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsWidgets);
}

void main() {
  testWidgets(
    'confirm demo pixels, analyze offline, save, and reopen with provenance',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync('ph_flow_');
      final image = img.Image(width: 120, height: 80);
      img.fill(image, color: img.ColorRgb8(96, 87, 68));
      final path = '${directory.path}/photo.png';
      File(path).writeAsBytesSync(img.encodePng(image));
      Hive.init(directory.path);
      Hive.registerAdapter(PredictionRecordAdapter(), override: true);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => directory.path,
          );
      try {
        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: ROISelector(imagePath: path, source: 'demo'),
            ),
          );
        });
        await waitFor(tester, find.text('DEMO — Confirm regions'));
        await tester.binding.setSurfaceSize(const Size(320, 568));
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        await tester.pump();
        expect(tester.takeException(), isNull);
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.binding.setSurfaceSize(null);
        await tester.pump();
        await tester.tap(
          find.byTooltip('Place or reset active region at center'),
        );
        await tester.tap(find.text('Measure reference paper'));
        await tester.pump();
        await tester.ensureVisible(
          find.text('Analyze as an unvalidated estimate'),
        );
        await tester.runAsync(() async {
          await tester.tap(find.text('Analyze as an unvalidated estimate'));
          await tester.pump();
        });
        await waitFor(tester, find.text('DEMO • Not a sample measurement'));
        expect(find.textContaining('fixed background color'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Save to History'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.runAsync(() async {
          await tester.tap(find.text('Save to History'));
        });
        await waitFor(tester, find.text('Saved to History'));
        await tester.runAsync(() async {
          final record = (await HistoryService.getAllRecords()).single;
          expect(record.measurement!.isDemo, isTrue);
          expect(record.phValue, 7);
          expect(record.measurement!.validationStatus, 'not_validated');
        });
        await tester.runAsync(() async {
          await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
        });
        await waitFor(tester, find.text('DEMO • Not a sample measurement'));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await Hive.close();
          await directory.delete(recursive: true);
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              null,
            );
      }
    },
  );
}
