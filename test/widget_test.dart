import 'package:flutter_test/flutter_test.dart';
import 'package:ph_analyzer/main.dart';

void main() {
  testWidgets('App launches and displays HomeScreen with pH Analyzer title', (WidgetTester tester) async {
    await tester.pumpWidget(const PHAnalyzerApp());
    expect(find.text('pH Analyzer'), findsOneWidget);
    expect(find.text('How It Works'), findsOneWidget);
  });
}
