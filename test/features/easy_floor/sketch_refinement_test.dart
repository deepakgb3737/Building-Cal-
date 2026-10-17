import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_shapes.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/sketch_refinement.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';

void main() {
  test(
      'Removing residual jitter does not flatten an intentional curved outline',
      () {
    final input = [
      for (var i = 0; i <= 300; i++)
        DrawingPoint(i * 10, 400 * math.sin(i * math.pi / 300))
    ];
    final result =
        SketchRefinement.fromStroke(input, tolerance: 30, recognize: false);
    for (final sample in input) {
      final error = List.generate(
          result.refined.length - 1,
          (i) => (sample -
                  projectToSegment(
                      sample, result.refined[i], result.refined[i + 1]))
              .length).reduce(math.min);
      expect(error, lessThanOrEqualTo(30.001));
    }
  });
  test('Long dense jitter reduces to a valid wall with bounded vertex count',
      () {
    final input = [
      for (var i = 0; i < 12000; i++) DrawingPoint(i * 4, math.sin(i * .7) * 6)
    ];
    final times = <int>[];
    for (var repeat = 0; repeat < 5; repeat++) {
      final watch = Stopwatch()..start();
      final result = SketchRefinement.fromStroke(input, tolerance: 30);
      times.add(watch.elapsedMicroseconds);
      expect(result.refined.length, 2);
      expect((WallNetwork()..addPolyline(result.refined)).walls.length, 1);
      expect(input.length, 12000);
    }
    times.sort();
    // Desktop debug timing is diagnostic, not a phone frame-rate guarantee.
    debugPrint('FREEHAND samples=12000 median_us=${times[2]}');
  });
  test('Refinement respects existing walls without modifying their geometry',
      () {
    final base = WallNetwork()
      ..addPolyline(
          [const DrawingPoint(150, -50), const DrawingPoint(150, 350)]);
    final before = base.toJson();
    final input = [
      const DrawingPoint(18, 192),
      const DrawingPoint(46, 174),
      const DrawingPoint(236, 38),
      const DrawingPoint(196, 125),
      const DrawingPoint(265, 204),
      const DrawingPoint(5, 196),
      const DrawingPoint(29, 141),
      const DrawingPoint(283, 32)
    ];
    final original = base.copy()..addPolyline(input);
    final result = SketchRefinement.fromStroke(input,
        tolerance: 30, recognize: false, existing: base);
    final refined = base.copy()..addPolyline(result.refined);
    expect(refined.walls.length, original.walls.length);
    expect(result.refined, result.original);
    expect(base.toJson(), before);
  });
  test('Reduction cannot introduce a sub-minimum segment at an intersection',
      () {
    final input = [
      const DrawingPoint(269, 296),
      const DrawingPoint(18, 48),
      const DrawingPoint(158, 22),
      const DrawingPoint(206, 177),
      const DrawingPoint(263, 188),
      const DrawingPoint(173, 156),
      const DrawingPoint(140, 149),
      const DrawingPoint(205, 51),
    ];
    final original = WallNetwork()..addPolyline(input);
    final result =
        SketchRefinement.fromStroke(input, tolerance: 30, recognize: false);
    final refined = WallNetwork()..addPolyline(result.refined);
    expect(refined.walls.length, original.walls.length);
    expect(result.refined, result.original);
    expect(result.shape, isNull);
    expect(input.length, 8);
  });
  test('Dense straight-wall jitter becomes two points without altering input',
      () {
    final input = [
      for (var i = 0; i <= 1000; i++) DrawingPoint(i * 4, math.sin(i * .7) * 6)
    ];
    final raw = List.of(input);
    final result = SketchRefinement.fromStroke(input, tolerance: 30);
    expect(input, raw);
    expect(result.refined.length, 2);
    expect(result.original.length, greaterThan(2));
    expect(result.refined.first, input.first);
    expect(result.refined.last, input.last);
    final model = WallNetwork()..addPolyline(result.refined);
    expect(model.walls.length, 1);
  });
  for (final kind in [
    ShapePreset.square,
    ShapePreset.rectangle,
    ShapePreset.lShape,
    ShapePreset.uShape,
    ShapePreset.tShape
  ]) {
    test('${kind.label} refinement retains its topology and proportions', () {
      final base =
          ShapeSpec(kind, 4000, 3200, 0).points(const DrawingPoint(0, 0));
      final raw = [
        for (var i = 0; i < base.length - 1; i++)
          base[i] + DrawingPoint(i.isEven ? 6 : -6, i % 3 == 0 ? 5 : -5)
      ];
      raw.add(raw.first);
      final result = SketchRefinement.fromStroke(raw, tolerance: 30);
      expect(result.shape, kind);
      expect(result.refined.length, base.length);
      final model = WallNetwork()..addPolyline(result.refined);
      expect(model.walls.length, base.length - 1);
      expect(model.corners.length, base.length - 1);
    });
  }
  test('Open irregular outlines stay open and retain meaningful corners', () {
    final input = [
      const DrawingPoint(0, 0),
      const DrawingPoint(2000, 330),
      const DrawingPoint(1700, 1900),
      const DrawingPoint(90, 2100),
      const DrawingPoint(0, 90)
    ];
    final result = SketchRefinement.fromStroke(input, tolerance: 30);
    expect(result.shape, isNull);
    expect(result.refined.length, input.length);
    expect((result.refined.first - result.refined.last).length, 90);
    expect(result.refined.last, input.last);
  });
  test('Intentional curves remain polylines, not a single wall or rectangle',
      () {
    final input = [
      for (var i = 0; i <= 100; i++)
        DrawingPoint(1000 * math.cos(i * math.pi / 100),
            1000 * math.sin(i * math.pi / 100))
    ];
    final result = SketchRefinement.fromStroke(input, tolerance: 25);
    expect(result.shape, isNull);
    expect(result.refined.length, inInclusiveRange(8, 30));
    for (final point in input) {
      final distance = List.generate(
          result.refined.length - 1,
          (i) => (point -
                  projectToSegment(
                      point, result.refined[i], result.refined[i + 1]))
              .length).reduce(math.min);
      expect(distance, lessThanOrEqualTo(25.00001));
    }
  });
  test('Duplicate samples and tiny jitter do not make tiny wall segments', () {
    final result = SketchRefinement.fromStroke([
      for (var i = 0; i < 100; i++) const DrawingPoint(0, 0),
      const DrawingPoint(3, 1),
      const DrawingPoint(1000, 0),
      const DrawingPoint(1001, 0)
    ], tolerance: 30);
    expect(result.refined.length, 2);
    expect(result.refined.last.x, 1001);
    expect(
        SketchRefinement.fromStroke(
                [const DrawingPoint(0, 0), const DrawingPoint(2, 1)],
                tolerance: 30)
            .refined
            .length,
        1);
  });
  test('Recognition can be disabled without disabling point reduction', () {
    final input = [
      const DrawingPoint(0, 0),
      const DrawingPoint(2000, 10),
      const DrawingPoint(1990, 2000),
      const DrawingPoint(0, 1990),
      const DrawingPoint(0, 0)
    ];
    final result =
        SketchRefinement.fromStroke(input, tolerance: 30, recognize: false);
    expect(result.shape, isNull);
    expect(result.refined[1].y, 10);
  });
  test('Invalid points and tolerances are rejected', () {
    expect(
        () => SketchRefinement.fromStroke([const DrawingPoint(double.nan, 0)],
            tolerance: 30),
        throwsArgumentError);
    expect(() => SketchRefinement.fromStroke([], tolerance: 0),
        throwsArgumentError);
  });
}
