import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_shapes.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/drawing_length_field.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/shape_dialog.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/shape_diagram.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'preset_dimensions_test.dart' show customPresets;
import 'drawing_screen_test.dart' as harness;
import 'shape_interaction_test.dart' show menu;

Finder input(ShapeDimension id) => find.descendant(
    of: find.byKey(ValueKey(id)), matching: find.byType(TextFormField));
ShapeDiagram diagram(WidgetTester t) => t
    .widget<CustomPaint>(find.byKey(const ValueKey('shapeDimensionDiagram')))
    .painter! as ShapeDiagram;
Future<void> edit(WidgetTester t, ShapeDimension id, String value) async {
  await t.ensureVisible(input(id));
  await t.tap(input(id));
  await t.enterText(input(id), value);
  await t.pump();
}

void main() {
  for (final unit in DrawingUnit.values) {
    for (final spec in customPresets) {
      testWidgets('${spec.kind.label} dimension entry in ${unit.symbol}',
          (t) async {
        t.view.physicalSize = const Size(320, 740);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        ShapeSpec? result;
        await t.pumpWidget(MaterialApp(
            theme: AppTheme.light,
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () async {
                          result = await showDialog<ShapeSpec>(
                              context: context,
                              builder: (_) => ShapeDialog(
                                  spec: ShapeSpec(spec.kind, 6000, 5000, 0),
                                  unit: unit));
                        },
                        child: const Text('Open'))))));
        await t.tap(find.text('Open'));
        await t.pumpAndSettle();
        expect(find.byType(DrawingLengthField),
            findsNWidgets(spec.measurements.length));
        for (final m in spec.measurements) {
          await edit(t, m.id, unit.input(m.value));
          expect(diagram(t).active, m.id);
        }
        await t.tap(find.text('Preview'));
        await t.pumpAndSettle();
        expect(result, isNotNull);
        final actual = result!.points(const DrawingPoint(0, 0));
        final expected = spec.points(const DrawingPoint(0, 0));
        for (var i = 0; i < actual.length; i++) {
          expect((actual[i] - expected[i]).length, closeTo(0, 1e-6));
        }
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('Conflicting dimensions hide stale preview and block placement',
      (t) async {
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: ShapeDialog(spec: customPresets[4], unit: DrawingUnit.mm))));
    await edit(t, ShapeDimension.leftArm, '5000');
    expect(find.textContaining('Leave an opening'), findsOneWidget);
    expect(find.byKey(const ValueKey('shapeDimensionDiagram')), findsNothing);
    await t.tap(find.text('Preview'));
    await t.pump();
    expect(find.byType(ShapeDialog), findsOneWidget);
    await edit(t, ShapeDimension.leftArm, '1200');
    expect(diagram(t).spec.leftArm, 1200);
    expect(find.textContaining('Leave an opening'), findsNothing);
    await edit(t, ShapeDimension.leftArm, '');
    expect(find.text('Enter valid dimensions to preview'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'U-shape diagram stays visible above scrolled fields and keyboard',
      (t) async {
    t.view.physicalSize = const Size(320, 740);
    t.view.devicePixelRatio = 1;
    t.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetViewInsets);
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showDialog<ShapeSpec>(
                        context: context,
                        builder: (_) => ShapeDialog(
                            spec: customPresets[4], unit: DrawingUnit.mm)),
                    child: const Text('Open'))))));
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    final finder = find.byKey(const ValueKey('shapeDimensionDiagram'));
    final before = t.getRect(finder);
    await edit(t, ShapeDimension.base, '950');
    await t.pumpAndSettle();
    expect(t.getRect(finder), before);
    expect(diagram(t).spec.base, 950);
    expect(diagram(t).active, ShapeDimension.base);
    expect(before.bottom, lessThan(460));
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Custom L preview can be re-edited and placed with exact wall lengths',
      (t) async {
    await harness.open(t);
    await menu(t, 'Shape presets', 'L-shape');
    final unit = harness.painter(t).unit;
    await edit(t, ShapeDimension.width, unit.input(4000));
    await edit(t, ShapeDimension.height, unit.input(3000));
    await edit(t, ShapeDimension.verticalArm, unit.input(1000));
    await edit(t, ShapeDimension.horizontalArm, unit.input(900));
    await t.tap(find.text('Preview'));
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls, isEmpty);
    await t.ensureVisible(find.text('Dimensions / rotation'));
    await t.tap(find.text('Dimensions / rotation'));
    await t.pumpAndSettle();
    expect(diagram(t).spec.verticalArm, 1000);
    await edit(t, ShapeDimension.horizontalArm, unit.input(800));
    await t.tap(find.text('Preview'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Place shape'));
    await t.tap(find.text('Place shape'));
    await t.pumpAndSettle();
    final model = harness.painter(t).model;
    expect(model.walls.length, 6);
    final lengths = model.walls.keys.map(model.length).toList()..sort();
    final expected = <double>[4000, 800, 3000, 2200, 1000, 3000]..sort();
    for (var i = 0; i < lengths.length; i++) {
      expect(lengths[i], closeTo(expected[i], 1e-7));
    }
    expect(t.takeException(), isNull);
  });
}
