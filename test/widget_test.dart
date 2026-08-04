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
}

