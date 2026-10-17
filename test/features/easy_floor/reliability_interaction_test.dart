import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'drawing_screen_test.dart' as harness;
import 'natural_drawing_test.dart' as natural;

String geometry(WidgetTester t) => harness
    .painter(t)
    .model
    .corners
    .entries
    .map((e) => '${e.key}:${e.value.x},${e.value.y}')
    .join(';');
Future<void> undo(WidgetTester t) async {
  await t.ensureVisible(find.byTooltip('Undo'));
  await t.tap(find.byTooltip('Undo'));
  await t.pumpAndSettle();
}

Offset wallMiddle(WidgetTester t) {
  final v = harness.painter(t), w = harness.painter(t).model.walls.values.first;
  return t.getTopLeft(harness.canvas) +
      (v.screen(v.model.corners[w.start]!) +
              v.screen(v.model.corners[w.end]!)) /
          2;
}

void main() {
  testWidgets(
      'Turning precision options off leaves endpoint connections enabled',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    for (final value in ['grid', 'angle15', 'parallel', 'align']) {
      for (var toggle = 0; toggle < (value == 'align' ? 1 : 2); toggle++) {
        await t.tap(find.byTooltip('Drawing assistance'));
        await t.pumpAndSettle();
        await t.ensureVisible(find.byWidgetPredicate(
            (w) => w is CheckedPopupMenuItem && w.value == value));
        await t.tap(find.byWidgetPredicate(
            (w) => w is CheckedPopupMenuItem && w.value == value));
        await t.pumpAndSettle();
      }
    }
    await natural.stroke(t, const [Offset(160, 60), Offset(160, 220)],
        hold: true);
    expect(harness.painter(t).model.walls.length, 7);
    expect(harness.painter(t).model.corners.length, 6);
  });

  testWidgets('A multi-update drag produces one coherent undo/redo edit',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    final before = geometry(t), at = wallMiddle(t);
    final drag = await t.startGesture(at);
    for (final y in [20.0, 25.0, 30.0]) {
      await drag.moveTo(at + Offset(0, y));
      await t.pump();
    }
    await drag.up();
    await t.pumpAndSettle();
    final after = geometry(t);
    expect(after, isNot(before));
    await undo(t);
    expect(geometry(t), before);
    await t.tap(find.byTooltip('Redo'));
    await t.pumpAndSettle();
    expect(geometry(t), after);
  });
  testWidgets(
      'Ending at an impossible position rolls back the entire drag, not its last valid preview',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    final before = geometry(t), at = wallMiddle(t);
    final drag = await t.startGesture(at);
    await drag.moveTo(at + const Offset(0, 30));
    await t.pump();
    expect(geometry(t), isNot(before));
    await drag.moveTo(at + const Offset(0, 160));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    expect(geometry(t), before);
    expect(find.textContaining('below 10 mm'), findsOneWidget);
    await undo(t);
    expect(harness.painter(t).model.walls, isEmpty);
  });
  testWidgets(
      'Cancelled corner movement restores shared geometry and adds no history entry',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    await natural.stroke(t, const [Offset(160, 60), Offset(160, 220)],
        hold: true);
    final before = geometry(t), origin = t.getTopLeft(harness.canvas);
    final drag = await t.startGesture(origin + const Offset(160, 60));
    await drag.moveTo(origin + const Offset(180, 90));
    await t.pump();
    await drag.cancel();
    await t.pumpAndSettle();
    expect(geometry(t), before);
    expect(harness.painter(t).guides, isEmpty);
    await undo(t);
    expect(harness.painter(t).model.walls.length, 4);
  });
  testWidgets(
      'Split and join are accessible and undoable without removing branch junctions',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    await t.tapAt(wallMiddle(t));
    await t.pumpAndSettle();
    await harness.moreWallOptions(t);
    await t.ensureVisible(find.text('Split wall'));
    await t.tap(find.text('Split wall'));
    await t.pumpAndSettle();
    expect(find.text('Split distance from wall start'), findsOneWidget);
    await t.tap(find.text('Apply'));
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls.length, 5);
    await t.tap(find.text('Join straight segments'));
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls.length, 4);
    await undo(t);
    expect(harness.painter(t).model.walls.length, 5);
  });
  testWidgets(
      'A corner delete requires explicit confirmation for attached walls',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    final v = harness.painter(t),
        corner = harness.painter(t).model.corners.values.first;
    await t.tapAt(t.getTopLeft(harness.canvas) + v.screen(corner));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byTooltip('Delete selected geometry'));
    await t.tap(find.byTooltip('Delete selected geometry'));
    await t.pumpAndSettle();
    expect(find.text('Delete 2 connected walls?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls.length, 4);
    await t.tap(find.byTooltip('Delete selected geometry'));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete walls'));
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls.length, 2);
    await undo(t);
    expect(harness.painter(t).model.walls.length, 4);
  });
  testWidgets(
      'Automatic split-wall movement highlights and moves its connected straight run',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    await natural.stroke(t, const [Offset(160, 60), Offset(160, 220)],
        hold: true);
    final before = geometry(t),
        at = t.getTopLeft(harness.canvas) + const Offset(110, 60);
    final drag = await t.startGesture(at);
    await t.pump();
    expect(harness.painter(t).highlightedWalls.length, 1);
    await drag.moveTo(at + const Offset(0, -25));
    await t.pump();
    expect(harness.painter(t).highlightedWalls.length, 2);
    await drag.up();
    await t.pumpAndSettle();
    expect(geometry(t), isNot(before));
    expect(harness.painter(t).model.walls.length, 7);
    await undo(t);
    expect(geometry(t), before);
  });
}
