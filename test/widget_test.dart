import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/main.dart';

void main() {
  testWidgets('Grid Ceiling Calculator smoke test',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GridCeilingCalculatorApp());

    expect(find.text('BuildCalc'), findsOneWidget);
    expect(find.text('Grid Ceiling'), findsOneWidget);
    expect(find.text('Unit Converter'), findsOneWidget);
  });
}
