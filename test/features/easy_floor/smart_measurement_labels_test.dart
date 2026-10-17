import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/measurement_groups.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/drawing_painter.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/dimension_dialog.dart';
import 'drawing_screen_test.dart' as board;

DrawingPoint p(double x, double y) => DrawingPoint(x, y);
WallNetwork room({double height = 1000, double angle = 0}) {
  DrawingPoint rotate(DrawingPoint v) => p(
      v.x * math.cos(angle) - v.y * math.sin(angle),
      v.x * math.sin(angle) + v.y * math.cos(angle));
  return WallNetwork()
    ..addPolyline([
      for (final v in [
        p(0, 0),
        p(2000, 0),
        p(2000, height),
        p(0, height),
        p(0, 0)
      ])
        rotate(v)
    ]);
}

Map<int, Rect> labels(WallNetwork m,
    {double scale = .1,
    Offset origin = const Offset(180, 160),
    int? selected,
    int? corner,
    Set<int> context = const {},
    bool editing = false}) {
  final bounds = <int, Rect>{};
  final recorder = ui.PictureRecorder();
  DrawingPainter(
          model: m,
          origin: origin,
          scale: scale,
          unit: DrawingUnit.metres,
          preview: [],
          selectedWall: selected,
          selectedCorner: corner,
          contextWalls: context,
          editingActive: editing,
          showAllMeasurements: true,
          anglesEnabled: false,
          labelBounds: bounds)
      .paint(Canvas(recorder), const Size(800, 600));
  recorder.endRecording().dispose();
  return bounds;
}

void main() {
  for (final angle in [0.0, math.pi / 4, math.pi / 2]) {
    for (final scale in [.04, .1, .2]) {
      test('Rectangle and square overview at angle $angle and zoom $scale', () {
        final rectangle = room(angle: angle), before = rectangle.toJson();
        expect(
            redundantMeasurementGroups(rectangle).map((g) => g.length), [2, 2]);
        final visible = labels(rectangle, scale: scale);
        expect(visible.length, 2);
        expect(visible.keys.map(rectangle.length).toSet(), {1000.0, 2000.0});
        expect(rectangle.toJson(), before);
        final square = room(height: 2000, angle: angle);
        expect(redundantMeasurementGroups(square).single.length, 4);
        expect(labels(square, scale: scale).length, 1);
      });
    }
  }

  test('Equal numbers in unrelated or irregular segments are not hidden', () {
    final m = WallNetwork()..addPolyline([p(0, 0), p(2000, 0)]);
    m.addPolyline([p(0, 1000), p(2000, 1000)]);
    expect(redundantMeasurementGroups(m), isEmpty);
    expect(labels(m).length, 2);
    final separateRooms = room()
      ..addPolyline(
          [p(3000, 0), p(5000, 0), p(5000, 1000), p(3000, 1000), p(3000, 0)]);
    expect(redundantMeasurementGroups(separateRooms).length, 4);
    expect(labels(separateRooms).length, 4);
    final irregular = WallNetwork()
      ..addPolyline([
        p(0, 0),
        p(2000, 0),
        p(2000, 1000),
        p(1000, 1000),
        p(1000, 2000),
        p(0, 2000),
        p(0, 0)
      ]);
    expect(redundantMeasurementGroups(irregular), isEmpty);
    expect(labels(irregular).length, 6);
    final almostSquare = room(height: 2000.02);
    expect(redundantMeasurementGroups(almostSquare).length, 2);
    expect(labels(almostSquare).length, 2);
  });

  test(
      'Partitions, shared rooms, T-junctions and lock information remain explicit',
      () {
    final partitioned = room()..addPolyline([p(1000, 0), p(1000, 1000)]);
    expect(redundantMeasurementGroups(partitioned), isEmpty);
    expect(labels(partitioned).length, partitioned.walls.length);
    final shared = room()
      ..addPolyline([p(2000, 0), p(3000, 0), p(3000, 1000), p(2000, 1000)]);
    expect(redundantMeasurementGroups(shared), isEmpty);
    expect(labels(shared).length, shared.walls.length);
    final locked = room();
    locked.setLength(locked.walls.keys.first, 2000, lock: true);
    expect(redundantMeasurementGroups(locked), isEmpty);
    expect(labels(locked).length, 4);
  });

  test('Active walls and affected corner walls always restore their own labels',
      () {
    final m = room(height: 2000);
    for (final w in m.walls.values) {
      expect(labels(m, selected: w.id), contains(w.id));
      expect(labels(m, selected: w.id, context: {w.id}, editing: true).keys,
          [w.id]);
    }
    final corner = m.corners.keys.first;
    final affected = m.walls.values
        .where((w) => w.start == corner || w.end == corner)
        .map((w) => w.id)
        .toSet();
    expect(labels(m, corner: corner, editing: true).keys.toSet(), affected);
    final w = m.walls.values.first;
    m.moveWall(w.id, p(100, -200));
    expect(redundantMeasurementGroups(m), isEmpty);
    expect(labels(m).length, 4);
  });

  test('Panning keeps an on-screen representative of each rectangle dimension',
      () {
    final m = room();
    final bounds = labels(m, scale: .4, origin: const Offset(-100, 100));
    expect(bounds.length, 2);
    expect(bounds.keys.map(m.length).toSet(), {1000.0, 2000.0});
  });

  testWidgets(
      'A hidden opposite wall can be selected and its exact dimension edited',
      (t) async {
    await board.open(t);
    await board.outline(t);
    await board.collapseTools(t);
    final v = board.painter(t);
    expect(v.labelBounds!.length, 2);
    final hidden = v.model.walls.values
        .firstWhere((w) => !v.labelBounds!.containsKey(w.id));
    final midpoint =
        (v.model.corners[hidden.start]! + v.model.corners[hidden.end]!) * .5;
    await t.tapAt(t.getTopLeft(board.canvas) + v.screen(midpoint));
    await t.pumpAndSettle();
    final selected = board.painter(t);
    expect(selected.selectedWall, hidden.id);
    expect(selected.labelBounds, contains(hidden.id));
    await t.tapAt(
        t.getTopLeft(board.canvas) + selected.labelBounds![hidden.id]!.center);
    await t.pumpAndSettle();
    expect(t.widget<DimensionDialog>(find.byType(DimensionDialog)).valueMm,
        v.model.length(hidden.id));
    await t.enterText(find.byType(TextFormField), '2.5');
    await t.tap(find.text('Apply'));
    await t.pumpAndSettle();
    expect(board.painter(t).model.length(hidden.id), 2500);
  });
}
