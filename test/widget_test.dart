import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:ph_analyzer/models/prediction_record.dart';
import 'package:ph_analyzer/screens/home_screen.dart';
import 'package:ph_analyzer/screens/live_camera_screen.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ph_widgets_');
    Hive.init(directory.path);
    Hive.registerAdapter(PredictionRecordAdapter(), override: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => directory.path,
        );
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

  testWidgets('home shows estimate workflow without fake confidence', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    expect(find.text('Scan Dye Paper'), findsOneWidget);
    expect(find.text('94%'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('camera failure cannot capture or silently display demo data', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LiveCameraScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Camera unavailable'), findsOneWidget);
    final capture = tester.widget<FilledButton>(
      find.byKey(const Key('capture_button')),
    );
    expect(capture.onPressed, isNull);
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(const Key('gallery_button')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('demo mode requires an explicit choice and labels capture', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LiveCameraScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reference_image_toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Use labeled demo'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('capture_button')))
          .onPressed,
      isNotNull,
    );
    expect(find.text('Capture and select regions'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'camera screen tolerates background resume and disposal during init',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LiveCameraScreen()));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
