import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:grid_ceiling_calculator/ui/app_widgets.dart';

void main() {
  testWidgets('Measurement marker and unit stay visible even when empty',
      (t) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: AppNumberField(
                label: 'Left shoulder (optional)',
                controller: controller,
                validator: (_) => null,
                leadingLabel: 'E',
                unit: 'ft',
                labelAbove: true,
                textAlign: TextAlign.end))));
    expect(find.text('E'), findsOneWidget);
    expect(find.text('ft'), findsOneWidget);
    final input = find.byType(TextFormField);
    expect(
        t
            .widget<TextField>(
                find.descendant(of: input, matching: find.byType(TextField)))
            .textAlign,
        TextAlign.end);
    await t.enterText(input, '14.5');
    await t.pumpAndSettle();
    expect(controller.text, '14.5');
    expect(find.text('ft'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Existing numeric fields keep their unadorned default',
      (t) async {
    final controller = TextEditingController(text: '12');
    addTearDown(controller.dispose);
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: AppNumberField(
                label: 'Width',
                controller: controller,
                validator: (_) => null))));
    final input = t.widget<TextField>(find.byType(TextField));
    expect(input.textAlign, TextAlign.start);
    expect(input.decoration!.prefixIcon, isNull);
    expect(input.decoration!.suffixIcon, isNull);
  });
}
