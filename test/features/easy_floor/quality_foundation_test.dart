import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';

void main() {
  test('Near-end projection chooses the corner, not an unusable tiny split',
      () {
    for (final scale in [.02, .1, 1.0, 2.0]) {
      final m = WallNetwork()
        ..addPolyline(const [DrawingPoint(0, 0), DrawingPoint(1000, 0)]);
      final snapped = m.snap(const DrawingPoint(995, 3), 16 / scale);
      expect(snapped.x, 1000);
      expect(snapped.y, 0);
      m.addPolyline([const DrawingPoint(1300, 400), snapped]);
      expect(m.walls.length, 2);
      expect(m.corners.length, 3);
      final copy = WallNetwork.fromJson(m.toJson());
      expect(copy.toJson(), m.toJson());
    }
  });

  test(
      'Valid interior projections remain available; too-short splits are not offered',
      () {
    final m = WallNetwork()
      ..addPolyline(const [DrawingPoint(0, 0), DrawingPoint(1000, 0)]);
    expect(m.snap(const DrawingPoint(500, 3), 16).x, 500);
    final outsideCornerRange = m.snap(const DrawingPoint(991, 1), 2);
    expect(outsideCornerRange.x, 991);
    expect(outsideCornerRange.y, 1);
  });
}
