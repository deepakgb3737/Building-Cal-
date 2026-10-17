import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_history.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_precision.dart';

DrawingPoint p(double x, double y) => DrawingPoint(x, y);
String signature(WallNetwork m) =>
    '${m.corners.entries.map((e) => '${e.key}:${e.value.x},${e.value.y}').join(';')}|${m.walls.values.map((w) => '${w.id}:${w.start},${w.end}').join(';')}|${m.constraintSignature}';
void main() {
  test('Reversed overlapping edges are rejected without changing the plan', () {
    final m = WallNetwork()..addPolyline([p(0, 0), p(1000, 0)]);
    m.addPolyline([p(1000, 500), p(0, 500)]);
    final before = signature(m);
    expect(() => m.moveWall(m.walls.keys.first, p(0, 500)),
        throwsA(isA<DrawingConflict>()));
    expect(signature(m), before);
  });

  test(
      'Split and rejoin retain fixed span constraints and undo/redo relationships',
      () {
    final m = WallNetwork()..addPolyline([p(0, 0), p(3000, 0)]);
    m.setLength(m.walls.keys.single, 3000, lock: true);
    final h = DrawingHistory()..commit(m), original = signature(m);
    m.splitWall(m.walls.keys.single, 1200);
    expect(m.walls.length, 2);
    final node = m.nearestCorner(p(1200, 0), .001)!;
    expect(m.walls.keys.every(m.isFixed), isTrue);
    h.commit(m);
    final joined = m.joinAtCorner(node);
    expect(m.walls.length, 1);
    expect(m.length(joined), 3000);
    expect(m.isFixed(joined), isTrue);
    h.commit(m);
    expect(h.undo().walls.length, 2);
    expect(signature(h.undo()), original);
    expect(h.redo().walls.length, 2);
    expect(h.redo().isFixed(joined), isTrue);
  });
  test(
      'Join rejects branches, angles and independently locked segments atomically',
      () {
    final m = WallNetwork()..addPolyline([p(0, 0), p(1000, 0), p(2000, 0)]);
    final node = m.nearestCorner(p(1000, 0), 1)!;
    m.setLength(m.walls.keys.first, 1000, lock: true);
    var before = signature(m);
    expect(() => m.joinAtCorner(node), throwsA(isA<DrawingConflict>()));
    expect(signature(m), before);
    m.unlock(m.walls.keys.first);
    m.addPolyline([p(1000, 0), p(1000, 1000)]);
    before = signature(m);
    expect(() => m.joinAtCorner(node), throwsA(isA<DrawingConflict>()));
    expect(signature(m), before);
    final angled = WallNetwork()
      ..addPolyline([p(0, 0), p(1000, 0), p(1000, 1000)]);
    expect(() => angled.joinAtCorner(angled.nearestCorner(p(1000, 0), 1)!),
        throwsA(isA<DrawingConflict>()));
  });
  test('Short strokes and invalid splits reject all partial changes', () {
    final m = WallNetwork();
    expect(() => m.addPolyline([p(0, 0), p(1000, 0), p(1003, 0)]),
        throwsA(isA<DrawingConflict>()));
    expect(m.walls, isEmpty);
    m.addPolyline([p(0, 0), p(1000, 0)]);
    final before = signature(m);
    expect(() => m.splitWall(m.walls.keys.single, 995),
        throwsA(isA<DrawingConflict>()));
    expect(signature(m), before);
    expect(() => m.moveWall(m.walls.keys.single, p(double.nan, 0)),
        throwsA(isA<DrawingConflict>()));
    expect(signature(m), before);
  });
  test('Reconnect to midpoint forms an actual shared T junction', () {
    final m = WallNetwork()..addPolyline([p(0, 0), p(3000, 0)]);
    m.addPolyline([p(1500, 100), p(1500, 1000)]);
    final end = m.nearestCorner(p(1500, 100), 1)!;
    m.moveCorners({end: p(1500, 0)}, join: true);
    final junction = m.nearestCorner(p(1500, 0), 1)!;
    expect(
        m.walls.values
            .where((w) => w.start == junction || w.end == junction)
            .length,
        3);
    expect(m.walls.length, 3);
    m.moveCorners({junction: p(1600, 0)}, join: true);
    expect(
        m.walls.values
            .where((w) => w.start == junction || w.end == junction)
            .length,
        3);
  });
  test(
      'Straight-run movement can require explicit consent; disconnected walls stay untouched',
      () {
    final m = WallNetwork()..addPolyline([p(0, 0), p(1000, 0), p(2000, 0)]);
    m.addPolyline([p(5000, 0), p(6000, 0)]);
    final first = m.walls.keys.first, far = m.walls.values.last;
    final before = signature(m), untouched = m.corners[far.start]!;
    expect(() => m.moveWall(first, p(0, 100), includeStraightRun: false),
        throwsA(isA<DrawingConflict>()));
    expect(signature(m), before);
    m.moveWall(first, p(50, 100), includeStraightRun: true, join: true);
    expect(m.length(first), 1000);
    expect(m.corners[far.start], same(untouched));
  });
  test(
      'Precision assistance is optional and does not mutate reference geometry',
      () {
    final m = WallNetwork()..addPolyline([p(0, 0), p(2000, 1000)]);
    final before = signature(m), point = p(1234, 687);
    expect(precisionPoint(m, point, anchor: p(0, 0)), same(point));
    final grid = precisionPoint(m, p(1020, 980), grid: true, tolerance: 60);
    expect(grid.x, 1000);
    expect(grid.y, 1000);
    final axis = precisionPoint(m, p(1000, 20), anchor: p(0, 0), axes: true);
    expect(axis.y, closeTo(0, .001));
    final diagonal =
        precisionPoint(m, p(1000, 700), anchor: p(0, 0), axes: true);
    expect(diagonal.x, 1000);
    expect(diagonal.y, 700);
    final parallel =
        precisionPoint(m, p(2000, 1010), anchor: p(0, 0), parallel: true);
    expect(parallel.y / parallel.x, closeTo(.5, .001));
    final increment =
        precisionPoint(m, p(1000, 1010), anchor: p(0, 0), angleStep: 15);
    expect(increment.y / increment.x, closeTo(1, .001));
    expect(signature(m), before);
  });
  test(
      'Repeated connected edits on a dense cross-junction layout preserve topology',
      () {
    final m = WallNetwork();
    for (var x = 0; x <= 10; x++) {
      m.addPolyline([p(x * 200, 0), p(x * 200, 2000)]);
    }
    for (var y = 0; y <= 10; y++) {
      m.addPolyline([p(0, y * 200), p(2000, y * 200)]);
    }
    final before = signature(m), count = m.walls.length;
    final junction = m.nearestCorner(p(1000, 1000), 1)!;
    final h = DrawingHistory()..commit(m);
    for (var i = 0; i < 30; i++) {
      m.moveCorners({junction: p(1000 + (i % 2) * 20, 1000 + (i % 3) * 10)},
          join: true);
      expect(m.walls.length, count);
      expect(
          m.walls.values
              .where((w) => w.start == junction || w.end == junction)
              .length,
          4);
    }
    h.commit(m);
    expect(signature(h.undo()), before);
    expect(h.redo().walls.length, count);
  });
}
