import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_relation.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_history.dart';

DrawingPoint p(double x, double y) => DrawingPoint(x, y);
WallNetwork room() => WallNetwork()
  ..addPolyline([p(0, 0), p(2000, 0), p(2000, 2000), p(0, 2000), p(0, 0)]);
String signature(WallNetwork m) =>
    '${m.corners.entries.map((e) => '${e.key}:${e.value.x},${e.value.y}').join(';')}|${m.walls.values.map((w) => '${w.id}:${w.start},${w.end}').join(';')}|${m.constraintSignature}';
void main() {
  test(
      'Small rooms, long corridors and irregular plans retain geometry under group edits',
      () {
    final layouts = [
      [p(0, 0), p(800, 0), p(800, 1000), p(0, 1000), p(0, 0)],
      [p(0, 0), p(100000, 0), p(100000, 500), p(0, 500), p(0, 0)],
      [
        p(0, 0),
        p(3500, 600),
        p(2800, 2600),
        p(1300, 1700),
        p(0, 2200),
        p(0, 0)
      ],
    ];
    for (final points in layouts) {
      final m = WallNetwork()..addPolyline(points), ids = <int>{};
      ids.addAll(m.walls.keys);
      final lengths = ids.map(m.length).toList();
      for (var i = 0; i < 25; i++) {
        m.moveGroup(ids, {}, p(20, 15));
      }
      expect(m.corners.length, points.length - 1);
      final result = ids.map(m.length).toList();
      for (var i = 0; i < result.length; i++) {
        expect(result[i], closeTo(lengths[i], 1e-6));
      }
    }
  });

  test(
      'Right-angle, parallel and equal-length locks preserve valid edits and reject conflicts',
      () {
    final m = room(), ids = room().walls.keys.toList();
    m.constrain(WallRelationKind.rightAngle, ids[0], ids[1]);
    m.constrain(WallRelationKind.parallel, ids[0], ids[2]);
    m.constrain(WallRelationKind.equalLength, ids[0], ids[2]);
    m.moveWall(ids[0], p(0, -100), join: true);
    final before = signature(m), end = m.walls[ids[0]]!.end;
    expect(() => m.moveCorners({end: m.corners[end]! + p(100, 50)}),
        throwsA(isA<DrawingConflict>()));
    expect(signature(m), before);
    m.splitWall(ids[0], 1000);
    final node = m.nearestCorner(p(1000, -100), .001)!;
    m.joinAtCorner(node);
    expect(m.relations.length, 3);
    expect(m.walls.length, 4);
  });
  test('Incompatible constraints are atomic and visible in history snapshots',
      () {
    final m = WallNetwork()..addPolyline([p(0, 0), p(1000, 0), p(1500, 1000)]);
    final ids = m.walls.keys.toList(), before = signature(m);
    for (final kind in WallRelationKind.values) {
      expect(() => m.constrain(kind, ids[0], ids[1]),
          throwsA(isA<DrawingConflict>()));
      expect(signature(m), before);
    }
    final r = room(), h = DrawingHistory()..commit(room());
    final pair = r.walls.keys.toList();
    r.constrain(WallRelationKind.parallel, pair[0], pair[2]);
    h.commit(r);
    expect(h.undo().relations, isEmpty);
    expect(h.redo().relations.length, 1);
  });
  test(
      'Group movement rejects unapproved external changes and preserves internal connections',
      () {
    final m = room(), id = room().walls.keys.first, before = signature(room());
    expect(() => m.moveGroup({id}, {}, p(0, 100)),
        throwsA(isA<DrawingConflict>()));
    expect(signature(m), before);
    m.moveGroup({id}, {}, p(0, 100), stretchAttached: true);
    expect(m.length(id), 2000);
    expect(m.corners.length, 4);
    m.addPolyline([p(8000, 0), p(9000, 0)]);
    final far = m.walls.values.last,
        old = m.corners[m.walls.values.last.start]!;
    final selected = m.walls.keys.where((w) => w != far.id).toSet();
    m.moveGroup(selected, {}, p(100, 200));
    expect(m.corners[far.start], same(old));
  });
  test(
      'Duplication preserves shared points, fixed lengths and internal relationships',
      () {
    final m = room(), ids = room().walls.keys.toList();
    m.setLength(ids[0], 2000, lock: true);
    m.constrain(WallRelationKind.rightAngle, ids[0], ids[1]);
    m.constrain(WallRelationKind.equalLength, ids[0], ids[2]);
    final oldNodes = m.corners.keys.toSet(), oldSignature = signature(m);
    expect(() => m.duplicateGroup({ids[0]}, {}, p(4000, 0)),
        throwsA(isA<DrawingConflict>()));
    expect(signature(m), oldSignature);
    final copied = m.duplicateGroup(ids.toSet(), {}, p(4000, 0));
    expect(copied.length, 4);
    expect(m.corners.length, 8);
    expect(m.relations.length, 4);
    expect(copied.any(m.isFixed), isTrue);
    final nodes = m.groupNodes(copied, {});
    expect(nodes.intersection(oldNodes), isEmpty);
    m.moveGroup(copied, {}, p(100, 100));
    m.deleteGroup(copied, {});
    expect(signature(m), oldSignature);
  });
  test('Copies cannot overlap or reconnect to existing geometry', () {
    final m = room(),
        ids = room().walls.keys.toSet(),
        before = signature(room());
    for (final delta in [p(0, 0), p(2000, 0), p(.0005, 0)]) {
      expect(() => m.duplicateGroup(ids, {}, delta),
          throwsA(isA<DrawingConflict>()));
      expect(signature(m), before);
    }
  });
  test('Known-dimension calibration uniformly rescales plan and respects locks',
      () {
    final m = room(),
        ids = room().walls.keys.toList(),
        h = DrawingHistory()..commit(room());
    m.constrain(WallRelationKind.rightAngle, ids[0], ids[1]);
    m.calibrateFromWall(ids[0], 3500);
    h.commit(m);
    expect(m.calibrated, isTrue);
    for (final id in ids) {
      expect(m.length(id), 3500);
    }
    expect(h.undo().calibrated, isFalse);
    expect(h.redo().calibrated, isTrue);
    m.setLength(ids[0], 3500, lock: true);
    final before = signature(m);
    expect(() => m.calibrateFromWall(ids[0], 4000),
        throwsA(isA<DrawingConflict>()));
    expect(signature(m), before);
    expect(() => m.calibrateFromWall(ids[0], double.nan),
        throwsA(isA<DrawingConflict>()));
    for (final unit in DrawingUnit.values) {
      expect(unit.readMm(unit.input(3500)), closeTo(3500, 1e-6));
    }
  });
  test(
      'Long editing history retains latest 50 operations and bounded, connected geometry',
      () {
    var m = room();
    final ids = m.walls.keys.toSet(), h = DrawingHistory()..commit(m);
    for (var i = 0; i < 80; i++) {
      m.moveGroup(ids, {}, p(10, 5));
      h.commit(m);
    }
    var count = 0;
    while (h.canUndo) {
      m = h.undo();
      count++;
      expect(m.walls.length, 4);
      expect(m.corners.length, 4);
    }
    expect(count, 50);
    while (h.canRedo) {
      m = h.redo();
    }
    expect(m.corners.values.first.x, 800);
  });
}
