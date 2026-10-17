import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/drawing_painter.dart';
import 'measurement_layout_test.dart' as layout;

void main() {
  test('A previously distant label returns beside its wall when space clears',
      () {
    final model = WallNetwork()
      ..addPolyline([const DrawingPoint(0, 0), const DrawingPoint(2000, 0)]);
    final id = model.walls.keys.single;
    final bounds = <int, Rect>{}, offsets = <int, double>{id: 120};
    final view = DrawingPainter(
        model: model,
        origin: const Offset(60, 200),
        scale: .1,
        unit: DrawingUnit.mm,
        preview: [],
        showAllMeasurements: true,
        labelBounds: bounds,
        labelOffsets: offsets);
    layout.paint(view);
    expect(
        (bounds[id]!.center - const Offset(160, 200)).distance, lessThan(40));
    expect((bounds[id]!.center.dy - 200).abs() - bounds[id]!.height / 2,
        closeTo(18, .01));
    final first = bounds[id];
    layout.paint(view);
    expect(bounds[id], first);
  });

  test('A blocked midpoint uses the clear opposite side before drifting along',
      () {
    final model = WallNetwork()
      ..addPolyline([const DrawingPoint(0, 0), const DrawingPoint(2000, 0)]);
    final id = model.walls.keys.single, bounds = <int, Rect>{};
    const obstacle = Rect.fromLTWH(130, 140, 60, 55);
    layout.paint(DrawingPainter(
        model: model,
        origin: const Offset(60, 200),
        scale: .1,
        unit: DrawingUnit.mm,
        preview: [],
        showAllMeasurements: true,
        labelBounds: bounds,
        labelObstacles: [obstacle]));
    expect(bounds[id]!.center.dx, closeTo(160, .01));
    expect(bounds[id]!.top, greaterThan(200));
    expect(
        bounds[id]!.center.dy - 200 - bounds[id]!.height / 2, closeTo(18, .01));
    expect(bounds[id]!.overlaps(obstacle), isFalse);
  });

  for (final end in [
    const DrawingPoint(0, 2000),
    const DrawingPoint(1600, 1200)
  ]) {
    for (final scale in [.05, .1, .2]) {
      test('Direction-aware clearance stays near $end at zoom $scale', () {
        final model = WallNetwork()
          ..addPolyline([const DrawingPoint(0, 0), end]);
        final id = model.walls.keys.single, bounds = <int, Rect>{};
        final before = model.toJson();
        final view = DrawingPainter(
            model: model,
            origin: const Offset(120, 70),
            scale: scale,
            unit: DrawingUnit.feetInches,
            preview: [],
            showAllMeasurements: true,
            labelBounds: bounds);
        layout.paint(view, const Size(600, 600));
        final a = view.screen(const DrawingPoint(0, 0)), b = view.screen(end);
        final rect = bounds[id]!;
        final normal = Offset((b - a).dy, -(b - a).dx) / (b - a).distance;
        final clearance = normal.dx.abs() * rect.width / 2 +
            normal.dy.abs() * rect.height / 2 +
            16 * (normal.dx.abs() + normal.dy.abs()) +
            2;
        expect((rect.center - (a + b) / 2).distance,
            inInclusiveRange(clearance - .01, clearance + 4));
        for (final corner in [a, b]) {
          expect(rect.overlaps(Rect.fromCircle(center: corner, radius: 8)),
              isFalse);
        }
        for (var i = 0; i <= 100; i++) {
          expect(rect.contains(a + (b - a) * (i / 100)), isFalse);
        }
        expect(model.toJson(), before);
      });
    }
  }

  test('Crowded fallback chooses the nearest available region, not top left',
      () {
    final model = WallNetwork()
      ..addPolyline([const DrawingPoint(0, 0), const DrawingPoint(100, 0)]);
    final bounds = <int, Rect>{};
    layout.paint(DrawingPainter(
        model: model,
        origin: const Offset(150, 260),
        scale: .1,
        unit: DrawingUnit.mm,
        preview: [],
        showAllMeasurements: true,
        labelBounds: bounds,
        labelObstacles: [const Rect.fromLTWH(0, 120, 320, 280)]));
    expect(bounds.length, 1);
    expect(bounds.values.single.bottom, lessThan(120));
    expect(bounds.values.single.bottom, greaterThan(70));
    expect((bounds.values.single.center.dx - 155).abs(), lessThan(35));
  });
}
