import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/dimension_dialog.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';

void main() {
  for (final unit in DrawingUnit.values) {
    testWidgets('Keyboard applies an exact ${unit.symbol} dimension',
        (t) async {
      (double, double?, bool)? result;
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: Builder(builder: (context) {
            return Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await showDialog<(double, double?, bool)>(
                          context: context,
                          builder: (_) => DimensionDialog(
                              valueMm: 2000, unit: unit, showLock: false));
                    },
                    child: const Text('Edit')));
          })));
      await t.tap(find.text('Edit'));
      await t.pumpAndSettle();
      final editable = t.widget<EditableText>(find.byType(EditableText));
      expect(editable.focusNode.hasFocus, isTrue);
      expect(
          editable.controller.selection,
          TextSelection(
              baseOffset: 0, extentOffset: editable.controller.text.length));
      final input = find.byType(TextFormField);
      await t.enterText(input, '0');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(find.byType(DimensionDialog), findsOneWidget);
      expect(result, isNull);
      await t.enterText(input, unit.input(3352.8));
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(find.byType(DimensionDialog), findsNothing);
      expect(result!.$1, closeTo(3352.8, .000001));
      expect(result!.$2, isNull);
      expect(result!.$3, isFalse);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('Keyboard submission validates both rectangle dimensions',
      (t) async {
    (double, double?, bool)? result;
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Builder(builder: (context) {
          return Scaffold(
              body: TextButton(
                  onPressed: () async {
                    result = await showDialog<(double, double?, bool)>(
                        context: context,
                        builder: (_) => const DimensionDialog(
                            valueMm: 2000,
                            secondMm: 3000,
                            unit: DrawingUnit.mm));
                  },
                  child: const Text('Edit')));
        })));
    await t.tap(find.text('Edit'));
    await t.pumpAndSettle();
    final inputs = find.byType(TextFormField);
    await t.enterText(inputs.last, '0');
    await t.enterText(inputs.first, '4000');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(result, isNull);
    expect(find.byType(DimensionDialog), findsOneWidget);
    await t.enterText(inputs.last, '5000');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(result!.$1, 4000);
    expect(result!.$2, 5000);
    expect(t.takeException(), isNull);
  });
}
