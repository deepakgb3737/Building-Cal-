import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_history.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_resize.dart';

void main() {
  for (final seed in [17, 42, 2026]) {
    test('Independent final audit: 100 mixed connected edits, seed $seed', () {
      final random = math.Random(seed);
      final m = WallNetwork()
        ..addPolyline(const [
          DrawingPoint(0, 0),
          DrawingPoint(4000, 0),
          DrawingPoint(4000, 3000),
          DrawingPoint(0, 3000),
          DrawingPoint(0, 0)
        ])
        ..addPolyline(const [DrawingPoint(2000, 0), DrawingPoint(2000, 3000)])
        ..addPolyline(const [DrawingPoint(0, 1500), DrawingPoint(4000, 1500)]);
      m.addPolyline(const [DrawingPoint(8000, 0), DrawingPoint(9000, 1000)]);
      final independent = m.walls.values.last;
      final independentStart = m.corners[independent.start]!;
      final independentEnd = m.corners[independent.end]!;
      final history = DrawingHistory()..commit(m);
      var applied = 0, rejected = 0;
      for (var step = 0; step < 100; step++) {
        final before = m.toJson();
        final choices =
            m.walls.values.where((w) => w.id != independent.id).toList();
        final wall = choices[random.nextInt(choices.length)];
        final delta = DrawingPoint(
            random.nextDouble() * 160 - 80, random.nextDouble() * 160 - 80);
        try {
          switch (step % 5) {
            case 0:
              m.moveWall(wall.id, delta, join: true);
            case 1:
              m.moveCorners({wall.start: m.corners[wall.start]! + delta},
                  join: true);
            case 2:
              m.setLength(
                  wall.id, m.length(wall.id) + random.nextDouble() * 100 - 50,
                  lock: false,
                  join: true,
                  anchor: WallResizeAnchor
                      .values[step % WallResizeAnchor.values.length]);
            case 3:
              m.setLength(wall.id, m.length(wall.id), lock: true, join: true);
            case 4:
              m.unlock(wall.id);
          }
          applied++;
        } on DrawingConflict catch (e) {
          rejected++;
          expect(e.message, isNotEmpty);
          expect(m.toJson(), before, reason: 'Rejected edit must be atomic');
        }
        expect(m.corners[independent.start], same(independentStart));
        expect(m.corners[independent.end], same(independentEnd));
        expect(WallNetwork.fromJson(m.toJson()).toJson(), m.toJson(),
            reason:
                'Every completed edit must remain canonical and reloadable');
        final after = m.toJson();
        if (before.toString() != after.toString()) {
          history.commit(m);
          expect(history.undo().toJson(), before);
          expect(history.redo().toJson(), after);
        }
      }
      expect(applied, greaterThan(20));
      expect(applied + rejected, 100);
    });
  }
}
