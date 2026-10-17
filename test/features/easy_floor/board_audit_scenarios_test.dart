import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/drawing_painter.dart';
import 'drawing_screen_test.dart' as harness;
import 'natural_drawing_test.dart' as natural;
import 'shape_interaction_test.dart' as shapes;

class LabelCounter implements Canvas {
  int labels = 0;
  @override
  dynamic noSuchMethod(Invocation call) {
    if (call.memberName == #drawParagraph) labels++;
    return null;
  }
}

void main() {
  test('Live wall dimension remains visible on a narrow mobile canvas', () {
    final canvas = LabelCounter();
    DrawingPainter(
            model: WallNetwork(),
            origin: const Offset(40, 40),
            scale: .1,
            unit: DrawingUnit.metres,
            preview: const [DrawingPoint(100, 100), DrawingPoint(1600, 100)])
        .paint(canvas, const Size(320, 500));
    expect(canvas.labels, 1);
  });
  test('Navigation does not paint transient preview measurements', () {
    final canvas = LabelCounter();
    DrawingPainter(
            model: WallNetwork(),
            origin: const Offset(40, 40),
            scale: .1,
            unit: DrawingUnit.metres,
            preview: const [DrawingPoint(100, 100), DrawingPoint(6000, 100)],
            navigationActive: true)
        .paint(canvas, const Size(1200, 800));
    expect(canvas.labels, 0);
  });
  testWidgets(
      'Rough continuous rectangle removes jitter and preserves proportions',
      (t) async {
    await harness.open(t);
    await natural.stroke(
        t,
        const [
          Offset(45, 60),
          Offset(100, 62),
          Offset(170, 59),
          Offset(270, 62),
          Offset(272, 95),
          Offset(269, 140),
          Offset(270, 180),
          Offset(190, 182),
          Offset(110, 179),
          Offset(45, 180),
          Offset(43, 120),
          Offset(45, 60)
        ],
        finish: false);
    await t.ensureVisible(find.text('Yes, Straighten'));
    await t.tap(find.text('Yes, Straighten'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Accept refinement'));
    await t.tap(find.text('Accept refinement'));
    await t.pumpAndSettle();
    final m = harness.painter(t).model,
        ids = harness.painter(t).model.walls.keys.toList();
    expect(m.walls.length, 4);
    expect(m.corners.length, 4);
    expect(m.length(ids[0]) / m.length(ids[1]), closeTo(1.875, .08));
  });
  testWidgets(
      'Shared room wall moves without detaching junctions or moving independent geometry',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    await natural.stroke(t, const [Offset(160, 60), Offset(160, 220)],
        hold: true);
    await natural.stroke(t, const [Offset(280, 300), Offset(60, 320)]);
    final origin = t.getTopLeft(harness.canvas), m = harness.painter(t).model;
    final far = m.walls.values.last,
        old = m.corners[m.walls.values.last.start]!;
    final partition = m.nearestWall(const DrawingPoint(1200, 1000), 1)!;
    final start = m.walls[partition]!.start;
    final drag = await t.startGesture(origin + const Offset(160, 140));
    await drag.moveTo(origin + const Offset(185, 140));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    final after = harness.painter(t).model;
    expect(after.length(partition), 1600);
    expect(
        after.walls.values
            .where((w) => w.start == start || w.end == start)
            .length,
        3);
    expect(after.corners[far.start], same(old));
    expect(after.walls.length, 8);
  });
  testWidgets(
      'Repeated real corner drags preserve attachments and return to original position',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    final id = harness.painter(t).model.corners.keys.first;
    final original = harness.painter(t).model.corners[id]!;
    for (var i = 0; i < 10; i++) {
      final v = harness.painter(t),
          at = t.getTopLeft(harness.canvas) +
              harness.painter(t).screen(harness.painter(t).model.corners[id]!);
      final delta = i.isEven ? const Offset(25, 20) : const Offset(-25, -20);
      final drag = await t.startGesture(at);
      await drag.moveTo(at + delta);
      await t.pump();
      await drag.up();
      await t.pumpAndSettle();
      expect(harness.painter(t).model.walls.length, 4);
      expect(harness.painter(t).model.corners.length, v.model.corners.length);
    }
    expect(harness.painter(t).model.corners[id]!.x, original.x);
    expect(harness.painter(t).model.corners[id]!.y, original.y);
  });
  testWidgets(
      'Changing from drawing to a pinch cancels the stroke without adding walls',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    final count = harness.painter(t).model.walls.length,
        origin = t.getTopLeft(harness.canvas);
    final a = await t.startGesture(origin + const Offset(100, 300), pointer: 1);
    await a.moveTo(origin + const Offset(140, 320));
    await t.pump();
    final b = await t.startGesture(origin + const Offset(220, 300), pointer: 2);
    await a.moveTo(origin + const Offset(70, 320));
    await b.moveTo(origin + const Offset(250, 300));
    await t.pump();
    await a.up();
    await b.up();
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls.length, count);
    expect(harness.painter(t).preview, isEmpty);
  });
  testWidgets('Pinching during a preset resize restores the pre-drag draft',
      (t) async {
    await harness.open(t);
    await shapes.menu(t, 'Shape presets', 'Rectangle');
    await t.tap(find.text('Preview'));
    await t.pumpAndSettle();
    final before = harness.painter(t).preview,
        origin = t.getTopLeft(harness.canvas);
    final a = await t.startGesture(origin + const Offset(60, 60), pointer: 1);
    await a.moveTo(origin + const Offset(230, 160));
    await t.pump();
    final b = await t.startGesture(origin + const Offset(280, 160), pointer: 2);
    await a.moveTo(origin + const Offset(200, 160));
    await b.moveTo(origin + const Offset(300, 160));
    await t.pump();
    await a.up();
    await b.up();
    await t.pumpAndSettle();
    final after = harness.painter(t).preview;
    expect(after.length, before.length);
    for (var i = 0; i < before.length; i++) {
      expect(after[i].x, before[i].x);
      expect(after[i].y, before[i].y);
    }
  });
  test(
      'Junction merging handles negative coordinates and neighbouring spatial buckets',
      () {
    final m = WallNetwork()
      ..addPolyline(const [DrawingPoint(-1000, 0), DrawingPoint(-.0011, 0)]);
    m.addPolyline(const [DrawingPoint(0, -1000), DrawingPoint(0, 100)]);
    final endpoint = m.nearestCorner(const DrawingPoint(-.0011, 0), .01)!;
    m.moveCorners({endpoint: const DrawingPoint(0, -.0005)}, join: true);
    final junction = m.nearestCorner(const DrawingPoint(0, 0), .01)!;
    expect(
        m.walls.values
            .where((w) => w.start == junction || w.end == junction)
            .length,
        3);
    expect(m.walls.length, 3);
  });
}
