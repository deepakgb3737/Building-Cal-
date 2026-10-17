import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_shapes.dart';
import 'drawing_screen_test.dart' as board;
import 'preset_dialog_test.dart' show edit, input, diagram;
import 'shape_interaction_test.dart' show menu;

const entered = {
  ShapeDimension.width: '20.58',
  ShapeDimension.height: '21.39',
  ShapeDimension.verticalArm: '9.88',
  ShapeDimension.horizontalArm: '10.70',
};
const letters = {
  ShapeDimension.width: 'A',
  ShapeDimension.height: 'B',
  ShapeDimension.verticalArm: 'C',
  ShapeDimension.horizontalArm: 'D',
};

void verify(WidgetTester t, {bool typed = false}) {
  final preview = diagram(t).spec;
  expect(preview.dimensionErrors, isEmpty);
  for (final measurement in preview.measurements) {
    final field = t.widget<TextFormField>(input(measurement.id));
    final text = field.controller!.text;
    expect(double.parse(text), double.parse(entered[measurement.id]!));
    if (typed) expect(text, entered[measurement.id]);
    expect(measurement.letter, letters[measurement.id]);
    expect(measurement.value,
        closeTo(double.parse(entered[measurement.id]!) * 304.8, 1e-7));
    expect(find.text('${measurement.letter} · ${measurement.name} (ft)'),
        findsOneWidget);
    expect(field.validator!(text), isNull);
  }
}

void main() {
  test('Dimension letters follow semantic identity, not measurement ordering',
      () {
    for (final kind
        in ShapePreset.values.where((k) => k != ShapePreset.polygon)) {
      final spec = ShapeSpec(kind, 5000, 7000, 0);
      final expected = [
        'A',
        if (kind != ShapePreset.square) 'B',
        if ([ShapePreset.lShape, ShapePreset.tShape, ShapePreset.uShape]
            .contains(kind)) ...['C', 'D'],
        if (kind == ShapePreset.uShape) 'E',
      ];
      expect(spec.measurements.map((m) => m.letter), expected);
      expect(
          spec.measurements.reversed.map((m) => m.letter), expected.reversed);
    }
  });

  for (final orientation in LShapeOrientation.values) {
    testWidgets(
        '${orientation.label}: intended A/B/C/D stay exact through placement',
        (t) async {
      await board.open(t, showLabels: false);
      await menu(t, 'Measurement unit', DrawingUnit.feet.name);
      await menu(t, 'Shape presets', 'L-shape');
      final choice = find.byKey(ValueKey(orientation));
      await t.ensureVisible(choice);
      await t.tap(choice);
      await t.pumpAndSettle();
      for (final entry in entered.entries) {
        await edit(t, entry.key, entry.value);
      }
      verify(t, typed: true);
      expect(diagram(t).spec.orientation, orientation);
      await t.tap(find.text('Preview'));
      await t.pumpAndSettle();
      expect(board.painter(t).model.walls, isEmpty);
      await t.ensureVisible(find.text('Dimensions / rotation'));
      await t.tap(find.text('Dimensions / rotation'));
      await t.pumpAndSettle();
      verify(t);
      expect(diagram(t).spec.orientation, orientation);
      await t.tap(find.text('Preview'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Place shape'));
      await t.tap(find.text('Place shape'));
      await t.pumpAndSettle();
      final model = board.painter(t).model;
      expect(model.walls.length, 6);
      expect(model.corners.length, 6);
      final minX = model.corners.values.map((p) => p.x).reduce(math.min);
      final minY = model.corners.values.map((p) => p.y).reduce(math.min);
      final maxX = model.corners.values.map((p) => p.x).reduce(math.max);
      final maxY = model.corners.values.map((p) => p.y).reduce(math.max);
      expect(maxX - minX, closeTo(20.58 * 304.8, 1e-7));
      expect(maxY - minY, closeTo(21.39 * 304.8, 1e-7));
      // Independent vertices detect swapped arms even if lengths happen to match.
      for (final point in [
        (0.0, 0.0),
        (20.58, 0.0),
        (20.58, 10.70),
        (9.88, 10.70),
        (9.88, 21.39),
        (0.0, 21.39),
      ]) {
        final expected = DrawingPoint(
            minX + (orientation.flipX ? 20.58 - point.$1 : point.$1) * 304.8,
            minY + (orientation.flipY ? 21.39 - point.$2 : point.$2) * 304.8);
        expect(model.corners.values.any((p) => (p - expected).length < 1e-7),
            isTrue);
      }
      final lengths = model.walls.keys.map(model.length).toList()..sort();
      final expectedLengths = [
        20.58,
        21.39,
        9.88,
        10.70,
        20.58 - 9.88,
        21.39 - 10.70
      ].map((f) => f * 304.8).toList()
        ..sort();
      for (var i = 0; i < lengths.length; i++) {
        expect(lengths[i], closeTo(expectedLengths[i], 1e-7));
      }
      expect(t.takeException(), isNull);
    });
  }
}
