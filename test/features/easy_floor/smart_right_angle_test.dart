import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_precision.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_angles.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'drawing_screen_test.dart' as board;
import 'endpoint_connection_test.dart' show wall;

void main() {
  test('Default assistance follows a connected diagonal, not unrelated walls',
      () {
    const anchor = DrawingPoint(1000, 1000);
    final m = WallNetwork()..addPolyline([const DrawingPoint(0, 0), anchor]);
    const raw = DrawingPoint(5, 2010);
    final snapped = precisionPoint(m, raw, anchor: anchor, axes: true);
    expect(directionDegrees(anchor, snapped), closeTo(135, 1e-8));
    expect(precisionPoint(m, raw, anchor: anchor), same(raw));
    const distant = DrawingPoint(4000, 4000);
    final free = distant + (raw - anchor);
    expect(precisionPoint(m, free, anchor: distant, axes: true), same(free));
    const midpoint = DrawingPoint(500, 500);
    expect(
        directionDegrees(midpoint,
            precisionPoint(m, raw - midpoint, anchor: midpoint, axes: true)),
        closeTo(135, 1e-8));
    final continuous = precisionPoint(WallNetwork(), raw,
        anchor: anchor, previous: const DrawingPoint(0, 0), axes: true);
    expect(directionDegrees(anchor, continuous), closeTo(135, 1e-8));
    const continuation = DrawingPoint(2005, 1995);
    expect(
        directionDegrees(anchor,
            precisionPoint(m, continuation, anchor: anchor, axes: true)),
        closeTo(45, 1e-8));
  });

  testWidgets(
      'Connected diagonal previews an exact right angle and cancels safely',
      (t) async {
    await board.open(t, showLabels: false);
    await board.tool(t, 'Wall');
    await board.collapseTools(t);
    await wall(t, const Offset(60, 100), const Offset(150, 190));
    final before = board.painter(t).model.toJson();
    final origin = t.getTopLeft(board.canvas);
    final drag = await t.startGesture(origin + const Offset(150, 190));
    await drag.moveTo(origin + const Offset(70, 273));
    await t.pump();
    final view = board.painter(t);
    expect(directionDegrees(view.preview.first, view.preview.last),
        closeTo(135, 1e-8));
    expect(contextualAngles(view.model, preview: view.preview).single.degrees,
        closeTo(90, 1e-8));
    expect(view.guides, isNotEmpty);
    final second =
        await t.startGesture(origin + const Offset(250, 350), pointer: 2);
    await t.pump();
    await drag.moveBy(const Offset(15, 20));
    await second.moveBy(const Offset(15, 20));
    await t.pump();
    await second.up();
    await drag.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), before);
    expect(board.painter(t).preview, isEmpty);
    expect(t.takeException(), isNull);
  });

  for (final reverse in [false, true]) {
    testWidgets('Separate Wall strokes form an open C, reverse=$reverse',
        (t) async {
      await board.open(t, showLabels: false);
      await board.tool(t, 'Wall');
      await board.collapseTools(t);
      var points = const [
        Offset(240, 100),
        Offset(70, 100),
        Offset(70, 280),
        Offset(240, 280),
        Offset(240, 220)
      ];
      if (reverse) points = points.reversed.toList();
      for (var i = 1; i < points.length; i++) {
        await wall(t, points[i - 1], points[i]);
        expect(board.painter(t).model.walls.length, i);
      }
      final m = board.painter(t).model;
      expect(m.corners.length, 5);
      expect(m.enclosedComponentAt(const DrawingPoint(1000, 1800)), isEmpty);
      final before = m.toJson();
      await board.expandTools(t);
      await t.tap(find.byTooltip('Undo'));
      await t.pumpAndSettle();
      expect(board.painter(t).model.walls.length, 3);
      await t.tap(find.byTooltip('Redo'));
      await t.pumpAndSettle();
      expect(board.painter(t).model.toJson(), before);
      await board.collapseTools(t);
      await wall(t, points.last, points.first);
      expect(board.painter(t).model.walls.length, 5);
      expect(board.painter(t).model.corners.length, 5);
      expect(t.takeException(), isNull);
    });
  }

  for (final points in [
    const [Offset(60, 100), Offset(240, 100), Offset(240, 260)],
    const [Offset(240, 260), Offset(240, 100), Offset(60, 100)],
    const [
      Offset(60, 100),
      Offset(60, 260),
      Offset(240, 260),
      Offset(240, 100)
    ],
    const [Offset(60, 100), Offset(140, 100), Offset(240, 100)],
    const [Offset(60, 100), Offset(140, 150), Offset(240, 110)],
  ]) {
    testWidgets('Sequential open walls preserve $points', (t) async {
      await board.open(t, showLabels: false);
      await board.tool(t, 'Wall');
      await board.collapseTools(t);
      for (var i = 1; i < points.length; i++) {
        await wall(t, points[i - 1], points[i]);
      }
      final m = board.painter(t).model;
      expect(m.walls.length, points.length - 1);
      expect(m.corners.length, points.length);
      expect(
          m.corners.values
              .where((p) =>
                  m.walls.values
                      .where((w) =>
                          identical(m.corners[w.start], p) ||
                          identical(m.corners[w.end], p))
                      .length ==
                  1)
              .length,
          2);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
      'Separate walls close a rectangle; selected endpoint stays editable',
      (t) async {
    await board.open(t, showLabels: false);
    await board.tool(t, 'Wall');
    await board.collapseTools(t);
    const points = [
      Offset(60, 100),
      Offset(240, 100),
      Offset(240, 280),
      Offset(60, 280),
      Offset(60, 100)
    ];
    for (var i = 1; i < points.length; i++) {
      await wall(t, points[i - 1], points[i]);
    }
    final m = board.painter(t).model;
    expect(m.walls.length, 4);
    expect(m.corners.length, 4);
    final origin = t.getTopLeft(board.canvas);
    await t.tapAt(origin + points[1]);
    await t.pumpAndSettle();
    await wall(t, points[1], points[1] + const Offset(20, -20));
    expect(board.painter(t).model.walls.length, 4);
    expect(t.takeException(), isNull);
  });
}
