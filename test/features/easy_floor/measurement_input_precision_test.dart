import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_shapes.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/dimension_dialog.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/shape_dialog.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';

void main() {
  test('Compact input trims zeros and carries rounded inches into feet', () {
    expect(DrawingUnit.metres.input(2345.678, decimalPlaces: 2), '2.35');
    expect(DrawingUnit.mm.input(2000, decimalPlaces: 2), '2000');
    expect(DrawingUnit.feetInches.input(304.79, decimalPlaces: 2), '1 0');
  });

  for (final unit in DrawingUnit.values) {
    testWidgets('${unit.symbol}: rounded fields retain exact wall dimensions',
        (t) async {
      (double, double?, bool)? result;
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        result = await showDialog<(double, double?, bool)>(
                            context: context,
                            builder: (_) => DimensionDialog(
                                valueMm: 10, secondMm: 1234.567, unit: unit));
                      },
                      child: const Text('Open'))))));
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      final fields = find.byType(TextFormField);
      expect(t.widget<TextFormField>(fields.first).controller!.text,
          unit.input(10, decimalPlaces: 2));
      expect(t.widget<TextFormField>(fields.last).controller!.text,
          unit.input(1234.567, decimalPlaces: 2));
      await t.tap(find.byType(DropdownButtonFormField<DrawingUnit>));
      await t.pumpAndSettle();
      final next = unit == DrawingUnit.mm ? DrawingUnit.feet : DrawingUnit.mm;
      await t.tap(find.text(next.name).last);
      await t.pumpAndSettle();
      await t.tap(find.text('Apply'));
      await t.pumpAndSettle();
      expect(result!.$1, 10);
      expect(result!.$2, 1234.567);
    });

    testWidgets(
        '${unit.symbol}: preset fields are compact without changing geometry',
        (t) async {
      for (final kind
          in ShapePreset.values.where((k) => k != ShapePreset.polygon)) {
        final spec = ShapeSpec(kind, 1234.567, 2345.678, 0);
        ShapeSpec? result;
        await t.pumpWidget(MaterialApp(
            theme: AppTheme.light,
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () async {
                          result = await showDialog<ShapeSpec>(
                              context: context,
                              builder: (_) =>
                                  ShapeDialog(spec: spec, unit: unit));
                        },
                        child: const Text('Open'))))));
        await t.tap(find.text('Open'));
        await t.pumpAndSettle();
        for (final m in spec.measurements) {
          final field = find.descendant(
              of: find.byKey(ValueKey(m.id)),
              matching: find.byType(TextFormField));
          expect(t.widget<TextFormField>(field).controller!.text,
              unit.input(m.value, decimalPlaces: 2));
        }
        await t.tap(find.text('Preview'));
        await t.pumpAndSettle();
        final actual = result!.points(const DrawingPoint(0, 0));
        final expected = spec.points(const DrawingPoint(0, 0));
        for (var i = 0; i < expected.length; i++) {
          expect((actual[i] - expected[i]).length, 0);
        }
      }
    });
  }
}
