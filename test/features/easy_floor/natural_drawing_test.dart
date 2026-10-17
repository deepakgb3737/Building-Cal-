import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'drawing_screen_test.dart' as harness;
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';

Future<void> stroke(WidgetTester tester, List<Offset> points,
    {bool hold = false, bool finish = true}) async {
  final origin = tester.getTopLeft(harness.canvas);
  final drag = await tester.startGesture(origin + points.first);
  if (hold) await tester.pump(const Duration(milliseconds: 500));
  for (final point in points.skip(1)) {
    await drag.moveTo(origin + point);
    await tester.pump();
  }
  await drag.up();
  await tester.pumpAndSettle();
  if (finish) await harness.keepSketch(tester);
}

void main() {
  const layouts = <String, List<Offset>>{
    'rectangle': [
      Offset(60, 60),
      Offset(260, 60),
      Offset(260, 220),
      Offset(60, 220),
      Offset(60, 60)
    ],
    'L outline': [
      Offset(60, 60),
      Offset(260, 60),
      Offset(260, 120),
      Offset(140, 120),
      Offset(140, 220),
      Offset(60, 220),
      Offset(60, 60)
    ],
    'U outline': [
      Offset(60, 60),
      Offset(120, 60),
      Offset(120, 160),
      Offset(200, 160),
      Offset(200, 60),
      Offset(260, 60),
      Offset(260, 220),
      Offset(60, 220),
      Offset(60, 60)
    ],
    'T outline': [
      Offset(60, 60),
      Offset(260, 60),
      Offset(260, 110),
      Offset(190, 110),
      Offset(190, 220),
      Offset(130, 220),
      Offset(130, 110),
      Offset(60, 110),
      Offset(60, 60)
    ],
    'angled outline': [
      Offset(60, 60),
      Offset(220, 80),
      Offset(260, 170),
      Offset(150, 220),
      Offset(60, 180),
      Offset(60, 60)
    ],
    'open near start': [
      Offset(60, 60),
      Offset(260, 60),
      Offset(260, 220),
      Offset(60, 220),
      Offset(60, 68)
    ],
    'narrow corridor': [
      Offset(60, 60),
      Offset(260, 60),
      Offset(260, 80),
      Offset(180, 80),
      Offset(180, 220),
      Offset(160, 220),
      Offset(160, 80),
      Offset(60, 80),
      Offset(60, 60)
    ],
  };
  for (final entry in layouts.entries) {
    testWidgets('Natural continuous ${entry.key} retains intended geometry',
        (tester) async {
      await harness.open(tester);
      await stroke(tester, entry.value);
      final model = harness.painter(tester).model;
      expect(model.walls.length, entry.value.length - 1);
      expect(
          model.corners.length,
          entry.key == 'open near start'
              ? entry.value.length
              : entry.value.length - 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'Several rooms share boundaries through sequential drawn partitions',
      (tester) async {
    await harness.open(tester);
    await harness.outline(tester);
    for (final x in [110.0, 160.0, 210.0]) {
      await stroke(tester, [Offset(x, 60), Offset(x, 220)], hold: true);
    }
    final model = harness.painter(tester).model;
    expect(model.walls.length, 13);
    expect(model.corners.length, 10);
    for (final x in [700.0, 1200.0, 1700.0]) {
      final junction = model.nearestCorner(DrawingPoint(x, 200), .001)!;
      expect(
          model.walls.values
              .where((w) => w.start == junction || w.end == junction)
              .length,
          3);
    }
  });
  testWidgets(
      'L layout supports an internal partition without altering its outer corners',
      (tester) async {
    await harness.open(tester);
    await stroke(tester, layouts['L outline']!);
    await stroke(tester, const [Offset(100, 60), Offset(100, 220)], hold: true);
    expect(harness.painter(tester).model.walls.length, 9);
    expect(harness.painter(tester).model.corners.length, 8);
  });
  testWidgets(
      'Hold then draw creates partitions and continues endpoints without tool changes',
      (tester) async {
    await harness.open(tester);
    await harness.outline(tester);
    await stroke(tester, const [Offset(160, 60), Offset(160, 220)], hold: true);
    expect(harness.painter(tester).model.walls.length, 7);
    expect(harness.painter(tester).model.corners.length, 6);
    await stroke(tester, const [Offset(260, 60), Offset(285, 30)], hold: true);
    expect(harness.painter(tester).model.walls.length, 8);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Connections remain automatic and match the drawing preview',
      (tester) async {
    await harness.open(tester);
    await harness.outline(tester);
    await tester.tap(find.byTooltip('Drawing assistance'));
    await tester.pumpAndSettle();
    expect(
        find.byWidgetPredicate(
            (w) => w is CheckedPopupMenuItem && w.value == 'snap'),
        findsNothing);
    await tester.tapAt(const Offset(5, 400));
    await tester.pumpAndSettle();
    final origin = tester.getTopLeft(harness.canvas);
    final drag = await tester.startGesture(origin + const Offset(180, 300));
    await drag.moveTo(origin + const Offset(180, 68));
    await tester.pump();
    final tip = harness.painter(tester).preview.last;
    await drag.up();
    await tester.pumpAndSettle();
    final model = harness.painter(tester).model;
    expect(model.nearestCorner(tip, .001), isNotNull);
    expect(tip.y, closeTo(200, .001));
    // Both the lower crossing and snapped upper endpoint become junctions.
    expect(model.walls.length, 8);
  });
  testWidgets('Long continuous stroke preserves many corners and supports undo',
      (tester) async {
    await harness.open(tester);
    final points = <Offset>[const Offset(60, 60)];
    for (var row = 0; row < 18; row++) {
      final y = 60.0 + row * 8;
      points.add(Offset(row.isEven ? 260 : 60, y));
      points.add(Offset(row.isEven ? 260 : 60, y + 8));
    }
    await stroke(tester, points);
    expect(harness.painter(tester).model.walls.length, 36);
    await tester.ensureVisible(find.byTooltip('Undo'));
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(harness.painter(tester).model.walls, isEmpty);
  });
  testWidgets('Cancelling active drawing discards the stroke', (tester) async {
    await harness.open(tester);
    final origin = tester.getTopLeft(harness.canvas);
    final drag = await tester.startGesture(origin + const Offset(60, 60));
    await drag.moveTo(origin + const Offset(260, 100));
    await tester.pump();
    await drag.cancel();
    await tester.pumpAndSettle();
    expect(harness.painter(tester).model.walls, isEmpty);
    expect(harness.painter(tester).preview, isEmpty);
  });
}
