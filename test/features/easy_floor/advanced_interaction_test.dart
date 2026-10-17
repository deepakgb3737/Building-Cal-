import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'drawing_screen_test.dart' as harness;
import 'natural_drawing_test.dart' as natural;

Future<void> menu(WidgetTester t, String tooltip, String label) async {
  if (tooltip == 'More drawing tools' || tooltip == 'Drawing assistance') {
    await harness.expandTools(t);
    await t.ensureVisible(find.byTooltip(tooltip));
  }
  await t.tap(find.byTooltip(tooltip));
  await t.pumpAndSettle();
  await t.ensureVisible(find.text(label));
  await t.tap(find.text(label));
  await t.pumpAndSettle();
}

Future<void> selectWall(WidgetTester t, int id) async {
  final v = harness.painter(t), w = harness.painter(t).model.walls[id]!;
  await t.tapAt(t.getTopLeft(harness.canvas) +
      (v.screen(v.model.corners[w.start]!) +
              v.screen(v.model.corners[w.end]!)) /
          2);
  await t.pumpAndSettle();
}

Offset midpoint(WidgetTester t, int id) {
  final v = harness.painter(t), w = harness.painter(t).model.walls[id]!;
  return t.getTopLeft(harness.canvas) +
      (v.screen(v.model.corners[w.start]!) +
              v.screen(v.model.corners[w.end]!)) /
          2;
}

String geometry(WidgetTester t) => harness
    .painter(t)
    .model
    .corners
    .entries
    .map((e) => '${e.key}:${e.value.x},${e.value.y}')
    .join(';');
Future<void> action(WidgetTester t, String label) async {
  await t.ensureVisible(find.text(label));
  await t.tap(find.text(label));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
      'Dragging a dimension label selects its wall without translating or drawing',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    final id = harness.painter(t).model.walls.keys.first;
    await selectWall(t, id);
    final v = harness.painter(t), before = harness.painter(t).model.toJson();
    final at = t.getTopLeft(harness.canvas) + v.labelBounds![id]!.center;
    final drag = await t.startGesture(at);
    await drag.moveTo(at + const Offset(0, -25));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    final after = harness.painter(t);
    expect(after.selectedWall, id);
    expect(after.model.walls.length, 4);
    expect(after.model.length(id), 2000);
    expect(after.model.toJson(), before);
  });

  testWidgets('Competing nearby wall taps retain the initial touch target',
      (t) async {
    await harness.open(t);
    await natural.stroke(t, const [Offset(100, 60), Offset(100, 240)]);
    await natural.stroke(t, const [Offset(130, 60), Offset(130, 240)]);
    final first = harness.painter(t).model.walls.keys.first;
    await menu(t, 'Plan actions', 'Multi-select');
    final origin = t.getTopLeft(harness.canvas);
    final tap = await t.startGesture(origin + const Offset(114, 150));
    await tap.moveTo(origin + const Offset(116, 150));
    await t.pump();
    await tap.up();
    await t.pumpAndSettle();
    expect(harness.painter(t).highlightedWalls, {first});
    expect(harness.painter(t).model.walls.length, 2);
  });
  testWidgets(
      'Group dragging after zoom uses world dimensions rather than screen pixels',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    await t.ensureVisible(find.byTooltip('Fit to Screen'));
    await t.tap(find.byTooltip('Fit to Screen'));
    await t.pumpAndSettle();
    await menu(t, 'Plan actions', 'Select all');
    final v = harness.painter(t),
        id = harness.painter(t).model.walls.keys.first;
    final corner = v.model.corners.keys.first,
        old = v.model.corners.values.first;
    final at = midpoint(t, id);
    final drag = await t.startGesture(at);
    await drag.moveTo(at + const Offset(25, 25));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    final moved = harness.painter(t).model.corners[corner]!;
    expect(moved.x - old.x, closeTo(25 / v.scale, .001));
    expect(moved.y - old.y, closeTo(25 / v.scale, .001));
  });

  testWidgets(
      'Multi-select toggles walls and corners and applies a persistent relationship',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    final ids = harness.painter(t).model.walls.keys.toList();
    await menu(t, 'Plan actions', 'Multi-select');
    await selectWall(t, ids[0]);
    await selectWall(t, ids[2]);
    expect(harness.painter(t).highlightedWalls, {ids[0], ids[2]});
    await t.ensureVisible(find.byTooltip('Add constraint'));
    await menu(t, 'Add constraint', 'Parallel');
    expect(harness.painter(t).model.relations.length, 1);
    expect(find.text('Parallel locked'), findsOneWidget);
    final v = harness.painter(t),
        at = t.getTopLeft(harness.canvas) +
            harness
                .painter(t)
                .screen(harness.painter(t).model.corners.values.first);
    await t.tapAt(at);
    await t.pumpAndSettle();
    expect(harness.painter(t).highlightedCorners.length, 1);
    await t.tapAt(at);
    await t.pumpAndSettle();
    expect(harness.painter(t).highlightedCorners, isEmpty);
    expect(v.model.walls.length, 4);
  });
  testWidgets('Partial group rejects external changes until explicitly allowed',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    final id = harness.painter(t).model.walls.keys.first;
    await menu(t, 'Plan actions', 'Multi-select');
    await selectWall(t, id);
    final before = geometry(t), at = midpoint(t, id);
    var drag = await t.startGesture(at);
    await drag.moveTo(at + const Offset(0, 25));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    expect(geometry(t), before);
    expect(find.textContaining('unselected walls'), findsOneWidget);
    await action(t, 'Stretch attached walls');
    drag = await t.startGesture(at);
    await drag.moveTo(at + const Offset(0, 25));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    expect(geometry(t), isNot(before));
    expect(harness.painter(t).model.walls.length, 4);
    await t.ensureVisible(find.byTooltip('Undo'));
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(geometry(t), before);
  });
  testWidgets(
      'Selected group duplicates safely and deletes the copy in one undoable operation',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    final id = harness.painter(t).model.walls.keys.first;
    await menu(t, 'Plan actions', 'Select all');
    await action(t, 'Duplicate selection');
    final at = midpoint(t, id);
    final drag = await t.startGesture(at);
    await drag.moveTo(at + const Offset(0, 230));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls.length, 8);
    expect(harness.painter(t).model.corners.length, 8);
    expect(harness.painter(t).highlightedWalls.length, 4);
    await t.ensureVisible(find.byTooltip('Delete selected geometry'));
    await t.tap(find.byTooltip('Delete selected geometry'));
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls.length, 4);
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls.length, 8);
    expect(harness.painter(t).model.corners.length, 8);
  });
  testWidgets('Known wall dimension calibrates the whole plan and is undoable',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    final ids = harness.painter(t).model.walls.keys.toList();
    await selectWall(t, ids[0]);
    await harness.moreWallOptions(t);
    await action(t, 'Calibrate plan');
    await t.enterText(find.byType(TextFormField), '4');
    await t.tap(find.text('Apply'));
    await t.pumpAndSettle();
    final m = harness.painter(t).model;
    expect(m.calibrated, isTrue);
    expect(m.length(ids[0]), 4000);
    expect(m.length(ids[1]), 3200);
    await t.ensureVisible(find.byTooltip('Undo'));
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(harness.painter(t).model.calibrated, isFalse);
    expect(harness.painter(t).model.length(ids[0]), 2000);
  });
  testWidgets(
      'Cancelled group drag restores geometry and does not add a history entry',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    final id = harness.painter(t).model.walls.keys.first;
    await menu(t, 'Plan actions', 'Select all');
    final before = geometry(t), at = midpoint(t, id);
    final drag = await t.startGesture(at);
    await drag.moveTo(at + const Offset(20, 20));
    await t.pump();
    await drag.cancel();
    await t.pumpAndSettle();
    expect(geometry(t), before);
    await t.ensureVisible(find.byTooltip('Undo'));
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls, isEmpty);
  });
}
