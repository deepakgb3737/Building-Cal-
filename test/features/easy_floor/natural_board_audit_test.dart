import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'drawing_screen_test.dart' as board;
import 'annotation_interaction_test.dart' as notes;

void main() {
  test(
      'Rigid movement still rejects collisions with stationary walls atomically',
      () {
    final m = WallNetwork()
      ..addPolyline([const DrawingPoint(0, 0), const DrawingPoint(1000, 0)])
      ..addPolyline(
          [const DrawingPoint(500, 500), const DrawingPoint(500, 1500)]);
    final wall = m.walls.values.first, before = m.toJson();
    expect(
        () => m.moveCorners({
              wall.start: const DrawingPoint(0, 1000),
              wall.end: const DrawingPoint(1000, 1000)
            }),
        throwsA(isA<DrawingConflict>()));
    expect(m.toJson(), before);
  });

  test('Non-rigid edits never bypass self-crossing validation', () {
    final m = WallNetwork()
      ..addPolyline([
        const DrawingPoint(0, 0),
        const DrawingPoint(1000, 0),
        const DrawingPoint(1000, 1000),
        const DrawingPoint(0, 1000),
        const DrawingPoint(0, 0)
      ]);
    final nodes = m.corners.keys.toList(), before = m.toJson();
    expect(
        () => m.moveCorners({
              nodes[0]: const DrawingPoint(0, 0),
              nodes[1]: const DrawingPoint(1000, 1000),
              nodes[2]: const DrawingPoint(1000, 0),
              nodes[3]: const DrawingPoint(0, 1000)
            }),
        throwsA(isA<DrawingConflict>()));
    expect(m.toJson(), before);
  });

  test('Whole-shape length locking is atomic and leaves coordinates untouched',
      () {
    final m = WallNetwork()
      ..addPolyline([
        const DrawingPoint(0, 0),
        const DrawingPoint(2000, 0),
        const DrawingPoint(2000, 1000),
        const DrawingPoint(0, 1000),
        const DrawingPoint(0, 0)
      ]);
    final ids = m.walls.keys.toSet(), corners = Map.of(m.corners);
    m.setGroupLengthLocks(ids, locked: true);
    expect(ids.every(m.isFixed), isTrue);
    expect(m.corners, corners);
    final locked = m.toJson(), wall = m.walls.values.first;
    expect(
        () => m.moveCorners({
              wall.start: m.corners[wall.start]! + const DrawingPoint(0, 200),
              wall.end: m.corners[wall.end]! + const DrawingPoint(0, 200)
            }),
        throwsA(isA<DrawingConflict>()));
    expect(m.toJson(), locked);
    m.setGroupLengthLocks(ids, locked: false);
    expect(ids.any(m.isFixed), isFalse);
    expect(m.corners, corners);
  });

  testWidgets(
      'Selecting a note clears whole-room highlighting without changing walls',
      (t) async {
    await board.open(t);
    await board.outline(t);
    await notes.add(t, 'Site note', const Offset(90, 110));
    final id = notes.textView(t).annotations.items.keys.single;
    await board.expandTools(t);
    await t.ensureVisible(find.widgetWithText(ChoiceChip, 'Text'));
    await t.tap(find.widgetWithText(ChoiceChip, 'Text'));
    await t.pumpAndSettle();
    await board.collapseTools(t);
    final before = board.painter(t).model.toJson();
    await t.tapAt(t.getTopLeft(board.canvas) + const Offset(160, 170));
    await t.pumpAndSettle();
    expect(board.painter(t).highlightedWalls,
        board.painter(t).model.walls.keys.toSet());
    await t.tapAt(notes.noteAt(t, id));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('annotationText')), findsOneWidget);
    expect(board.painter(t).highlightedWalls, isEmpty);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), before);
    expect(t.takeException(), isNull);
  });

  for (final size in [const Size(240, 420), const Size(740, 360)]) {
    testWidgets(
        'Selected-shape lock is directly accessible and undoable on $size',
        (t) async {
      await board.open(t);
      await board.outline(t);
      await board.collapseTools(t);
      await t.tapAt(t.getTopLeft(board.canvas) + const Offset(160, 140));
      await t.pumpAndSettle();
      final before = board.painter(t).model.toJson();
      t.view.physicalSize = size;
      t.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpAndSettle();
      expect(find.text('Connected shape · 4 walls'), findsOneWidget);
      await t.tap(find.text('Lock lengths'));
      await t.pumpAndSettle();
      expect(
          board
              .painter(t)
              .model
              .walls
              .keys
              .every(board.painter(t).model.isFixed),
          isTrue);
      expect(find.text('Unlock lengths'), findsOneWidget);
      await t.tap(find.text('Unlock lengths'));
      await t.pumpAndSettle();
      expect(board.painter(t).model.toJson(), before);
      await board.expandTools(t);
      await t.ensureVisible(find.byTooltip('Undo'));
      await t.tap(find.byTooltip('Undo'));
      await t.pumpAndSettle();
      expect(
          board
              .painter(t)
              .model
              .walls
              .keys
              .every(board.painter(t).model.isFixed),
          isTrue);
      await t.ensureVisible(find.byTooltip('Redo'));
      await t.tap(find.byTooltip('Redo'));
      await t.pumpAndSettle();
      expect(board.painter(t).model.toJson(), before);
      expect(t.takeException(), isNull);
    });
  }
}
