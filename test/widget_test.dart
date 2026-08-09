import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:ph_analyzer/models/prediction_record.dart';
import 'package:ph_analyzer/screens/home_screen.dart';
import 'package:ph_analyzer/screens/live_camera_screen.dart';

void main() {
  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('hive_widget_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PredictionRecordAdapter());
    }
  });
  testWidgets('App launches and displays HomeScreen with pH Lens title', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    expect(find.text('Scan Dye Paper'), findsOneWidget);
  });

  testWidgets('LiveCameraScreen renders and toggles Manual Reference ROI', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(home: LiveCameraScreen()));
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    expect(find.text('Ref Image'), findsOneWidget);
    expect(find.text('Manual Ref'), findsOneWidget);
    expect(find.byKey(const Key('gallery_button')), findsOneWidget);

    final refImageSwitchFinder = find.byKey(const Key('reference_image_toggle'));
    expect(refImageSwitchFinder, findsOneWidget);
    await tester.tap(refImageSwitchFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Showing reference.jpeg. Position ROI box over dye pad.'), findsOneWidget);

    final switchFinder = find.byKey(const Key('manual_reference_toggle'));
    expect(switchFinder, findsOneWidget);

    await tester.tap(switchFinder);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Dye Pad (Red)'), findsOneWidget);
    expect(find.text('Reference (Blue)'), findsOneWidget);
  });

  testWidgets('LiveCameraScreen supports 3-state flash control, zoom pills, and EV exposure slider', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(home: LiveCameraScreen()));
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    // 1. Flash mode 3-state cycling
    final torchToggleFinder = find.byKey(const Key('torch_toggle'));
    expect(torchToggleFinder, findsOneWidget);

    // Cycle Flash Off -> Flash Torch
    await tester.tap(torchToggleFinder);
    await tester.pump();

    // Cycle Flash Torch -> Flash Auto
    await tester.tap(torchToggleFinder);
    await tester.pump();

    // Cycle Flash Auto -> Flash Off
    await tester.tap(torchToggleFinder);
    await tester.pump();

    // 2. Zoom level indicator & Zoom pills (1x, 1.5x, 2x)
    expect(find.text('1.5x'), findsWidgets); // Default zoom badge & chip
    expect(find.text('1x'), findsOneWidget);
    expect(find.text('2x'), findsOneWidget);

    // Tap 2x zoom pill
    await tester.tap(find.text('2x'));
    await tester.pump();
    expect(find.text('2.0x'), findsOneWidget); // Zoom badge updated to 2.0x

    // 3. EV Exposure Slider toggle & interaction
    final evButtonFinder = find.byIcon(Icons.exposure);
    expect(evButtonFinder, findsOneWidget);
    await tester.tap(evButtonFinder);
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsOneWidget);

    // 4. Verify preview gestures (tap-to-focus and double-tap reset)
    final previewFinder = find.byType(GestureDetector).first;
    await tester.tap(previewFinder);
    await tester.pump();

    // Double tap preview to reset focus/exposure
    await tester.tap(previewFinder);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(previewFinder);
    await tester.pumpAndSettle();
  });
}
