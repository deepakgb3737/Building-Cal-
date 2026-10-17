import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_angles.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_precision.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'drawing_screen_test.dart' as harness;

void main() {
  test('Already aligned points are not reconstructed with trigonometric drift',
      () {
    const anchor = DrawingPoint(200, 200);
    for (final point in [
      const DrawingPoint(200, 1700),
      const DrawingPoint(200, -1700),
      const DrawingPoint(1700, 200),
      const DrawingPoint(-1700, 200)
    ]) {
      expect(precisionPoint(WallNetwork(), point, anchor: anchor, axes: true),
          same(point));
    }
  });
  for (final degrees in [0.0, 90.0, 180.0, 270.0, 37.0, 135.0]) {
    testWidgets(
        'Default assistance helps $degrees degrees without forcing diagonals',
        (t) async {
      await harness.open(t);
      final origin = t.getTopLeft(harness.canvas),
          start = origin + const Offset(160, 200);
      final rawDegrees = degrees % 90 == 0 ? degrees + 2 : degrees;
      final radians = rawDegrees * math.pi / 180;
      final end = start + Offset(math.cos(radians), math.sin(radians)) * 100;
      final drag = await t.startGesture(start);
      await drag.moveTo(end);
      await t.pump();
      final live = harness.painter(t).preview;
      expect(directionDegrees(live.first, live.last), closeTo(degrees, 1e-8));
      if (degrees % 90 == 0) expect(harness.painter(t).guides, isNotEmpty);
      await drag.up();
      await t.pumpAndSettle();
      final model = harness.painter(t).model,
          wall = harness.painter(t).model.walls.values.single;
      expect(
          directionDegrees(
              model.corners[wall.start]!, model.corners[wall.end]!),
          closeTo(degrees, 1e-8));
      expect(model.length(wall.id), closeTo(1000, 1e-7));
    });
  }
  testWidgets(
      'Cardinal assistance can be disabled for near-horizontal free angles',
      (t) async {
    await harness.open(t);
    await t.tap(find.byTooltip('Drawing assistance'));
    await t.pumpAndSettle();
    final toggle = find.byWidgetPredicate(
        (w) => w is CheckedPopupMenuItem && w.value == 'align');
    expect(t.widget<CheckedPopupMenuItem>(toggle).checked, isTrue);
    await t.ensureVisible(toggle);
    await t.tap(toggle);
    await t.pumpAndSettle();
    final origin = t.getTopLeft(harness.canvas);
    final drag = await t.startGesture(origin + const Offset(60, 100));
    await drag.moveTo(origin + const Offset(260, 105));
    await t.pump();
    final live = harness.painter(t).preview;
    expect(directionDegrees(live.first, live.last),
        closeTo(math.atan2(5, 200) * 180 / math.pi, 1e-8));
    await drag.cancel();
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls, isEmpty);
  });
}
