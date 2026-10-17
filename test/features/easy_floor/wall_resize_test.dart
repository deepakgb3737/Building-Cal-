import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_history.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_resize.dart';

void main() {
  const p = DrawingPoint.new;
  for (final direction in [p(1, 0), p(0, 1), p(.6, .8)]) {
    for (final anchor in WallResizeAnchor.values) {
      for (final length in [1500.0, 2500.0]) {
        test(
            '$direction $anchor resize to $length preserves direction and anchor',
            () {
          final a = p(100, 200), b = a + direction * 2000;
          final m = WallNetwork()..addPolyline([a, b]);
          final wall = m.walls.values.single;
          m.addPolyline([p(10000, 10000), p(11000, 10000)]);
          final unrelated = Map.of(m.corners)
            ..remove(wall.start)
            ..remove(wall.end);
          m.setLength(wall.id, length, lock: false, anchor: anchor);
          final start = m.corners[wall.start]!, end = m.corners[wall.end]!;
          expect(m.length(wall.id), closeTo(length, 1e-7));
          expect(((end - start) - direction * length).length, lessThan(1e-7));
          final fixed = switch (anchor) {
            WallResizeAnchor.start => (start - a).length,
            WallResizeAnchor.end => (end - b).length,
            WallResizeAnchor.center =>
              ((start + end) * .5 - (a + b) * .5).length,
          };
          expect(fixed, lessThan(1e-7));
          for (final entry in unrelated.entries) {
            expect(m.corners[entry.key], entry.value);
          }
        });
      }
    }
  }

  test(
      'Shared wall centered resize updates both rooms and undo restores all junctions',
      () {
    final m = WallNetwork()
      ..addPolyline([p(0, 0), p(3000, 0), p(3000, 3000), p(0, 3000), p(0, 0)])
      ..addPolyline(
          [p(3000, 0), p(6000, 0), p(6000, 3000), p(3000, 3000), p(3000, 0)]);
    final id = m.nearestWall(p(3000, 1500), 1)!, wall = m.walls[id]!;
    final history = DrawingHistory()..commit(m);
    final original = m.toJson();
    m.setLength(id, 4000, lock: false, anchor: WallResizeAnchor.center);
    history.commit(m);
    expect((m.corners[wall.start]! - p(3000, -500)).length, lessThan(1e-7));
    expect((m.corners[wall.end]! - p(3000, 3500)).length, lessThan(1e-7));
    expect(m.walls.length, 7);
    for (final corner in [wall.start, wall.end]) {
      expect(
          m.walls.values
              .where((w) => w.start == corner || w.end == corner)
              .length,
          3);
    }
    expect(m.nearestCorner(p(0, 0), .001), isNotNull);
    expect(m.nearestCorner(p(6000, 3000), .001), isNotNull);
    expect(history.undo().toJson(), original);
    expect(history.redo().toJson(), m.toJson());
    expect(WallNetwork.fromJson(m.toJson()).toJson(), m.toJson());
  });

  test(
      'Connected locked wall rejects conflicting resize atomically with an explanation',
      () {
    final m = WallNetwork()..addPolyline([p(0, 0), p(2000, 0), p(2000, 2000)]);
    final first = m.walls.keys.first, adjacent = m.walls.keys.last;
    m.setLength(adjacent, 2000, lock: true);
    final before = m.toJson();
    expect(
        () => m.setLength(first, 3000,
            lock: false, anchor: WallResizeAnchor.center),
        throwsA(isA<DrawingConflict>()
            .having((e) => e.message, 'message', isNotEmpty)));
    expect(m.toJson(), before);
    for (final invalid in [0.0, double.nan, double.infinity]) {
      expect(() => m.setLength(first, invalid, lock: false),
          throwsA(isA<DrawingConflict>()));
      expect(m.toJson(), before);
    }
  });
}
