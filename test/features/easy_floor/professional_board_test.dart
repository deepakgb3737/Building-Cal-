import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'drawing_screen_test.dart' as board;
import 'annotation_interaction_test.dart' as actions;
import 'advanced_interaction_test.dart' as editing;

void main() {
  for (final scale in [.02, .1, 1.0]) {
    test(
        'Snap chooses the wall under the finger, not a farther corner at $scale',
        () {
      final m = WallNetwork()
        ..addPolyline([const DrawingPoint(0, 0), DrawingPoint(300 / scale, 0)])
        ..addPolyline([
          DrawingPoint(150 / scale, 9 / scale),
          DrawingPoint(150 / scale, 60 / scale)
        ]);
      final snap = m.snap(DrawingPoint(150 / scale, 0), 10 / scale);
      expect(snap.x, closeTo(150 / scale, .001));
      expect(snap.y, 0);
      final corner = m.snap(DrawingPoint(150 / scale, 9 / scale), 10 / scale);
      expect(corner.y, closeTo(9 / scale, .001));
    });
  }

  test('Equal-distance snap targets do not depend on wall insertion order', () {
    final m = WallNetwork()
      ..addPolyline([const DrawingPoint(0, 0), const DrawingPoint(3000, 0)])
      ..addPolyline(
          [const DrawingPoint(0, 100), const DrawingPoint(3000, 100)]);
    final snap = m.snap(const DrawingPoint(1500, 50), 100);
    final entries = m.walls.entries.toList().reversed.toList();
    m.walls
      ..clear()
      ..addEntries(entries);
    final reversed = m.snap(const DrawingPoint(1500, 50), 100);
    expect(reversed.x, snap.x);
    expect(reversed.y, snap.y);
  });

  testWidgets(
      'Complete first-user acceptance workflow stays in automatic editing',
      (t) async {
    await board.open(t);
    await board.outline(t);
    await board.collapseTools(t);
    var v = board.painter(t);
    final top = v.model.walls.values.first;
    final right = v.model.walls.values.elementAt(1);
    final fixedSide = v.model.corners[top.start]!;
    var at = editing.midpoint(t, right.id);
    var drag = await t.startGesture(at);
    await drag.moveTo(at + const Offset(-20, 0));
    await t.pump();
    expect(board.painter(t).measuredWalls.length, greaterThan(1));
    await drag.up();
    await t.pumpAndSettle();
    v = board.painter(t);
    expect(v.model.rectangle(top.id), isNotNull);
    expect(v.model.corners[top.start]!.x, fixedSide.x);
    expect(v.model.length(top.id), closeTo(1800, .001));

    await editing.selectWall(t, top.id);
    v = board.painter(t);
    await t.tapAt(t.getTopLeft(board.canvas) + v.labelBounds![top.id]!.center);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField), '2.4');
    await t.tap(find.text('Apply'));
    await t.pumpAndSettle();
    v = board.painter(t);
    expect(v.model.length(top.id), closeTo(2400, .001));
    expect(v.model.rectangle(top.id), isNotNull);
    expect(v.model.isFixed(top.id), isFalse);

    final nodes = v.model.rectangle(top.id)!;
    final a = v.model.corners[nodes[0]]!, b = v.model.corners[nodes[1]]!;
    final c = v.model.corners[nodes[2]]!, d = v.model.corners[nodes[3]]!;
    final origin = t.getTopLeft(board.canvas);
    drag = await t.startGesture(origin + v.screen((a + b) * .5));
    await t.pump(const Duration(milliseconds: 500));
    await drag.moveTo(origin + v.screen((c + d) * .5));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    await board.keepSketch(t);
    v = board.painter(t);
    expect(v.model.walls.length, 7);
    expect(v.model.corners.length, 6);
    expect(() => WallNetwork.fromJson(v.model.toJson()), returnsNormally);

    final corner = v.model.corners[nodes[0]]!;
    final untouched = v.model.corners[nodes[2]]!;
    at = t.getTopLeft(board.canvas) + v.screen(corner);
    drag = await t.startGesture(at);
    await drag.moveTo(at + const Offset(-20, -20));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    v = board.painter(t);
    expect(v.model.corners[nodes[2]]!.x, untouched.x);
    expect(v.model.corners[nodes[2]]!.y, untouched.y);
    expect(() => WallNetwork.fromJson(v.model.toJson()), returnsNormally);

    final wallId = v.model.walls.keys.last;
    await editing.selectWall(t, wallId);
    final beforeDelete = board.painter(t).model.toJson();
    await t.ensureVisible(find.byTooltip('Delete selected geometry'));
    await t.tap(find.byTooltip('Delete selected geometry'));
    await t.pumpAndSettle();
    expect(board.painter(t).model.walls.length, 6);
    await actions.undo(t, 'Undo');
    expect(board.painter(t).model.toJson(), beforeDelete);
    await actions.undo(t, 'Redo');
    expect(board.painter(t).model.walls.length, 6);
    await actions.undo(t, 'Undo');

    drag = await t
        .startGesture(t.getTopLeft(board.canvas) + const Offset(40, 300));
    await drag.moveTo(t.getTopLeft(board.canvas) + const Offset(240, 300));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.walls.length, 8);
    expect(() => WallNetwork.fromJson(board.painter(t).model.toJson()),
        returnsNormally);
    expect(t.takeException(), isNull);
  });
}
