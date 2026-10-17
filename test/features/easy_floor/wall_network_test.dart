import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_history.dart';

DrawingPoint p(double x, double y) => DrawingPoint(x, y);
Matcher get conflict => throwsA(isA<DrawingConflict>());

void main() {
  test(
      'L, U and T outlines keep their segment topology rather than becoming rectangles',
      () {
    final outlines = [
      [
        p(0, 0),
        p(3000, 0),
        p(3000, 1000),
        p(1000, 1000),
        p(1000, 3000),
        p(0, 3000),
        p(0, 0)
      ],
      [
        p(0, 0),
        p(1000, 0),
        p(1000, 2000),
        p(2000, 2000),
        p(2000, 0),
        p(3000, 0),
        p(3000, 3000),
        p(0, 3000),
        p(0, 0)
      ],
      [
        p(0, 0),
        p(3000, 0),
        p(3000, 1000),
        p(2000, 1000),
        p(2000, 3000),
        p(1000, 3000),
        p(1000, 1000),
        p(0, 1000),
        p(0, 0)
      ],
    ];
    for (final outline in outlines) {
      final model = WallNetwork()..addPolyline(straightenStroke(outline, 20));
      expect(model.walls.length, outline.length - 1);
      expect(model.corners.length, outline.length - 1);
    }
  });
  test(
      'A measured wall keeps its total length when a partition slides along it',
      () {
    final model = WallNetwork()..addPolyline([p(0, 0), p(4000, 0)]);
    model.setLength(model.walls.keys.single, 4000, lock: true);
    model.addPolyline([p(2000, 0), p(2000, 2000)]);
    final junction = model.nearestCorner(p(2000, 0), 1)!;
    model.moveCorners({junction: p(2500, 0)}, join: true);
    expect(model.corners[junction]!.x, 2500);
    expect(() => model.moveCorners({junction: p(2500, 200)}), conflict);
    expect(model.corners[junction]!.y, 0);
    final piece = model.walls.values.firstWhere((w) => model.isFixed(w.id));
    model.unlock(piece.id);
    model.moveCorners({junction: p(2500, 200)}, join: true);
    expect(model.corners[junction]!.y, 200);
  });
  test('A partition snaps to a wall and shares a junction corner', () {
    final model = WallNetwork()..addPolyline([p(0, 0), p(4000, 0)]);
    model.addPolyline([p(2000, 20), p(2000, 3000)], snapRadius: 50);
    expect(model.walls.length, 3);
    final junction = model.nearestCorner(p(2000, 0), 1)!;
    expect(
        model.walls.values
            .where((w) => w.start == junction || w.end == junction)
            .length,
        3);
  });
  test('Crossing partitions are split into connected segments', () {
    final model = WallNetwork()..addPolyline([p(0, 2000), p(4000, 2000)]);
    model.addPolyline([p(2000, 0), p(2000, 4000)]);
    expect(model.walls.length, 4);
    expect(model.corners.length, 5);
    final junction = model.nearestCorner(p(2000, 2000), 1)!;
    expect(
        model.walls.values
            .where((w) => w.start == junction || w.end == junction)
            .length,
        4);
  });
  test('Overlaps and shared room boundaries reuse walls', () {
    final overlap = WallNetwork()..addPolyline([p(0, 0), p(3000, 0)]);
    overlap.addPolyline([p(1000, 0), p(4000, 0)]);
    expect(overlap.walls.length, 3);
    final rooms = WallNetwork()
      ..addPolyline([p(0, 0), p(3000, 0), p(3000, 3000), p(0, 3000), p(0, 0)]);
    rooms.addPolyline(
        [p(3000, 0), p(6000, 0), p(6000, 3000), p(3000, 3000), p(3000, 0)]);
    expect(rooms.walls.length, 7);
    expect(rooms.corners.length, 6);
  });
  test('Shared corner edits affect only connected walls', () {
    final model = WallNetwork()
      ..addPolyline([p(0, 0), p(3000, 0), p(3000, 3000)]);
    model.addPolyline([p(8000, 0), p(9000, 0)]);
    final junction = model.nearestCorner(p(3000, 0), 1)!;
    final untouched = model.walls.values.last;
    final a = model.corners[untouched.start]!;
    model.moveCorners({junction: p(3500, 0)}, join: true);
    expect(
        model.walls.values
            .where((w) => w.start == junction || w.end == junction)
            .length,
        2);
    expect(model.corners[untouched.start], same(a));
    expect(model.length(untouched.id), 1000);
  });
  test('Locked lengths report conflicts and an edit rolls back atomically', () {
    final model = WallNetwork()
      ..addPolyline([p(0, 0), p(1000, 0), p(1000, 1000)]);
    final first = model.walls.values.first;
    model.setLength(first.id, 1000, lock: true);
    expect(() => model.moveCorners({first.end: p(1200, 0)}), conflict);
    expect(model.length(first.id), 1000);
    expect(model.corners[first.end]!.x, 1000);
    model.setLength(first.id, 1000, lock: false);
    model.moveCorners({first.end: p(1200, 0)});
    expect(model.length(first.id), 1200);
  });
  test('Parallel movement preserves the selected wall direction and length',
      () {
    final model = WallNetwork()..addPolyline([p(0, 0), p(1000, 1000)]);
    final wall = model.walls.values.single;
    final size = model.length(wall.id);
    model.moveWall(wall.id, p(-200, 200));
    expect(model.length(wall.id), closeTo(size, 1e-7));
    expect(model.corners[wall.start]!.x, closeTo(-200, 1e-7));
  });
  test('Rectangle dimensions edit both sides and reject fixed conflicts', () {
    final model = WallNetwork()
      ..addPolyline([p(0, 0), p(3000, 0), p(3000, 3000), p(0, 3000), p(0, 0)]);
    final id = model.walls.keys.first;
    expect(model.rectangle(id), isNotNull);
    model.resizeRectangle(id, 4000, 2000);
    expect(model.length(id), 4000);
    final nodes = model.rectangle(id)!;
    expect((model.corners[nodes[2]]! - model.corners[nodes[1]]!).length, 2000);
    model.setLength(id, 4000, lock: true);
    expect(() => model.resizeRectangle(id, 5000, 2000), conflict);
    expect(model.length(id), 4000);
  });
  test('Undo restores connected geometry and branching drops redo', () {
    final history = DrawingHistory();
    var model = WallNetwork()..addPolyline([p(0, 0), p(1000, 0)]);
    history.commit(model);
    model.addPolyline([p(1000, 0), p(1000, 1000)]);
    history.commit(model);
    model = history.undo();
    expect(model.walls.length, 1);
    model.addPolyline([p(0, 0), p(0, 1000)]);
    history.commit(model);
    expect(history.canRedo, isFalse);
    expect(history.undo().walls.length, 1);
    expect(history.redo().walls.length, 2);
  });
  test('Deleting a corner removes only its incident geometry', () {
    final model = WallNetwork()
      ..addPolyline([p(0, 0), p(1000, 0), p(1000, 1000)]);
    model.addPolyline([p(5000, 0), p(6000, 0)]);
    model.deleteCorner(model.nearestCorner(p(1000, 0), 1)!);
    expect(model.walls.length, 1);
    expect(model.corners.length, 2);
  });
  test('Units and stroke simplification preserve intended irregular corners',
      () {
    final aligned = alignEndpoint(p(0, 0), p(1000, 20));
    expect(aligned.y, closeTo(0, 1e-9));
    final free = p(1000, 300);
    expect(alignEndpoint(p(0, 0), free), same(free));
    expect(DrawingUnit.inches.toMm(12), closeTo(304.8, 1e-9));
    expect(DrawingUnit.feet.toMm(1), closeTo(304.8, 1e-9));
    final outline = straightenStroke([
      p(0, 0),
      p(500, 4),
      p(2000, 0),
      p(2000, 1000),
      p(1000, 1000),
      p(1000, 2000),
      p(0, 2000),
      p(0, 0)
    ], 20);
    expect(outline.length, 7);
    expect(outline.any((v) => v.x == 1000 && v.y == 1000), isTrue);
    final model = WallNetwork();
    expect(() => model.addPolyline([p(0, 0), p(double.infinity, 0)]), conflict);
    expect(model.walls, isEmpty);
  });
}
