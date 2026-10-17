import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_shapes.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_angles.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';

DrawingPoint p(double x, double y) => DrawingPoint(x, y);
void main() {
  test('Rough square is equal sided with exact right angles', () {
    final result = recognizeShape(
        [p(0, 0), p(2020, 15), p(2010, 1990), p(-10, 2005), p(0, 0)])!;
    expect(result.kind, ShapePreset.square);
    final lengths = [
      for (var i = 0; i < 4; i++)
        (result.points[i + 1] - result.points[i]).length
    ];
    for (final length in lengths) {
      expect(length, closeTo(lengths.first, .001));
    }
    expect(
        CornerAngle(result.points[1], result.points[0], result.points[2])
            .degrees,
        closeTo(90, .001));
  });
  test(
      'Rectangle preserves proportion and irregular/open strokes are not coerced',
      () {
    final result = recognizeShape(
        [p(0, 0), p(4010, 20), p(3990, 2010), p(10, 1990), p(0, 0)])!;
    expect(result.kind, ShapePreset.rectangle);
    expect(
        (result.points[1] - result.points[0]).length /
            (result.points[2] - result.points[1]).length,
        closeTo(2, .03));
    expect(
        recognizeShape(
            [p(0, 0), p(3000, 800), p(2000, 2400), p(400, 1700), p(0, 0)]),
        isNull);
    expect(recognizeShape([p(0, 0), p(2000, 0), p(2000, 2000), p(0, 2000)]),
        isNull);
  });
  test(
      'Triangles remain triangles; L recognition retains its re-entrant corner',
      () {
    expect(recognizeShape([p(0, 0), p(2000, 0), p(1000, 1400), p(0, 0)])!.kind,
        ShapePreset.triangle);
    final result = recognizeShape([
      p(0, 0),
      p(3000, 15),
      p(3010, 1000),
      p(1010, 1010),
      p(1000, 3000),
      p(-10, 3010),
      p(0, 0)
    ])!;
    expect(result.kind, ShapePreset.lShape);
    expect(result.points.length, 7);
  });
  test('Presets create real closed walls, rotate and reuse shared boundaries',
      () {
    for (final kind
        in ShapePreset.values.where((s) => s != ShapePreset.polygon)) {
      final spec = ShapeSpec(kind, 3000, 2000, 37);
      final points = spec.points(p(0, 0));
      final model = WallNetwork()..addPolyline(points);
      expect(model.walls.length, points.length - 1);
      expect(model.corners.length, points.length - 1);
      expect((points[1] - points[0]).length,
          closeTo(kind == ShapePreset.uShape ? 900 : 3000, .001));
    }
    final rooms = WallNetwork()
      ..addPolyline(
          const ShapeSpec(ShapePreset.square, 2000, 2000, 0).points(p(0, 0)));
    rooms.addPolyline(const ShapeSpec(ShapePreset.rectangle, 3000, 2000, 0)
        .points(p(2000, 0)));
    expect(rooms.walls.length, 7);
    expect(() => const ShapeSpec(ShapePreset.uShape, 10, 10, 0).points(p(0, 0)),
        throwsA(isA<DrawingConflict>()));
  });
  test('Units round-trip exact input and normalize feet/inches display carry',
      () {
    for (final unit in DrawingUnit.values) {
      expect(unit.readMm(unit.input(3500)), closeTo(3500, 1e-6));
    }
    expect(DrawingUnit.feetInches.format(3500), '11 ft 5.8 in');
    expect(
        DrawingUnit.feetInches.readMm('11 ft 5.8 in'), closeTo(3500.12, .001));
    expect(DrawingUnit.feetInches.readMm('11 12'), isNull);
    expect(DrawingUnit.feetInches.readMm('-1 5'), isNull);
    expect(DrawingUnit.feetInches.format(304.79), '1 ft 0 in');
    expect(DrawingUnit.inches.readMm('12'), closeTo(304.8, 1e-9));
  });
  test(
      'Included angles distinguish right, straight and diagonal from direction',
      () {
    expect(CornerAngle(p(0, 0), p(1000, 0), p(0, 1000)).degrees,
        closeTo(90, .001));
    expect(CornerAngle(p(0, 0), p(-1000, 0), p(1000, 0)).degrees,
        closeTo(180, .001));
    expect(CornerAngle(p(0, 0), p(1000, 0), p(1000, 1000)).radians,
        closeTo(math.pi / 4, .001));
    final m = WallNetwork()..addPolyline([p(0, 0), p(1000, 0), p(1000, 1000)]);
    expect(contextualAngles(m), isEmpty);
    expect(contextualAngles(m, wall: m.walls.keys.first).single.degrees,
        closeTo(90, .001));
  });
}
