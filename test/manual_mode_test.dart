import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ph_analyzer/screens/first_run_screen.dart';
import 'package:ph_analyzer/services/analyzer_isolate.dart';

void main() {
  testWidgets('first launch offers a calibration path without a Gemini key', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: FirstRunScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Continue in manual mode'), findsOneWidget);
    await tester.tap(find.text('Continue in manual mode'));
    await tester.pump();
    expect(find.text('Choose a calibration'), findsOneWidget);
    expect(
      find.textContaining('Dye-pad identity is not checked by AI'),
      findsOneWidget,
    );
  });

  test(
    'manual sample estimates pH locally and records lack of AI validation',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final directory = Directory.systemTemp.createTempSync('ph_manual_');
      try {
        final image = img.Image(width: 20, height: 20);
        img.fill(image, color: img.ColorRgb8(111, 92, 81));
        final path = '${directory.path}/sample.png';
        File(path).writeAsBytesSync(img.encodePng(image));
        final result = await AnalyzerService.analyze(
          imagePath: path,
          dyeRect: const Rect.fromLTWH(0, 0, 20, 20),
          manualMode: true,
        );
        expect(result.measurement.validationStatus, 'manual_unvalidated');
        expect(
          result.measurement.validationReason,
          contains('no AI dye-pad identity check'),
        );
        expect(result.measurement.ph, inInclusiveRange(0, 14));
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
