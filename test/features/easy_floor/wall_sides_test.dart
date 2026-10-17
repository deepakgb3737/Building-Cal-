import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'drawing_screen_test.dart' as board;

void main() {
  for (final scale in [.02, .1, 1.0]) {
    test('Both sides and the full wall body resolve correctly at zoom $scale',
        () {
      for (final angle in [0.0, math.pi / 2, math.pi / 4, -math.pi / 3]) {
        final direction = DrawingPoint(math.cos(angle), math.sin(angle));
        final normal = DrawingPoint(-direction.y, direction.x);
        for (final screenLength in [12.0, 24.0, 200.0]) {
          final m = WallNetwork()
            ..addPolyline(
                [const DrawingPoint(0, 0), direction * (screenLength / scale)]);
          final id = m.walls.keys.single;
          for (final along in [
            math.min(8.0, screenLength * .3),
            screenLength / 2,
            screenLength - math.min(8.0, screenLength * .3)
          ]) {
            for (final side in [-14.0, 0.0, 14.0]) {
              final point =
                  direction * (along / scale) + normal * (side / scale);
              final hit = m.hitTest(point,
                  cornerRadius: 22 / scale,
                  wallRadius: 16 / scale,
                  endpointRadius: 6 / scale);
              expect(hit.wall, id,
                  reason:
                      'angle=$angle length=$screenLength along=$along side=$side');
              for (final sign in [-1.0, 1.0]) {
                final next = m.copy();
                next.moveWall(id,
                    normal * (sign * 30 / scale) + direction * (20 / scale));
                expect(next.length(id), closeTo(m.length(id), .001));
                final a = next.corners[next.walls[id]!.start]!;
                expect(a.dot(normal), closeTo(sign * 30 / scale, .001));
                expect(a.dot(direction), closeTo(20 / scale, .001));
              }
            }
          }
          final endpoint = m.hitTest(
              direction * (math.min(2.0, screenLength * .1) / scale),
              cornerRadius: 22 / scale,
              wallRadius: 16 / scale,
              endpointRadius: 6 / scale);
          expect(endpoint.corner, m.walls[id]!.start);
        }
      }
    });
  }

  for (final wallIndex in [0, 1, 2, 3]) {
    testWidgets(
        'Rectangle wall $wallIndex moves from both sides and along its body',
        (t) async {
      await board.open(t);
      await board.outline(t);
      await board.collapseTools(t);
      final v = board.painter(t), before = v.model.toJson();
      final wall = v.model.walls.values.elementAt(wallIndex);
      final a = v.model.corners[wall.start]!, b = v.model.corners[wall.end]!;
      final direction = (b - a) * (1 / (b - a).length);
      final normal = DrawingPoint(-direction.y, direction.x);
      final connected = {wall.start, wall.end};
      for (final fraction in [.08, .5, .92]) {
        for (final side in [-12.0, 0.0, 12.0]) {
          for (final sign in [-1.0, 1.0]) {
            final at = t.getTopLeft(board.canvas) +
                v.screen(a + (b - a) * fraction) +
                Offset(normal.x * side, normal.y * side);
            final drag = await t.startGesture(at);
            await drag.moveTo(
                at + Offset(normal.x * sign * 25, normal.y * sign * 25));
            await t.pump();
            final live = board.painter(t);
            expect(live.selectedWall, wall.id,
                reason: 'fraction=$fraction side=$side sign=$sign');
            expect(live.selectedCorner, isNull);
            expect(live.measuredWalls, contains(wall.id));
            expect(live.model.rectangle(wall.id), isNotNull);
            expect(live.model.length(wall.id),
                closeTo(v.model.length(wall.id), .001));
            final moved = live.model.corners[wall.start]! - a;
            expect(moved.dot(normal), closeTo(sign * 250, .001));
            for (final entry in v.model.corners.entries) {
              if (!connected.contains(entry.key)) {
                expect(live.model.corners[entry.key]!.x, entry.value.x);
                expect(live.model.corners[entry.key]!.y, entry.value.y);
              }
            }
            await drag.cancel();
            await t.pumpAndSettle();
            expect(board.painter(t).model.toJson(), before);
          }
        }
      }
      expect(t.takeException(), isNull);
    });
  }
}
