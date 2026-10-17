import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_angles.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_guides.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_precision.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'drawing_screen_test.dart' as harness;
import 'shape_interaction_test.dart' as shapes;
import 'natural_drawing_test.dart' as natural;

DrawingPoint p(double x, double y) => DrawingPoint(x, y);
DrawingPoint at(double degrees, [double length = 1000]) => p(
    math.cos(degrees * math.pi / 180) * length,
    math.sin(degrees * math.pi / 180) * length);

void main() {
  test('Parallel and perpendicular snaps work against arbitrary diagonal walls',
      () {
    final m = WallNetwork()..addPolyline([p(0, 0), p(1000, 700)]);
    final anchor = p(3000, 4000), direction = p(1000, 700);
    for (final perpendicular in [false, true]) {
      final axis = perpendicular ? p(-700, 1000) : direction;
      final raw = anchor + axis + p(4, -3);
      final result = precisionPoint(m, raw,
          anchor: anchor,
          parallel: !perpendicular,
          perpendicular: perpendicular);
      expect(
          perpendicular
              ? (result - anchor).dot(direction).abs()
              : (result - anchor).cross(direction).abs(),
          lessThan(1e-6));
      expect(m.corners.length, 2);
      expect(m.walls.length, 1);
    }
  });
  test('Angle tolerance is configurable and spatial tolerance is also required',
      () {
    final m = WallNetwork(), raw = at(2);
    expect(
        precisionPoint(m, raw,
            anchor: p(0, 0), angleStep: 45, angleToleranceDegrees: 1),
        same(raw));
    final snapped = precisionPoint(m, raw,
        anchor: p(0, 0), angleStep: 45, angleToleranceDegrees: 3);
    expect(snapped.y, closeTo(0, 1e-8));
    expect(
        precisionPoint(m, raw,
            anchor: p(0, 0),
            angleStep: 45,
            angleToleranceDegrees: 3,
            tolerance: 5),
        same(raw));
    for (final invalid in [double.nan, double.infinity, -1.0, 46.0]) {
      expect(() => precisionPoint(m, raw, angleToleranceDegrees: invalid),
          throwsArgumentError);
    }
  });
  test('Free drawing preserves arbitrary directions with assistance disabled',
      () {
    final m = WallNetwork()..addPolyline([p(0, 0), p(1000, 0)]);
    for (final degrees in [0.0, 45.0, 90.0, 135.0, 180.0, 237.3, 359.9]) {
      final raw = at(degrees);
      expect(precisionPoint(m, raw, anchor: p(0, 0)), same(raw));
      expect(directionDegrees(p(0, 0), raw), closeTo(degrees, 1e-8));
    }
  });
  test('45 degree increments preserve reverse directions including 135 and 180',
      () {
    for (final degrees in [
      0.0,
      45.0,
      90.0,
      135.0,
      180.0,
      225.0,
      270.0,
      315.0
    ]) {
      final snapped = precisionPoint(WallNetwork(), at(degrees + 1),
          anchor: p(0, 0), angleStep: 45);
      expect(directionDegrees(p(0, 0), snapped), closeTo(degrees, 1e-8));
      expect(snapped.length, closeTo(1000, 1e-8));
    }
  });
  test(
      'Perpendicular guides detect a diagonal reference without making a junction',
      () {
    final m = WallNetwork()..addPolyline([p(0, 0), p(1000, 700)]);
    final guides = drawingGuides(m, p(2300, 5000), 20, anchor: p(3000, 4000));
    expect(guides.any((g) => g.kind == GuideKind.perpendicular), isTrue);
    expect(m.walls.length, 1);
    expect(m.corners.length, 2);
    expect(drawingGuides(m, p(2200, 5000), 20, anchor: p(3000, 4000)), isEmpty);
  });
  test(
      'Centerline and extension guides use infinite diagonal lines without connecting',
      () {
    final m = WallNetwork()..addPolyline([p(0, 0), p(1000, 700)]);
    expect(drawingGuides(m, p(500, 352), 10).single.kind, GuideKind.centerline);
    expect(
        drawingGuides(m, p(2000, 1402), 10).single.kind, GuideKind.extension);
    expect(m.corners.length, 2);
    expect(m.nearestCorner(p(2000, 1402), 10), isNull);
  });
  test('Competing parallel targets prefer nearest reference and remain stable',
      () {
    final m = WallNetwork()..addPolyline([p(0, 0), p(1000, 700)]);
    m.addPolyline([p(2000, 2000), p(3000, 2700)]);
    final guides = drawingGuides(m, p(3200, 2950), 20, anchor: p(2200, 2250));
    final parallel = guides.firstWhere((g) => g.kind == GuideKind.parallel);
    expect(parallel.key, 'p${m.walls.keys.last}');
    final next = drawingGuides(m, p(3200, 2951), 20,
        anchor: p(2200, 2250), previous: guides);
    expect(next.first.key, guides.first.key);
    expect(next.length, lessThanOrEqualTo(2));
  });
  test('Shared-corner and midpoint preview angles are distinct from direction',
      () {
    final m = WallNetwork()..addPolyline([p(0, 0), p(1000, 0)]);
    final corner = contextualAngles(m, preview: [p(1000, 0), p(1000, 1000)]);
    expect(corner.single.degrees, closeTo(90, 1e-8));
    expect(
        contextualAngles(m, preview: [p(1000, 0), p(2000, 0)]).single.degrees,
        closeTo(180, 1e-8));
    expect(
        contextualAngles(m, preview: [p(1000, 0), p(2000, 1000)])
            .single
            .degrees,
        closeTo(135, 1e-8));
    final midpoint = contextualAngles(m, preview: [p(500, 0), p(500, 1000)]);
    expect(midpoint.length, 2);
    expect(
        midpoint.every((angle) => (angle.degrees - 90).abs() < 1e-8), isTrue);
    expect(
        contextualAngles(m, preview: [p(2000, 1000), p(2000, 2000)]), isEmpty);
    expect(m.walls.length, 1);
  });
  test(
      'Alignment and angles are world-based across zoom-dependent touch tolerances',
      () {
    final m = WallNetwork()..addPolyline([p(0, 0), p(1000, 700)]);
    for (final zoom in [.005, .1, 2.0]) {
      final guides = drawingGuides(m, p(2000, 1400), 6 / zoom);
      expect(guides.any((g) => g.kind == GuideKind.extension), isTrue);
      expect(
          directionDegrees(p(0, 0), p(2000, 1400)), closeTo(34.9920202, 1e-6));
    }
  });
  testWidgets('Tolerance setting is editable and does not enable snapping',
      (t) async {
    await harness.open(t);
    await shapes.menu(t, 'Drawing assistance', 'Angle tolerance: 3.0°');
    await t.tap(find.text('1.0°'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Drawing assistance'));
    await t.pumpAndSettle();
    expect(find.text('Angle tolerance: 1.0°'), findsOneWidget);
    final item = t.widget<CheckedPopupMenuItem>(find.byWidgetPredicate(
        (w) => w is CheckedPopupMenuItem && w.value == 'parallel'));
    expect(item.checked, isFalse);
    expect(harness.painter(t).model.walls, isEmpty);
  });
  testWidgets(
      'Live perpendicular preview stays independent of its reference wall',
      (t) async {
    await harness.open(t);
    await natural.stroke(t, const [Offset(60, 60), Offset(200, 200)]);
    await t.tap(find.byTooltip('Drawing assistance'));
    await t.pumpAndSettle();
    final toggle = find.byWidgetPredicate(
        (w) => w is CheckedPopupMenuItem && w.value == 'parallel');
    await t.ensureVisible(toggle);
    await t.tap(toggle);
    await t.pumpAndSettle();
    final origin = t.getTopLeft(harness.canvas);
    final drag = await t.startGesture(origin + const Offset(60, 300));
    await drag.moveTo(origin + const Offset(160, 202));
    await t.pump();
    final view = harness.painter(t);
    expect(view.guides.any((g) => g.kind == GuideKind.perpendicular), isTrue);
    expect(directionDegrees(view.preview.first, view.preview.last),
        closeTo(315, 1e-6));
    expect(view.angles, isEmpty);
    expect(view.model.walls.length, 1);
    await drag.up();
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls.length, 2);
    expect(harness.painter(t).model.corners.length, 4);
    expect(harness.painter(t).guides, isEmpty);
  });
}
