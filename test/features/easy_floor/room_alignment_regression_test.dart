import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_guides.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'whole_shape_move_test.dart' as rooms;

void main() {
  for (final scale in [.02, .1, 1.0]) {
    test('An aligned X edge does not block useful Y alignment at $scale', () {
      final m = rooms.rectangle(0, 0, 100 / scale, 100 / scale)
        ..addPolyline([
          DrawingPoint(300 / scale, 260 / scale),
          DrawingPoint(350 / scale, 201 / scale)
        ]);
      final selected =
          m.enclosedComponentAt(DrawingPoint(50 / scale, 50 / scale));
      final nodes = m.groupNodes(selected, {}), before = Map.of(m.corners);
      final applied = m.moveRoom(
          selected, DrawingPoint(200 / scale, 100 / scale),
          alignmentRadius: 6 / scale);
      expect(applied.x, closeTo(200 / scale, 1e-8));
      expect(applied.y, closeTo(101 / scale, 1e-8));
      for (final entry in before.entries) {
        final delta = m.corners[entry.key]! - entry.value;
        expect(
            delta.x, closeTo(nodes.contains(entry.key) ? applied.x : 0, 1e-8));
        expect(
            delta.y, closeTo(nodes.contains(entry.key) ? applied.y : 0, 1e-8));
      }
      final geometry = m.toJson();
      final guides = roomMovementGuides(m, nodes, 6 / scale);
      expect(guides.map((g) => g.kind).toSet(),
          {GuideKind.horizontal, GuideKind.vertical});
      expect(guides.any((g) => (g.end - m.corners[nodes.first]!).length < .001),
          isFalse);
      for (final guide in guides) {
        expect(
            m.corners.entries.any((e) =>
                !nodes.contains(e.key) &&
                (e.value - guide.target).length < .001),
            isTrue);
        expect(nodes.any((id) => (m.corners[id]! - guide.end).length < .001),
            isTrue);
      }
      expect(m.toJson(), geometry);
      expect(() => WallNetwork.fromJson(geometry), returnsNormally);
    });
  }

  test('Compatible X and Y alignments preserve one rigid room translation', () {
    final m = rooms.rectangle(0, 0, 1000, 1000)
      ..addPolyline(
          [const DrawingPoint(3000, 3500), const DrawingPoint(3500, 3000)]);
    final selected = m.enclosedComponentAt(const DrawingPoint(500, 500));
    final lengths = {for (final id in selected) id: m.length(id)};
    final applied = m.moveRoom(selected, const DrawingPoint(1990, 1990),
        alignmentRadius: 60);
    expect(applied.x, 2000);
    expect(applied.y, 2000);
    for (final id in selected) {
      expect(m.length(id), lengths[id]);
    }
    expect(() => WallNetwork.fromJson(m.toJson()), returnsNormally);
  });

  test('Unsafe two-axis snapping retains a safe single-axis placement', () {
    final m = rooms.rectangle(0, 0, 1000, 1000)
      ..addPolyline(
          [const DrawingPoint(3000, 3000), const DrawingPoint(4000, 3000)]);
    final selected = m.enclosedComponentAt(const DrawingPoint(500, 500));
    final applied = m.moveRoom(selected, const DrawingPoint(1990, 1990),
        alignmentRadius: 60);
    expect(applied.x, 2000);
    expect(applied.y, 1990);
    expect(m.corners.length, 6);
    expect(m.walls.length, 5);
    expect(() => WallNetwork.fromJson(m.toJson()), returnsNormally);
  });

  test('A lone shape never shows guides to its own corners', () {
    final m = rooms.rectangle(0, 0, 1000, 1000);
    expect(roomMovementGuides(m, m.corners.keys.toSet(), 60), isEmpty);
  });

  test('Distant rooms do not generate irrelevant group alignment guides', () {
    final m = rooms.rectangle(0, 0, 1000, 1000)
      ..addPolyline(
          [const DrawingPoint(100000, 1000), const DrawingPoint(101000, 1000)]);
    final selected = m.enclosedComponentAt(const DrawingPoint(500, 500));
    expect(roomMovementGuides(m, m.groupNodes(selected, {}), 60), isEmpty);
  });
}
