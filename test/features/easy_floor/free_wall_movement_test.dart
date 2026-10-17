import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_history.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'drawing_screen_test.dart' as board;
import 'endpoint_connection_test.dart' show wall;
import 'annotation_interaction_test.dart' show undo;

DrawingPoint p(double x, double y) => DrawingPoint(x, y);
void point(DrawingPoint actual, DrawingPoint expected) =>
    expect((actual - expected).length, closeTo(0, .00001));

void main() {
  for (final scale in [.02, .1, 1.0]) {
    test('Rigid wall translation and hit testing through 360 degrees at $scale',
        () {
      for (final orientation in [0, 45, 90, 137]) {
        for (final length in [24.0, 200.0, 2000.0]) {
          final angle = orientation * math.pi / 180;
          final direction = p(math.cos(angle), math.sin(angle));
          final original = WallNetwork()
            ..addPolyline([p(0, 0), direction * (length / scale)]);
          final w = original.walls.values.single;
          for (var degrees = 0; degrees < 360; degrees += 15) {
            final radians = degrees * math.pi / 180;
            final delta =
                p(math.cos(radians), math.sin(radians)) * (30 / scale);
            final m = original.copy()..moveWall(w.id, delta);
            point(m.corners[w.start]!, delta);
            point(m.corners[w.end]! - m.corners[w.start]!,
                direction * (length / scale));
            for (final fraction in [.3, .5, .7]) {
              final hit = m.hitTest(
                  delta + direction * (length * fraction / scale),
                  cornerRadius: 22 / scale,
                  wallRadius: 16 / scale,
                  endpointRadius: 6 / scale);
              expect(hit.wall, w.id);
            }
          }
        }
      }
    });

    for (final midpoint in [false, true]) {
      test(
          'Rigid snap to ${midpoint ? 'wall interior' : 'endpoint'} at $scale, join, move away, undo/redo',
          () {
        final m = WallNetwork()..addPolyline([p(0, 0), p(200 / scale, 0)]);
        m.addPolyline(
            [p(300 / scale, 300 / scale), p(350 / scale, 400 / scale)]);
        final w = m.walls.values.last;
        final before = m.toJson();
        final history = DrawingHistory()..commit(m);
        final target = p((midpoint ? 100 : 200) / scale, 0);
        final direction = m.corners[w.end]! - m.corners[w.start]!;
        final delta = target - m.corners[w.start]! + p(3 / scale, 4 / scale);
        final snapped = m.snapWallTranslation(w.id, delta, 10 / scale);
        final connection = midpoint ? target + p(3 / scale, 0) : target;
        point(snapped.connection!, connection);
        m.moveWall(w.id, snapped.delta, join: true);
        final moved = m.walls[w.id]!;
        point(m.corners[moved.end]! - m.corners[moved.start]!, direction);
        final junction = m.nearestCorner(connection, .001)!;
        expect(
            m.walls.values
                .where((edge) => edge.start == junction || edge.end == junction)
                .length,
            midpoint ? 3 : 2);
        history.commit(m);
        final joined = m.toJson();
        expect(history.undo().toJson(), before);
        expect(history.redo().toJson(), joined);
        m.moveWall(w.id, p(30 / scale, 20 / scale), join: true);
        point(m.corners[m.walls[w.id]!.end]! - m.corners[m.walls[w.id]!.start]!,
            direction);
        expect(
            m.walls.values
                .where((edge) => edge.start == junction || edge.end == junction)
                .length,
            midpoint ? 3 : 2);
      });
    }
  }

  test('Out-of-range targets and the wall itself cannot attract a translation',
      () {
    final m = WallNetwork()..addPolyline([p(0, 0), p(1000, 0)]);
    final id = m.walls.keys.single;
    final delta = p(20, 30);
    final snap = m.snapWallTranslation(id, delta, 100);
    point(snap.delta, delta);
    expect(snap.connection, isNull);
    m.addPolyline([p(4000, 4000), p(5000, 4000)]);
    expect(m.snapWallTranslation(id, delta, 100).connection, isNull);
  });

  testWidgets(
      'Wall body follows finger in every direction; cancel and undo are exact',
      (t) async {
    await board.open(t, showLabels: false);
    await board.tool(t, 'Wall');
    await board.collapseTools(t);
    await wall(t, const Offset(60, 100), const Offset(140, 100));
    await wall(t, const Offset(200, 250), const Offset(280, 250));
    final v = board.painter(t), w = v.model.walls.values.last;
    final a = v.model.corners[w.start]!, b = v.model.corners[w.end]!;
    final before = v.model.toJson();
    for (final fraction in [.1, .5, .9]) {
      for (var degrees = 0; degrees < 360; degrees += 45) {
        final radians = degrees * math.pi / 180;
        final delta = Offset(math.cos(radians) * 30, math.sin(radians) * 30);
        final at =
            t.getTopLeft(board.canvas) + v.screen(a + (b - a) * fraction);
        final drag = await t.startGesture(at);
        await drag.moveTo(at + delta);
        await t.pump();
        final live = board.painter(t);
        expect(live.selectedWall, w.id);
        point(live.model.corners[w.start]!,
            a + p(delta.dx / v.scale, delta.dy / v.scale));
        point(live.model.corners[w.end]! - live.model.corners[w.start]!, b - a);
        expect(live.measuredWalls, contains(w.id));
        await drag.cancel();
        await t.pumpAndSettle();
        expect(board.painter(t).model.toJson(), before);
      }
    }
    final at = t.getTopLeft(board.canvas) + v.screen((a + b) * .5);
    final drag = await t.startGesture(at);
    await drag.moveTo(at + const Offset(-25, 20));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    final after = board.painter(t).model.toJson();
    await undo(t, 'Undo');
    expect(board.painter(t).model.toJson(), before);
    await undo(t, 'Redo');
    expect(board.painter(t).model.toJson(), after);
  });

  for (final factor in [.5, 2.0]) {
    testWidgets('Full-direction drag after pinch zoom by $factor', (t) async {
      await board.open(t, showLabels: false);
      await board.tool(t, 'Wall');
      await board.collapseTools(t);
      await wall(t, const Offset(200, 250), const Offset(280, 250));
      final before = board.painter(t), w = before.model.walls.values.single;
      final a = before.model.corners[w.start]!,
          b = before.model.corners[w.end]!;
      final origin = t.getTopLeft(board.canvas);
      final first =
          await t.startGesture(origin + const Offset(220, 250), pointer: 1);
      final second =
          await t.startGesture(origin + const Offset(260, 250), pointer: 2);
      await first.moveTo(origin + Offset(240 - 20 * factor, 250));
      await second.moveTo(origin + Offset(240 + 20 * factor, 250));
      await t.pump();
      await second.up();
      await first.up();
      await t.pumpAndSettle();
      final zoomed = board.painter(t);
      expect(zoomed.scale, closeTo(before.scale * factor, .00001));
      expect(zoomed.model.toJson(), before.model.toJson());
      final at = origin + zoomed.screen((a + b) * .5);
      final drag = await t.startGesture(at);
      await drag.moveTo(at + const Offset(-20, 25));
      await t.pump();
      point(board.painter(t).model.corners[w.start]!,
          a + p(-20 / zoomed.scale, 25 / zoomed.scale));
      await drag.up();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
      'A rejected overlap snap does not block a valid nearby parallel move',
      (t) async {
    await board.open(t, showLabels: false);
    await board.tool(t, 'Wall');
    await board.collapseTools(t);
    await wall(t, const Offset(60, 100), const Offset(140, 100));
    await wall(t, const Offset(60, 250), const Offset(140, 250));
    final v = board.painter(t), w = v.model.walls.values.last;
    final origin = t.getTopLeft(board.canvas);
    final drag = await t.startGesture(origin + const Offset(100, 250));
    await drag.moveTo(origin + const Offset(100, 108));
    await t.pump();
    final live = board.painter(t);
    point(live.model.corners[w.start]!,
        v.model.corners[w.start]! + p(0, -142 / v.scale));
    expect(live.connection, isNull);
    await drag.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.walls.length, 2);
    expect(t.takeException(), isNull);
  });

  for (final midpoint in [false, true]) {
    testWidgets(
        'Translate second wall into ${midpoint ? 'T-junction' : 'shared endpoint'} with live snap feedback',
        (t) async {
      await board.open(t, showLabels: false);
      await board.tool(t, 'Wall');
      await board.collapseTools(t);
      await wall(t, const Offset(60, 100), const Offset(140, 100));
      await wall(t, const Offset(220, 200), const Offset(220, 280));
      final v = board.painter(t), w = v.model.walls.values.last;
      final direction = v.model.corners[w.end]! - v.model.corners[w.start]!;
      final origin = t.getTopLeft(board.canvas);
      final drag = await t.startGesture(origin + const Offset(220, 240));
      await drag.moveTo(origin + Offset(midpoint ? 103 : 143, 143));
      await t.pump();
      expect(board.painter(t).connection, isNotNull);
      await drag.up();
      await t.pumpAndSettle();
      final m = board.painter(t).model, moved = m.walls[w.id]!;
      point(m.corners[moved.end]! - m.corners[moved.start]!, direction);
      final shared = moved.start;
      expect(
          m.walls.values
              .where((edge) => edge.start == shared || edge.end == shared)
              .length,
          midpoint ? 3 : 2);
      expect(t.takeException(), isNull);
    });
  }
}
