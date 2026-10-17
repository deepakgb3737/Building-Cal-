import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_shapes.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';

const origin = DrawingPoint(0, 0);
const customPresets = [
  ShapeSpec(ShapePreset.square, 3700, 3700, 0),
  ShapeSpec(ShapePreset.rectangle, 5200, 3700, 0),
  ShapeSpec(ShapePreset.triangle, 3000, 4000, 0),
  ShapeSpec(ShapePreset.lShape, 5200, 3700, 0, details: {
    ShapeDimension.verticalArm: 1100,
    ShapeDimension.horizontalArm: 900,
  }),
  ShapeSpec(ShapePreset.uShape, 5200, 3700, 0, details: {
    ShapeDimension.leftArm: 1000,
    ShapeDimension.rightArm: 1300,
    ShapeDimension.base: 850,
  }),
  ShapeSpec(ShapePreset.tShape, 5200, 3700, 0, details: {
    ShapeDimension.topBar: 950,
    ShapeDimension.stem: 1400,
  }),
];

void main() {
  test('Custom dimensions generate the requested L, U, T and triangle edges',
      () {
    final l = customPresets[3].points(origin);
    expect(l.map((p) => (p.x, p.y)), [
      (0, 0),
      (5200, 0),
      (5200, 900),
      (1100, 900),
      (1100, 3700),
      (0, 3700),
      (0, 0),
    ]);
    final u = customPresets[4].points(origin);
    expect(u[1].x, closeTo(1000, 1e-8));
    expect(u[2].y, closeTo(2850, 1e-8));
    expect(u[3].x, closeTo(3900, 1e-8));
    final t = customPresets[5].points(origin);
    expect(t[2].y, closeTo(950, 1e-8));
    expect(t[3].x, closeTo(3300, 1e-8));
    expect(t[5].x, closeTo(1900, 1e-8));
    final triangle = customPresets[2].points(origin);
    expect((triangle[2] - triangle[1]).length, 5000);
  });

  for (final spec in customPresets) {
    test(
        '${spec.kind.label}: diagram spans, connected placement, translation and resize',
        () {
      final points = spec.points(origin);
      final model = WallNetwork()..addPolyline(points);
      expect(model.walls.length, points.length - 1);
      expect(model.corners.length, points.length - 1);
      final lengths = {for (final w in model.walls.keys) w: model.length(w)};
      final corners = Map.of(model.corners);
      model.moveRoom(model.walls.keys.toSet(), const DrawingPoint(425, -280));
      for (final entry in corners.entries) {
        expect(model.corners[entry.key]!.x, closeTo(entry.value.x + 425, 1e-7));
        expect(model.corners[entry.key]!.y, closeTo(entry.value.y - 280, 1e-7));
      }
      for (final entry in lengths.entries) {
        expect(model.length(entry.key), closeTo(entry.value, 1e-7));
      }
      final resized = spec.resized(spec.width * 1.5, spec.height * 2);
      final next = resized.points(origin);
      for (var i = 0; i < points.length; i++) {
        expect(next[i].x, closeTo(points[i].x * 1.5, 1e-7));
        expect(
            next[i].y,
            closeTo(points[i].y * (spec.kind == ShapePreset.square ? 1.5 : 2),
                1e-7));
      }
      for (final m in spec.measurements) {
        expect(m.value, greaterThanOrEqualTo(10));
        if (m.id != ShapeDimension.width && m.id != ShapeDimension.height) {
          expect(
              List.generate(
                  points.length - 1,
                  (i) =>
                      (projectToSegment(m.start, points[i], points[i + 1]) -
                                  m.start)
                              .length <
                          1e-7 &&
                      (projectToSegment(m.end, points[i], points[i + 1]) -
                                  m.end)
                              .length <
                          1e-7).any((v) => v),
              isTrue);
        }
      }
    });
  }

  test('Rotation preserves custom dimensions and connected edges', () {
    final spec = customPresets[4];
    final rotated = ShapeSpec(spec.kind, spec.width, spec.height, 37,
        details: spec.details);
    final a = spec.points(origin),
        b = rotated.points(const DrawingPoint(100, 250));
    for (var i = 1; i < a.length; i++) {
      expect((a[i] - a[i - 1]).length, closeTo((b[i] - b[i - 1]).length, 1e-7));
    }
    expect((b[1] - b[0]).y, closeTo(1000 * math.sin(37 * math.pi / 180), 1e-7));
  });

  test(
      'Impossible arms, negative input, nonfinite sizes and tiny remainders are rejected',
      () {
    for (final spec in [
      const ShapeSpec(ShapePreset.lShape, 2000, 1500, 0,
          details: {ShapeDimension.verticalArm: 2000}),
      const ShapeSpec(ShapePreset.lShape, 2000, 1500, 0,
          details: {ShapeDimension.horizontalArm: 1495}),
      const ShapeSpec(ShapePreset.uShape, 2000, 1500, 0, details: {
        ShapeDimension.leftArm: 1200,
        ShapeDimension.rightArm: 900
      }),
      const ShapeSpec(ShapePreset.uShape, 2000, 1500, 0,
          details: {ShapeDimension.base: 1500}),
      const ShapeSpec(ShapePreset.tShape, 2000, 1500, 0,
          details: {ShapeDimension.stem: 1990}),
      const ShapeSpec(ShapePreset.tShape, 2000, 1500, 0,
          details: {ShapeDimension.topBar: -50}),
      const ShapeSpec(ShapePreset.lShape, 2000, 1500, 0,
          details: {ShapeDimension.verticalArm: double.nan}),
    ]) {
      expect(() => spec.points(origin), throwsA(isA<DrawingConflict>()));
    }
  });
}
