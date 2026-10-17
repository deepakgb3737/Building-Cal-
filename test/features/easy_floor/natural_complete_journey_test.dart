import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'drawing_screen_test.dart' as board;
import 'natural_drawing_test.dart' as sketch;
import 'advanced_interaction_test.dart' as editing;
import 'annotation_interaction_test.dart' as actions;

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(320, 740),
    const Size(430, 900)
  ]) {
    testWidgets(
        'Draw, resize, partition, move, delete, navigate and continue on $size',
        (t) async {
      await board.open(t, showLabels: size.height == 568);
      t.view.physicalSize = size;
      await t.pumpAndSettle();
      await board.outline(t);
      await board.collapseTools(t);
      final top = board.painter(t).model.walls.values.first;
      final right = board.painter(t).model.walls.values.elementAt(1);
      final fixed = board.painter(t).model.corners[top.start]!;
      final at = editing.midpoint(t, right.id);
      final resize = await t.startGesture(at);
      await resize.moveBy(const Offset(-20, 0));
      await t.pump();
      await resize.up();
      await t.pumpAndSettle();
      expect(board.painter(t).model.length(top.id), closeTo(1800, .001));
      expect(board.painter(t).model.corners[top.start]!.x, fixed.x);

      var view = board.painter(t);
      await editing.selectWall(t, top.id);
      view = board.painter(t);
      await t.tapAt(
          t.getTopLeft(board.canvas) + view.labelBounds![top.id]!.center);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField), '2.1');
      await t.tap(find.text('Apply'));
      await t.pumpAndSettle();
      expect(board.painter(t).model.length(top.id), closeTo(2100, .001));
      await sketch.stroke(t, const [Offset(165, 60), Offset(165, 220)],
          hold: true);
      expect(board.painter(t).model.walls.length, 7);
      final connected = board.painter(t).model.walls.keys.toSet();
      await sketch.stroke(t, const [
        Offset(70, 310),
        Offset(220, 310),
        Offset(250, 355),
        Offset(180, 420),
        Offset(70, 420),
        Offset(70, 310)
      ]);
      view = board.painter(t);
      expect(view.model.walls.length, 12);
      final movingNodes = view.model.groupNodes(connected, {});
      final before = Map.of(view.model.corners);
      final origin = t.getTopLeft(board.canvas);
      final move = await t.startGesture(origin + const Offset(105, 105));
      await move.moveBy(const Offset(0, 50));
      await t.pump();
      await move.up();
      await t.pumpAndSettle();
      view = board.painter(t);
      for (final entry in before.entries) {
        final shift = view.model.corners[entry.key]! - entry.value;
        expect(shift.x, closeTo(0, .001));
        expect(
            shift.y, closeTo(movingNodes.contains(entry.key) ? 500 : 0, .001));
      }
      expect(find.byTooltip('Expand drawing tools'), findsOneWidget);
      final beforeDelete = view.model.toJson();
      await editing.selectWall(t, connected.last);
      await t.ensureVisible(find.byTooltip('Delete selected geometry'));
      await t.tap(find.byTooltip('Delete selected geometry'));
      await t.pumpAndSettle();
      expect(board.painter(t).model.walls.length, 11);
      await actions.undo(t, 'Undo');
      expect(board.painter(t).model.toJson(), beforeDelete);

      final a =
          await t.startGesture(origin + const Offset(30, 460), pointer: 1);
      final b =
          await t.startGesture(origin + const Offset(250, 460), pointer: 2);
      final camera = board.painter(t).scale;
      await a.moveBy(const Offset(-10, 20));
      await b.moveBy(const Offset(30, 20));
      await t.pump();
      expect(board.painter(t).scale, greaterThan(camera));
      expect(board.painter(t).model.toJson(), beforeDelete);
      await a.up();
      await b.up();
      await t.pumpAndSettle();
      await sketch.stroke(t, const [Offset(20, 20), Offset(100, 20)]);
      expect(board.painter(t).model.walls.length, 13);
      expect(() => WallNetwork.fromJson(board.painter(t).model.toJson()),
          returnsNormally);
      expect(find.byTooltip('Expand drawing tools'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  for (final size in [const Size(240, 420), const Size(740, 360)]) {
    testWidgets('Collapsed sketch review stays usable after rotation to $size',
        (t) async {
      await board.open(t);
      await board.collapseTools(t);
      await sketch.stroke(
          t,
          const [
            Offset(60, 60),
            Offset(260, 60),
            Offset(260, 220),
            Offset(60, 220),
            Offset(60, 60)
          ],
          finish: false);
      t.view.physicalSize = size;
      t.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpAndSettle();
      expect(find.byTooltip('Expand drawing tools'), findsOneWidget);
      await t.tap(find.byTooltip('Hide UI'));
      await t.pumpAndSettle();
      expect(find.text('Keep Original'), findsNothing);
      await t.tap(find.byTooltip('Show Tools'));
      await t.pumpAndSettle();
      final keep = find.text('Keep Original');
      await t.ensureVisible(keep);
      expect(keep.hitTestable(), findsOneWidget);
      await t.tap(keep);
      await t.pumpAndSettle();
      expect(board.painter(t).model.walls.length, 4);
      expect(board.painter(t).rawStroke, isEmpty);
      expect(find.byTooltip('Expand drawing tools'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
