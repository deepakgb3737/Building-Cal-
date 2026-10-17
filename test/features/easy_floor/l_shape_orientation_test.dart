import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_shapes.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/shape_dialog.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'preset_dialog_test.dart' show edit, diagram, input;
import 'package:grid_ceiling_calculator/features/easy_floor/ui/shape_diagram.dart';

ShapeSpec shape(LShapeOrientation orientation,
        {double c = 3100, double d = 700, double rotation = 0}) =>
    ShapeSpec(ShapePreset.lShape, 5200, 2300, rotation,
        orientation: orientation,
        details: {
          ShapeDimension.verticalArm: c,
          ShapeDimension.horizontalArm: d
        });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final orientation in LShapeOrientation.values) {
    testWidgets(
        '${orientation.label}: reversed overall and arm inputs flag C, not D',
        (t) async {
      t.view.physicalSize = const Size(320, 740);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
              body: ShapeDialog(
                  spec: shape(orientation), unit: DrawingUnit.feet))));
      for (final entry in {
        ShapeDimension.width: '9.88',
        ShapeDimension.height: '21.39',
        ShapeDimension.verticalArm: '20.58',
        ShapeDimension.horizontalArm: '10.7',
      }.entries) {
        await edit(t, entry.key, entry.value);
      }
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('shapeDimensionDiagram')), findsNothing);
      final c = find.descendant(
          of: input(ShapeDimension.verticalArm),
          matching: find.byType(TextField));
      expect(t.widget<TextField>(c).decoration!.errorText,
          contains('overall length (A)'));
      expect(
          t
              .widget<TextFormField>(input(ShapeDimension.horizontalArm))
              .validator!('10.7'),
          isNull);
      await edit(t, ShapeDimension.verticalArm, '8');
      expect(diagram(t).spec.orientation, orientation);
      expect(diagram(t).spec.width, closeTo(9.88 * 304.8, 1e-7));
      expect(diagram(t).spec.height, closeTo(21.39 * 304.8, 1e-7));
      expect(diagram(t).spec.horizontalArm, closeTo(10.7 * 304.8, 1e-7));
      expect(diagram(t).spec.points(const DrawingPoint(0, 0)).length, 7);
      expect(t.takeException(), isNull);
    });

    test('${orientation.label}: geometry, A/B/C/D and resize use one transform',
        () {
      final spec = shape(orientation);
      final points = spec.points(const DrawingPoint(0, 0));
      final base =
          shape(LShapeOrientation.topLeft).points(const DrawingPoint(0, 0));
      for (var i = 0; i < points.length; i++) {
        expect(points[i].x, orientation.flipX ? 5200 - base[i].x : base[i].x);
        expect(points[i].y, orientation.flipY ? 2300 - base[i].y : base[i].y);
      }
      expect(spec.measurements.map((m) => m.value), [5200, 2300, 3100, 700]);
      for (final measurement in spec.measurements) {
        expect(
            points.any((p) => (p - measurement.start).length < 1e-7), isTrue);
        expect(points.any((p) => (p - measurement.end).length < 1e-7), isTrue);
      }
      expect((WallNetwork()..addPolyline(points)).walls.length, 6);
      final resized = spec.resized(10400, 6900);
      expect(resized.orientation, orientation);
      expect(resized.verticalArm, 6200);
      expect(resized.horizontalArm, 2100);
      final rotated = shape(orientation, rotation: 90);
      final edges = rotated.points(const DrawingPoint(0, 0));
      for (var i = 0; i < points.length; i++) {
        expect(edges[i].x, closeTo(-points[i].y, 1e-7));
        expect(edges[i].y, closeTo(points[i].x, 1e-7));
      }
      final bounds = <ShapeDimension, Rect>{};
      final painter = ShapeDiagram(
          rotated, DrawingUnit.mm, ShapeDimension.verticalArm,
          labelBounds: bounds);
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(320, 200));
      recorder.endRecording().dispose();
      expect(bounds.length, 4);
      final twice = rotated.resized(10400, 6900);
      expect(twice.verticalArm, closeTo(6200, 1e-7));
      expect(twice.horizontalArm, closeTo(2100, 1e-7));
    });

    test(
        '${orientation.label}: arms validate against their corresponding overall',
        () {
      expect(shape(orientation).dimensionErrors, isEmpty); // C may exceed B.
      for (final bad in [
        shape(orientation, c: 5200),
        shape(orientation, c: 5195)
      ]) {
        expect(bad.dimensionErrors.keys, [ShapeDimension.verticalArm]);
        expect(() => bad.points(const DrawingPoint(0, 0)),
            throwsA(isA<DrawingConflict>()));
      }
      for (final bad in [
        shape(orientation, d: 2300),
        shape(orientation, d: 2295)
      ]) {
        expect(bad.dimensionErrors.keys, [ShapeDimension.horizontalArm]);
        expect(() => bad.points(const DrawingPoint(0, 0)),
            throwsA(isA<DrawingConflict>()));
      }
      expect(shape(orientation, c: 5190, d: 2290).dimensionErrors, isEmpty);
      expect(
          shape(orientation, c: 10, d: 10, rotation: 37)
              .points(const DrawingPoint(0, 0))
              .length,
          7);
    });

    testWidgets(
        '${orientation.label}: live mapping, field errors and no stale preview',
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
                                spec: shape(LShapeOrientation.topLeft),
                                unit: DrawingUnit.mm));
                      },
                      child: const Text('Open'))))));
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      final choice = find.byKey(ValueKey(orientation));
      await t.ensureVisible(choice);
      await t.tap(choice);
      await t.pumpAndSettle();
      expect(diagram(t).spec.orientation, orientation);
      await edit(t, ShapeDimension.horizontalArm, '2400');
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('shapeDimensionDiagram')), findsNothing);
      final field =
          t.widget<TextFormField>(input(ShapeDimension.horizontalArm));
      expect(field.validator!('2400'), contains('overall width (B)'));
      await edit(t, ShapeDimension.horizontalArm, '800');
      expect(diagram(t).spec.horizontalArm, 800);
      expect(diagram(t).spec.orientation, orientation);
      await edit(t, ShapeDimension.verticalArm, '5300');
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('shapeDimensionDiagram')), findsNothing);
      expect(
          t
              .widget<TextFormField>(input(ShapeDimension.verticalArm))
              .validator!('5300'),
          contains('overall length (A)'));
      await edit(t, ShapeDimension.verticalArm, '3200');
      expect(diagram(t).spec.verticalArm, 3200);
      await edit(t, ShapeDimension.width, '3000');
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('shapeDimensionDiagram')), findsNothing);
      expect(
          t
              .widget<TextFormField>(input(ShapeDimension.verticalArm))
              .validator!('3200'),
          contains('overall length (A)'));
      await edit(t, ShapeDimension.width, '6000');
      expect(diagram(t).spec.width, 6000);
      expect(diagram(t).spec.orientation, orientation);
      await t.tap(find.text('Preview'));
      await t.pumpAndSettle();
      expect(result!.orientation, orientation);
      expect(result!.verticalArm, 3200);
      expect(result!.horizontalArm, 800);
      expect(t.takeException(), isNull);
    });
  }
}
