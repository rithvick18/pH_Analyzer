import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ph_analyzer/main.dart';
import 'package:ph_analyzer/screens/live_camera_screen.dart';

void main() {
  testWidgets('App launches and displays HomeScreen with pH Analyzer title', (WidgetTester tester) async {
    await tester.pumpWidget(const PHAnalyzerApp());
    expect(find.text('pH Analyzer'), findsOneWidget);
    expect(find.text('How It Works'), findsOneWidget);
  });

  testWidgets('LiveCameraScreen renders and toggles Manual Reference ROI', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(home: LiveCameraScreen()));
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    expect(find.text('Ref Image'), findsOneWidget);
    expect(find.text('Manual Ref'), findsOneWidget);

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
