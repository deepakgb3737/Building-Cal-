import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/drawing_painter.dart';
import 'drawing_screen_test.dart' as harness;
import 'package:grid_ceiling_calculator/features/easy_floor/ui/easy_floor_screen.dart';

void main() {
  testWidgets(
      'Visible label control shows all walls and hides selected-wall labels without editing geometry',
      (tester) async {
    await harness.open(tester);
    await harness.outline(tester);
    final before = harness.painter(tester).model.copy();
    expect(harness.painter(tester).measuredWalls, before.walls.keys.toSet());
    expect(find.byTooltip('Hide labels'), findsOneWidget);
    final view = harness.painter(tester), wall = before.walls.values.first;
    final at = tester.getTopLeft(harness.canvas) +
        (view.screen(before.corners[wall.start]!) +
                view.screen(before.corners[wall.end]!)) /
            2;
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    expect(harness.painter(tester).selectedWall, wall.id);
    await tester.ensureVisible(find.byTooltip('Hide labels'));
    await tester.tap(find.byTooltip('Hide labels'));
    await tester.pumpAndSettle();
    expect(harness.painter(tester).measuredWalls, isEmpty);
    expect(harness.painter(tester).labelBounds, isEmpty);
    expect(harness.painter(tester).model.corners, before.corners);
    expect(harness.painter(tester).model.walls, before.walls);
    await tester.ensureVisible(find.byTooltip('Undo'));
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(harness.painter(tester).model.walls, isEmpty);
  });
  testWidgets(
      'Labels has one visibility control without a duplicate menu option',
      (tester) async {
    await harness.open(tester);
    await harness.outline(tester);
    final before = harness.painter(tester).model.toJson();
    await tester.tap(find.byTooltip('Hide labels'));
    await tester.pumpAndSettle();
    expect(harness.painter(tester).measuredWalls, isEmpty);
    await tester.tap(find.byTooltip('Drawing assistance'));
    await tester.pumpAndSettle();
    final item = find.byWidgetPredicate(
        (w) => w is CheckedPopupMenuItem && w.value == 'measurements');
    expect(item, findsNothing);
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show labels'), findsOneWidget);
    expect(harness.painter(tester).measuredWalls, isEmpty);
    await tester.tap(find.byTooltip('Show labels'));
    await tester.pumpAndSettle();
    expect(harness.painter(tester).measuredWalls.length, 4);
    expect(harness.painter(tester).model.toJson(), before);
  });
  testWidgets(
      'All-wall measurements remain available during two-finger navigation',
      (tester) async {
    await harness.open(tester);
    await harness.outline(tester);
    expect(harness.painter(tester).measuredWalls.length, 4);
    final origin = tester.getTopLeft(harness.canvas);
    final a =
        await tester.startGesture(origin + const Offset(100, 140), pointer: 1);
    final b =
        await tester.startGesture(origin + const Offset(200, 140), pointer: 2);
    await a.moveTo(origin + const Offset(70, 140));
    await b.moveTo(origin + const Offset(230, 140));
    await tester.pump();
    expect(harness.painter(tester).measuredWalls.length, 4);
    expect(harness.painter(tester).guides, isEmpty);
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(harness.painter(tester).measuredWalls.length, 4);
  });
  testWidgets('Guide opacity is configurable independently of geometry',
      (tester) async {
    await harness.open(tester);
    await tester.pumpWidget(
        const MaterialApp(home: EasyFloorScreen(guideOpacity: .25)));
    await tester.pumpAndSettle();
    expect(harness.painter(tester).guideOpacity, .25);
    expect(harness.painter(tester).model.walls, isEmpty);
  });

  testWidgets(
      'Measurements follow drawing, wall drag, corner drag, and cancellation',
      (tester) async {
    await harness.open(tester);
    await harness.outline(tester);
    await tester.ensureVisible(find.byTooltip('Hide labels'));
    await tester.tap(find.byTooltip('Hide labels'));
    await tester.pumpAndSettle();
    var view = harness.painter(tester);
    expect(view.measuredWalls, isEmpty);
    expect(view.labelBounds, isEmpty);
    final wall = view.model.walls.values.first;
    final origin = tester.getTopLeft(harness.canvas);
    final middle = origin +
        (view.screen(view.model.corners[wall.start]!) +
                view.screen(view.model.corners[wall.end]!)) /
            2;
    var drag = await tester.startGesture(middle);
    await drag.moveTo(middle + const Offset(0, 30));
    await tester.pump();
    view = harness.painter(tester);
    expect(view.measuredWalls, {
      wall.id,
      for (final w in view.model.walls.values)
        if (w.start == wall.start ||
            w.end == wall.start ||
            w.start == wall.end ||
            w.end == wall.end)
          w.id
    });
    expect(view.moveOffset, closeTo(300, .001));
    await drag.cancel();
    await tester.pumpAndSettle();
    expect(harness.painter(tester).guides, isEmpty);
    view = harness.painter(tester);
    final corner = view.model.corners[wall.start]!;
    final at = origin + view.screen(corner);
    drag = await tester.startGesture(at);
    await drag.moveTo(at + const Offset(30, 25));
    await tester.pump();
    view = harness.painter(tester);
    final attached = view.model.walls.values
        .where((w) => w.start == wall.start || w.end == wall.start)
        .map((w) => w.id)
        .toSet();
    expect(view.measuredWalls, attached);
    await drag.up();
    await tester.pumpAndSettle();
    await harness.collapseTools(tester);
    drag = await tester.startGesture(origin + const Offset(200, 300));
    await drag.moveTo(origin + const Offset(80, 280));
    await tester.pump();
    expect(harness.painter(tester).preview.length, greaterThan(1));
    expect(harness.painter(tester).measuredWalls, isEmpty);
    await drag.cancel();
    await tester.pumpAndSettle();
    expect(harness.painter(tester).guides, isEmpty);
    expect(harness.painter(tester).preview, isEmpty);
  });
  testWidgets('Guides appear during relevant drawing and disappear on release',
      (tester) async {
    await harness.open(tester);
    await harness.outline(tester);
    final origin = tester.getTopLeft(harness.canvas);
    final drag = await tester.startGesture(origin + const Offset(280, 300));
    await drag.moveTo(origin + const Offset(290, 62));
    await tester.pump();
    final view = harness.painter(tester);
    expect(view.guides, isNotEmpty);
    expect(view.guideOpacity, .5);
    expect(view.guides.length, lessThanOrEqualTo(2));
    await drag.up();
    await tester.pumpAndSettle();
    expect(harness.painter(tester).guides, isEmpty);
    expect(harness.painter(tester).labelBounds, isNotEmpty);
  });
  test(
      'Context labels avoid each other, finger and target; offsets stay stable',
      () {
    final model = WallNetwork()
      ..addPolyline([
        const DrawingPoint(0, 0),
        const DrawingPoint(2000, 0),
        const DrawingPoint(2000, 1000),
        const DrawingPoint(0, 1000),
        const DrawingPoint(0, 0)
      ]);
    final bounds = <int, Rect>{}, offsets = <int, double>{};
    final painter = DrawingPainter(
        model: model,
        origin: const Offset(80, 100),
        scale: .1,
        unit: DrawingUnit.mm,
        preview: [],
        showAllMeasurements: true,
        labelBounds: bounds,
        labelOffsets: offsets,
        finger: const Offset(180, 82));
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Size(400, 400));
    recorder.endRecording().dispose();
    expect(bounds.length, greaterThanOrEqualTo(2));
    final rects = bounds.values.toList();
    for (var i = 0; i < rects.length; i++) {
      expect(
          rects[i].overlaps(
              Rect.fromCircle(center: const Offset(180, 82), radius: 28)),
          isFalse);
      for (var j = i + 1; j < rects.length; j++) {
        expect(rects[i].overlaps(rects[j]), isFalse);
      }
    }
    final before = Map.of(offsets);
    final second = ui.PictureRecorder();
    painter.paint(Canvas(second), const Size(400, 400));
    second.endRecording().dispose();
    expect(offsets, before);
  });
}
