import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/dimension_dialog.dart';
import 'drawing_screen_test.dart' as board;
import 'wall_resize_interaction_test.dart' as editing;

void main() {
  for (final degrees in [0, 37, 90]) {
    test('Exact room width preserves rectangle at $degrees degrees', () {
      final m = WallNetwork();
      final points = [
        const DrawingPoint(0, 0),
        const DrawingPoint(3657.6, 0),
        const DrawingPoint(3657.6, 3048),
        const DrawingPoint(0, 3048),
        const DrawingPoint(0, 0),
      ]
          .map((p) => DrawingPoint(
              p.x * math.cos(degrees * math.pi / 180) -
                  p.y * math.sin(degrees * math.pi / 180),
              p.x * math.sin(degrees * math.pi / 180) +
                  p.y * math.cos(degrees * math.pi / 180)))
          .toList();
      m.addPolyline(points);
      final id = m.walls.keys.first, nodes = m.rectangle(id)!;
      final fixedA = m.corners[nodes[0]], fixedD = m.corners[nodes[3]];
      for (final width in [3352.8, 3962.4, 3352.8]) {
        m.setRoomWallLength(id, width);
        expect(m.length(id), closeTo(width, .001));
        expect(m.rectangle(id), isNotNull);
        expect(m.corners[nodes[0]], fixedA);
        expect((m.corners[nodes[3]]! - fixedD!).length, lessThan(.001));
        expect((m.corners[nodes[2]]! - m.corners[nodes[1]]!).length,
            closeTo(3048, .001));
        expect(m.isFixed(id), isFalse);
        expect(() => WallNetwork.fromJson(m.toJson()), returnsNormally);
      }
    });
  }

  test(
      'Room resize rejects locked conflicts atomically and keeps unrelated room',
      () {
    final m = WallNetwork()
      ..addPolyline([
        const DrawingPoint(0, 0),
        const DrawingPoint(3600, 0),
        const DrawingPoint(3600, 3000),
        const DrawingPoint(0, 3000),
        const DrawingPoint(0, 0),
      ])
      ..addPolyline([const DrawingPoint(7000, 0), const DrawingPoint(8000, 0)]);
    final id = m.walls.keys.first, nodes = m.rectangle(id)!;
    final opposite = m.walls.values
        .firstWhere((w) => {w.start, w.end}.containsAll([nodes[2], nodes[3]]))
        .id;
    m.setLength(opposite, m.length(opposite), lock: true);
    final before = m.toJson();
    expect(
        () => m.setRoomWallLength(id, 3352.8), throwsA(isA<DrawingConflict>()));
    expect(m.toJson(), before);
    m.unlock(opposite);
    final unrelated = m.walls.values.last;
    final a = m.corners[unrelated.start], b = m.corners[unrelated.end];
    m.setRoomWallLength(id, 3352.8);
    expect(m.corners[unrelated.start], a);
    expect(m.corners[unrelated.end], b);
  });

  test('Irregular exact edit changes only its endpoint and connected walls',
      () {
    final m = WallNetwork()
      ..addPolyline([
        const DrawingPoint(0, 0),
        const DrawingPoint(3000, 0),
        const DrawingPoint(3000, 1000),
        const DrawingPoint(1000, 1000),
        const DrawingPoint(1000, 3000),
        const DrawingPoint(0, 3000),
        const DrawingPoint(0, 0),
      ]);
    final id = m.walls.keys.first, wall = m.walls[id]!;
    final corners = Map.of(m.corners);
    m.setRoomWallLength(id, 3200);
    expect(m.rectangle(id), isNull);
    expect(m.length(id), closeTo(3200, .001));
    for (final entry in corners.entries) {
      if (entry.key != wall.end) expect(m.corners[entry.key], entry.value);
    }
    expect(m.walls.length, 6);
    expect(() => WallNetwork.fromJson(m.toJson()), returnsNormally);
  });

  test('Shared wall drag preserves both rectangular rooms and outer sides', () {
    final m = WallNetwork()
      ..addPolyline([
        const DrawingPoint(0, 0),
        const DrawingPoint(3000, 0),
        const DrawingPoint(6000, 0),
        const DrawingPoint(6000, 3000),
        const DrawingPoint(3000, 3000),
        const DrawingPoint(0, 3000),
        const DrawingPoint(0, 0),
      ])
      ..addPolyline(
          [const DrawingPoint(3000, 0), const DrawingPoint(3000, 3000)]);
    final wall = m.walls.values.last;
    final corners = Map.of(m.corners);
    m.moveWall(wall.id, const DrawingPoint(-304.8, 0));
    expect(m.length(wall.id), closeTo(3000, .001));
    expect(m.walls.length, 7);
    for (final entry in corners.entries) {
      if (entry.key != wall.start && entry.key != wall.end) {
        expect(m.corners[entry.key], entry.value);
      }
    }
    for (final edge in m.walls.values) {
      expect(m.rectangle(edge.id), isNotNull);
    }
    expect(() => WallNetwork.fromJson(m.toJson()), returnsNormally);
  });

  testWidgets(
      'Simple exact entry preserves room with no modes or automatic lock; Undo restores',
      (t) async {
    final id = await editing.selectFirst(t);
    final before = board.painter(t).model.toJson();
    expect(find.text('Lock length'), findsOneWidget);
    expect(find.text('Drag length'), findsNothing);
    await board.collapseTools(t);
    final view = board.painter(t);
    await t.tapAt(t.getTopLeft(board.canvas) + view.labelBounds![id]!.center);
    await t.pumpAndSettle();
    expect(find.text('Keep this length fixed'), findsNothing);
    expect(find.text('How would you like to resize this wall?'), findsNothing);
    await t.enterText(
        find
            .descendant(
                of: find.byType(DimensionDialog),
                matching: find.byType(TextFormField))
            .first,
        '2.4');
    await t.tap(find.text('Apply'));
    await t.pumpAndSettle();
    final m = board.painter(t).model;
    expect(m.length(id), closeTo(2400, .001));
    expect(m.rectangle(id), isNotNull);
    expect(m.isFixed(id), isFalse);
    await board.expandTools(t);
    await t.ensureVisible(find.byTooltip('Undo'));
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), before);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Wall drag keeps opposite side fixed and shows changed room dimensions',
      (t) async {
    final id = await editing.selectFirst(t);
    await board.collapseTools(t);
    final v = board.painter(t), m = v.model, nodes = m.rectangle(id)!;
    final before = m.toJson();
    final a = m.corners[nodes[0]]!, b = m.corners[nodes[1]]!;
    final at = t.getTopLeft(board.canvas) + v.screen((a + b) * .5);
    final drag = await t.startGesture(at);
    await drag.moveTo(at + const Offset(0, -30));
    await t.pump();
    final live = board.painter(t);
    expect(live.model.rectangle(id), isNotNull);
    expect(live.model.corners[nodes[2]], m.corners[nodes[2]]);
    expect(live.model.corners[nodes[3]], m.corners[nodes[3]]);
    expect(live.model.length(id), closeTo(m.length(id), .001));
    expect(live.measuredWalls.length, 3);
    await drag.up();
    await t.pumpAndSettle();
    await board.expandTools(t);
    await t.ensureVisible(find.byTooltip('Undo'));
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), before);
    expect(t.takeException(), isNull);
  });
}
