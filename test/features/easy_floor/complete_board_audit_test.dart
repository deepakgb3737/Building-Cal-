import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_shapes.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_history.dart';
import 'drawing_screen_test.dart' as harness;
import 'shape_interaction_test.dart' as shapes;
import 'natural_drawing_test.dart' as natural;
import 'advanced_interaction_test.dart' as editing;

DrawingPoint p(double x, double y) => DrawingPoint(x, y);

Future<void> historyAction(WidgetTester t, String tooltip) async {
  final button = find.byTooltip(tooltip);
  await t.ensureVisible(button);
  await t.tap(button);
  await t.pumpAndSettle();
}

String signature(WallNetwork m) =>
    '${m.corners.entries.map((e) => '${e.key}:${e.value.x},${e.value.y}').join(';')}|'
    '${m.walls.values.map((w) => '${w.id}:${w.start},${w.end}').join(';')}|${m.constraintSignature}';

void checkConnections(WallNetwork m) {
  final edges = <(int, int)>{};
  for (final w in m.walls.values) {
    expect(m.length(w.id), greaterThanOrEqualTo(10));
    expect(edges.add(w.start < w.end ? (w.start, w.end) : (w.end, w.start)),
        isTrue);
    for (final corner in m.corners.entries) {
      final projection = projectToSegment(
          corner.value, m.corners[w.start]!, m.corners[w.end]!);
      if ((projection - corner.value).length < .001) {
        expect(corner.key == w.start || corner.key == w.end, isTrue,
            reason:
                'A touching corner must split the wall into shared segments');
      }
    }
  }
}

List<DrawingPoint> rough(ShapePreset kind,
    {bool reverse = false, double rotation = 0}) {
  var points = ShapeSpec(kind, 3000, 2400, 0).points(p(0, 0));
  if (reverse) points = points.reversed.toList();
  final radians = rotation * math.pi / 180;
  return [
    for (var i = 0; i < points.length; i++)
      if (i == points.length - 1)
        p(0, 0)
      else
        p(
            points[i].x * math.cos(radians) -
                points[i].y * math.sin(radians) +
                (i == 0
                    ? 0
                    : i.isEven
                        ? 8
                        : -8),
            points[i].x * math.sin(radians) +
                points[i].y * math.cos(radians) +
                (i == 0
                    ? 0
                    : i.isEven
                        ? -6
                        : 6))
  ];
}

void main() {
  testWidgets(
      'Cancelling clear confirmation cannot commit an unfinished stroke',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    final before = signature(harness.painter(t).model);
    final origin = t.getTopLeft(harness.canvas);
    final drag =
        await t.startGesture(origin + const Offset(280, 300), pointer: 7);
    await drag.moveTo(origin + const Offset(80, 300));
    await t.pump();
    await editing.menu(t, 'Plan actions', 'Clear plan');
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    await drag.up();
    await t.pumpAndSettle();
    expect(signature(harness.painter(t).model), before);
    expect(harness.painter(t).preview, isEmpty);
  });
  testWidgets('Preset placement cannot commit while its resize is unfinished',
      (t) async {
    await harness.open(t);
    await shapes.menu(t, 'Shape presets', 'Rectangle');
    await t.tap(find.text('Preview'));
    await t.pumpAndSettle();
    final origin = t.getTopLeft(harness.canvas);
    final drag = await t.startGesture(origin + const Offset(60, 80));
    await drag.moveTo(origin + const Offset(230, 180));
    await t.pump();
    final place = find.widgetWithText(FilledButton, 'Place shape');
    expect(t.widget<FilledButton>(place).onPressed, isNull);
    await drag.cancel();
    await t.pumpAndSettle();
    expect(t.widget<FilledButton>(place).onPressed, isNotNull);
    expect(harness.painter(t).model.walls, isEmpty);
  });
  test(
      'Eight-corner angled irregularities are not coerced to orthogonal U/T shapes',
      () {
    for (final kind in [ShapePreset.uShape, ShapePreset.tShape]) {
      final input = rough(kind);
      input[3] = input[3] + p(200, 150);
      expect(recognizeShape(input), isNull);
    }
  });
  testWidgets('Group reconnection cannot leave deleted segment IDs selected',
      (t) async {
    await harness.open(t);
    await natural.stroke(t, const [Offset(60, 60), Offset(260, 60)]);
    await natural.stroke(t, const [Offset(160, 200), Offset(160, 320)]);
    await editing.menu(t, 'Plan actions', 'Multi-select');
    final origin = t.getTopLeft(harness.canvas);
    await t.tapAt(origin + const Offset(160, 60));
    await t.pumpAndSettle();
    final drag = await t.startGesture(origin + const Offset(160, 60));
    await drag.moveTo(origin + const Offset(160, 200));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    final view = harness.painter(t);
    expect(view.model.walls.length, 3);
    expect(view.highlightedWalls.every(view.model.walls.containsKey), isTrue);
    expect(view.highlightedWalls, isEmpty);
    expect(find.byTooltip('Delete selected geometry'), findsNothing);
    await historyAction(t, 'Undo');
    expect(harness.painter(t).model.walls.length, 2);
    await historyAction(t, 'Redo');
    expect(harness.painter(t).model.walls.length, 3);
  });
  for (final kind in [ShapePreset.uShape, ShapePreset.tShape]) {
    testWidgets(
        '${kind.label} cleanup, exact edit and complete undo/redo workflow',
        (t) async {
      await harness.open(t);
      await natural.stroke(
          t,
          [
            for (final point in rough(kind))
              Offset(40 + point.x * .07, 80 + point.y * .07)
          ],
          finish: false);
      await editing.action(t, 'Yes, Straighten');
      await editing.action(t, 'Accept refinement');
      final m = harness.painter(t).model.copy();
      expect(m.walls.length, 8);
      checkConnections(m);
      final id = m.walls.keys.first;
      await editing.selectWall(t, id);
      await editing.action(t, 'Enter length');
      await t.enterText(find.byType(TextFormField), '1');
      await t.tap(find.text('Apply'));
      await t.pumpAndSettle();
      expect(harness.painter(t).model.length(id), closeTo(1000, 1e-6));
      checkConnections(harness.painter(t).model);
      await historyAction(t, 'Undo');
      expect(signature(harness.painter(t).model), signature(m));
      await historyAction(t, 'Undo');
      expect(harness.painter(t).model.walls, isEmpty);
      for (var i = 0; i < 2; i++) {
        await historyAction(t, 'Redo');
      }
      expect(harness.painter(t).model.length(id), closeTo(1000, 1e-6));
      checkConnections(harness.painter(t).model);
    });
    test('Rough ${kind.label} retains its notch in both windings and rotations',
        () {
      for (final reverse in [false, true]) {
        for (final rotation in [0.0, 37.0, 90.0]) {
          final input = rough(kind, reverse: reverse, rotation: rotation);
          final suggestion = recognizeShape(input);
          expect(suggestion, isNotNull);
          expect(suggestion!.kind, kind);
          final m = WallNetwork()..addPolyline(suggestion.points);
          expect(m.walls.length, 8);
          expect(m.corners.length, 8);
          for (var i = 0; i < input.length; i++) {
            expect((input[i] - suggestion.points[i]).length, lessThan(80));
          }
          expect(recognizeShape(input.sublist(0, input.length - 1)), isNull);
        }
      }
    });
  }
  test(
      '60 mixed edits preserve dense junctions and independent irregular geometry',
      () {
    final m = WallNetwork(), history = DrawingHistory();
    for (var i = 0; i <= 4; i++) {
      m.addPolyline([p(i * 2000, 0), p(i * 2000, 8000)]);
      m.addPolyline([p(0, i * 2000), p(8000, i * 2000)]);
    }
    m.addPolyline([p(10000, 0), p(13000, 400), p(12500, 2700), p(10000, 2000)]);
    final independent = {
      for (final e in m.corners.entries)
        if (e.value.x >= 10000) e.key: e.value
    };
    final wallCount = m.walls.length, cornerCount = m.corners.length;
    history.commit(m);
    for (var i = 0; i < 60; i++) {
      final before = signature(m);
      if (i % 3 == 0) {
        final id = m.nearestCorner(p(2000, 2000), 100)!;
        final old = m.corners[id]!;
        m.moveCorners({id: old + p(25, -15)}, join: true);
        m.moveCorners({id: old}, join: true);
      } else if (i % 3 == 1) {
        final id = m.nearestWall(p(4000, 1000), 1)!;
        m.moveWall(id, p(20, 0), join: true);
        m.moveWall(id, p(-20, 0), join: true);
      } else {
        final id = m.nearestWall(p(1000, 0), 1)!;
        m.splitWall(id, 1000);
        final corner = m.nearestCorner(p(1000, 0), .001)!;
        m.joinAtCorner(corner);
      }
      checkConnections(m);
      expect(m.walls.length, wallCount);
      expect(m.corners.length, cornerCount);
      for (final e in independent.entries) {
        expect(m.corners[e.key], same(e.value));
      }
      history.commit(m);
      if (signature(m) != before) {
        expect(signature(history.undo()), before);
        expect(signature(history.redo()), signature(m));
      }
    }
  });
  testWidgets('Wall command panel cannot mutate an uncommitted drag',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    final v = harness.painter(t), wall = v.model.walls.values.first;
    final at = t.getTopLeft(harness.canvas) +
        (v.screen(v.model.corners[wall.start]!) +
                v.screen(v.model.corners[wall.end]!)) /
            2;
    await t.tapAt(at);
    await t.pumpAndSettle();
    await t.tap(find.text('More wall options'));
    await t.pumpAndSettle();
    expect(find.text('Lock length'), findsOneWidget);
    final drag = await t.startGesture(at);
    await drag.moveTo(at + const Offset(0, 25));
    await t.pump();
    expect(find.text('Lock length'), findsNothing);
    await drag.cancel();
    await t.pumpAndSettle();
    expect(harness.painter(t).model.isFixed(wall.id), isFalse);
    expect(harness.painter(t).model.corners[wall.start]!.y,
        v.model.corners[wall.start]!.y);
  });
  testWidgets(
      'Lifting one pinch finger cannot turn the remaining finger into drawing',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    final origin = t.getTopLeft(harness.canvas);
    final a = await t.startGesture(origin + const Offset(90, 300), pointer: 1);
    final b = await t.startGesture(origin + const Offset(230, 300), pointer: 2);
    await a.moveTo(origin + const Offset(60, 300));
    await b.moveTo(origin + const Offset(260, 300));
    await t.pump();
    await a.up();
    await b.moveTo(origin + const Offset(270, 360));
    await t.pump();
    await b.up();
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls.length, 4);
    expect(harness.painter(t).preview, isEmpty);
  });
  testWidgets('Preset angle indicators are suppressed during camera navigation',
      (t) async {
    await harness.open(t);
    await shapes.menu(t, 'Shape presets', 'Rectangle');
    await t.tap(find.text('Preview'));
    await t.pumpAndSettle();
    final origin = t.getTopLeft(harness.canvas);
    final a = await t.startGesture(origin + const Offset(80, 250), pointer: 1);
    final b = await t.startGesture(origin + const Offset(240, 250), pointer: 2);
    await a.moveTo(origin + const Offset(60, 250));
    await b.moveTo(origin + const Offset(260, 250));
    await t.pump();
    expect(harness.painter(t).angles, isEmpty);
    await a.up();
    await b.up();
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls, isEmpty);
  });
}
