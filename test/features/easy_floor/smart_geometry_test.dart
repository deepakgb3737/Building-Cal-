import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_history.dart';

DrawingPoint p(double x, double y) => DrawingPoint(x, y);
String geometry(WallNetwork m) =>
    '${m.corners.entries.map((e) => '${e.key}:${e.value.x},${e.value.y}').join(';')}|${m.walls.values.map((e) => '${e.id}:${e.start},${e.end}').join(';')}';
WallNetwork rooms() => WallNetwork()
  ..addPolyline([p(0, 0), p(4000, 0), p(4000, 3000), p(0, 3000), p(0, 0)])
  ..addPolyline([p(2000, 0), p(2000, 3000)]);

void main() {
  test(
      'Shared wall moves both rooms, stays connected after repeated edits and undo restores topology',
      () {
    final m = rooms();
    final history = DrawingHistory()..commit(m);
    final original = geometry(m);
    final shared = m.nearestWall(p(2000, 1500), 1)!;
    for (var i = 0; i < 20; i++) {
      m.moveWall(shared, p(25, 70), join: true);
      expect(m.length(shared), closeTo(3000, .001));
      expect(m.walls.length, 7);
      expect(m.corners.length, 6);
      final wall = m.walls[shared]!;
      for (final node in [wall.start, wall.end]) {
        expect(
            m.walls.values
                .where((w) => w.start == node || w.end == node)
                .length,
            3);
      }
    }
    history.commit(m);
    expect(geometry(history.undo()), original);
  });
  test(
      'Moving split outer wall translates its straight run and attached partition',
      () {
    final m = rooms();
    m.addPolyline([p(9000, 0), p(10000, 0)]);
    final independent = m.walls.values.last;
    final start = m.corners[independent.start]!;
    final top = m.nearestWall(p(1000, 0), 1)!;
    m.moveWall(top, p(100, -200), join: true);
    for (final x in [0.0, 2000.0, 4000.0]) {
      expect(m.nearestCorner(p(x + 100, -200), .001), isNotNull);
    }
    expect(m.corners[independent.start], same(start));
    expect(m.length(top), 2000);
  });
  test('L shape corner changes only attached walls without rectangle coercion',
      () {
    final m = WallNetwork()
      ..addPolyline([
        p(0, 0),
        p(3000, 0),
        p(3000, 1000),
        p(1000, 1000),
        p(1000, 3000),
        p(0, 3000),
        p(0, 0)
      ]);
    final corner = m.nearestCorner(p(1000, 1000), 1)!;
    m.moveCorners({corner: p(1200, 1400)}, join: true);
    expect(m.walls.length, 6);
    expect(m.corners[corner]!.y, 1400);
    expect(m.nearestCorner(p(3000, 0), 1), isNotNull);
  });
  test('Crossing and overlap movements fail atomically with explanation', () {
    final m = WallNetwork()..addPolyline([p(0, 0), p(1000, 0)]);
    m.addPolyline([p(500, 500), p(500, 1500)]);
    final before = geometry(m);
    expect(
        () => m.moveWall(m.walls.keys.first, p(0, 1000)),
        throwsA(isA<DrawingConflict>().having(
            (e) => e.message, 'reason', contains('crosses or overlaps'))));
    expect(geometry(m), before);
  });
  test('Conflicting exact dimensions explain fixed span and preserve geometry',
      () {
    final m = WallNetwork()
      ..addPolyline([p(0, 0), p(2000, 0), p(2000, 2000), p(0, 2000), p(0, 0)]);
    final top = m.walls.keys.first;
    final right = m.walls.values.elementAt(1);
    m.setLength(right.id, 2000, lock: true);
    final before = geometry(m);
    expect(
        () => m.setLength(top, 2500, lock: true),
        throwsA(isA<DrawingConflict>()
            .having((e) => e.message, 'reason', contains('fixed'))));
    expect(geometry(m), before);
    expect(DrawingUnit.centimetres.toMm(250), 2500);
  });
}
