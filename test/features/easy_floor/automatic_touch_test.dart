import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'drawing_screen_test.dart' as board;

void main() {
  for (final scale in [.02, .1, 1.0]) {
    test('Wall center beats an unrelated nearby endpoint at zoom $scale', () {
      final m = WallNetwork()
        ..addPolyline([const DrawingPoint(0, 0), DrawingPoint(300 / scale, 0)])
        ..addPolyline([
          DrawingPoint(150 / scale, 10 / scale),
          DrawingPoint(150 / scale, 60 / scale)
        ]);
      final target = m.hitTest(DrawingPoint(150 / scale, 0),
          cornerRadius: 22 / scale,
          wallRadius: 16 / scale,
          endpointRadius: 6 / scale);
      expect(target.corner, isNull);
      expect(target.wall, m.walls.keys.first);
      final endpoint = m.hitTest(DrawingPoint(150 / scale, 10 / scale),
          cornerRadius: 22 / scale,
          wallRadius: 16 / scale,
          endpointRadius: 6 / scale);
      expect(endpoint.corner, m.walls.values.last.start);
    });
  }

  test('Competing walls and corners resolve by distance then stable ID', () {
    final m = WallNetwork()
      ..addPolyline([const DrawingPoint(0, 0), const DrawingPoint(0, 1000)])
      ..addPolyline(
          [const DrawingPoint(200, 0), const DrawingPoint(200, 1000)]);
    final wall = m.nearestWall(const DrawingPoint(100, 500), 160);
    final corner = m.nearestCorner(const DrawingPoint(100, 0), 220);
    final walls = m.walls.entries.toList().reversed.toList();
    final corners = m.corners.entries.toList().reversed.toList();
    m.walls
      ..clear()
      ..addEntries(walls);
    m.corners
      ..clear()
      ..addEntries(corners);
    expect(m.nearestWall(const DrawingPoint(100, 500), 160), wall);
    expect(m.nearestCorner(const DrawingPoint(100, 0), 220), corner);
  });

  for (final stroke in ['Wall', 'Draw']) {
    testWidgets(
        '$stroke keeps automatic wall and corner editing without switching modes',
        (t) async {
      await board.open(t);
      await board.outline(t);
      await t.ensureVisible(find.widgetWithText(ChoiceChip, stroke));
      await t.tap(find.widgetWithText(ChoiceChip, stroke));
      await t.pumpAndSettle();
      await board.collapseTools(t);
      var v = board.painter(t);
      final wall = v.model.walls.values.first;
      final before = v.model.toJson();
      final a = v.model.corners[wall.start]!, b = v.model.corners[wall.end]!;
      final at = t.getTopLeft(board.canvas) + v.screen((a + b) * .5);
      var drag = await t.startGesture(at);
      await t.pump(const Duration(milliseconds: 50));
      expect(board.painter(t).selectedWall, wall.id);
      expect(board.painter(t).model.toJson(), before);
      await drag.moveTo(at + const Offset(0, 30));
      await t.pump();
      expect(board.painter(t).selectedWall, wall.id);
      expect(board.painter(t).measuredWalls, contains(wall.id));
      await drag.up();
      await t.pumpAndSettle();
      v = board.painter(t);
      expect(v.model.walls.length, 4);
      expect(v.model.corners[wall.start]!.y, closeTo(a.y + 300, .001));
      expect(v.model.corners[wall.end]!.y, closeTo(b.y + 300, .001));
      final cornerAt =
          t.getTopLeft(board.canvas) + v.screen(v.model.corners[wall.start]!);
      drag = await t.startGesture(cornerAt);
      await t.pump();
      expect(board.painter(t).selectedCorner, wall.start);
      await drag.moveTo(cornerAt + const Offset(25, 25));
      await t.pump();
      expect(board.painter(t).selectedCorner, wall.start);
      await drag.cancel();
      await t.pumpAndSettle();
      expect(board.painter(t).model.toJson(), v.model.toJson());
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
      'Slow movement cancels the hold-to-connect action before the drag threshold',
      (t) async {
    await board.open(t);
    await board.outline(t);
    await board.collapseTools(t);
    final v = board.painter(t), wall = v.model.walls.values.first;
    final at = t.getTopLeft(board.canvas) +
        v.screen(
            (v.model.corners[wall.start]! + v.model.corners[wall.end]!) * .5);
    final drag = await t.startGesture(at);
    await drag.moveTo(at + const Offset(0, 8));
    await t.pump(const Duration(milliseconds: 500));
    await drag.moveTo(at + const Offset(0, 35));
    await t.pump();
    expect(board.painter(t).preview, isEmpty);
    expect(board.painter(t).selectedWall, wall.id);
    await drag.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.walls.length, 4);
    expect(board.painter(t).model.toJson(), isNot(v.model.toJson()));
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Drawing from empty space stays drawing when crossing a wall touch zone',
      (t) async {
    await board.open(t);
    await board.outline(t);
    await board.collapseTools(t);
    final before = board.painter(t).model.toJson();
    final origin = t.getTopLeft(board.canvas);
    final drag = await t.startGesture(origin + const Offset(160, 300));
    await drag.moveTo(origin + const Offset(160, 230));
    await t.pump();
    expect(board.painter(t).preview.length, greaterThan(1));
    expect(board.painter(t).selectedWall, isNull);
    expect(board.painter(t).model.toJson(), before);
    await drag.cancel();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), before);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Cancel action restores an automatic edit without a history entry',
      (t) async {
    await board.open(t);
    await board.outline(t);
    final v = board.painter(t), wall = v.model.walls.values.first;
    final before = v.model.toJson();
    final at = t.getTopLeft(board.canvas) +
        v.screen(
            (v.model.corners[wall.start]! + v.model.corners[wall.end]!) * .5);
    final drag = await t.startGesture(at);
    await drag.moveTo(at + const Offset(0, 30));
    await t.pump();
    expect(board.painter(t).model.toJson(), isNot(before));
    final cancel =
        t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Cancel'));
    cancel.onSelected!(true);
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), before);
    await board.expandTools(t);
    await t.ensureVisible(find.byTooltip('Undo'));
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(board.painter(t).model.walls, isEmpty);
    expect(t.takeException(), isNull);
  });
}
