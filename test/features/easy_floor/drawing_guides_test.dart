import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_guides.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';

DrawingPoint p(double x, double y) => DrawingPoint(x, y);
void main() {
  test('First wall can show an axis guide without existing geometry', () {
    final guides =
        drawingGuides(WallNetwork(), p(1000, 10), 60, anchor: p(0, 0));
    expect(guides.single.kind, GuideKind.horizontal);
    expect(drawingGuides(WallNetwork(), p(1000, 300), 60, anchor: p(0, 0)),
        isEmpty);
  });
  test('Guides are display only and select at most two relevant alignments',
      () {
    final m = WallNetwork()..addPolyline([p(0, 0), p(1000, 0), p(1000, 1000)]);
    final corners = Map.of(m.corners), walls = Map.of(m.walls);
    final guides = drawingGuides(m, p(2000, 20), 60);
    expect(guides, isNotEmpty);
    expect(guides.length, lessThanOrEqualTo(2));
    expect(
        guides.any((g) =>
            g.kind == GuideKind.horizontal || g.kind == GuideKind.extension),
        isTrue);
    expect(m.corners, corners);
    expect(m.walls, walls);
    expect(drawingGuides(m, p(2400, 2400), 60), isEmpty);
  });
  test(
      'Zoom tolerance is screen based; existing candidate resists nearby competitors',
      () {
    final m = WallNetwork()..addPolyline([p(0, 0), p(1000, 0)]);
    m.addPolyline([p(0, 100), p(1000, 100)]);
    final first = drawingGuides(m, p(2000, 45), 60);
    final next = drawingGuides(m, p(2000, 51), 60, previous: first);
    expect(next.first.key, first.first.key);
    expect(drawingGuides(m, p(2000, 400), 60), isEmpty);
    expect(drawingGuides(m, p(2000, 400), 600), isNotEmpty);
  });
  test('Parallel and angled extension guides preserve arbitrary orientations',
      () {
    final m = WallNetwork()..addPolyline([p(0, 0), p(1000, 700)]);
    final extension = drawingGuides(m, p(2000, 1405), 20);
    expect(extension.any((g) => g.kind == GuideKind.extension), isTrue);
    final parallel = drawingGuides(m, p(2000, 1800), 20, anchor: p(1000, 1100));
    expect(parallel.any((g) => g.kind == GuideKind.parallel), isTrue);
    expect(drawingGuides(m, p(2000, 1405), 20, exclude: m.corners.keys.toSet()),
        isEmpty);
  });
}
