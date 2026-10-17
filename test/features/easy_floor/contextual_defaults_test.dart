import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/dimension_dialog.dart';
import 'drawing_screen_test.dart' as board;
import 'advanced_interaction_test.dart' as editing;

void main() {
  testWidgets(
      'Explicitly hidden overview still shows selected or edited dimensions',
      (t) async {
    await board.open(t, showLabels: false);
    await board.outline(t);
    await board.collapseTools(t);
    var view = board.painter(t);
    expect(view.showAllMeasurements, isFalse);
    expect(view.measuredWalls, isEmpty);
    expect(view.labelBounds, isEmpty);
    final id = view.model.walls.keys.first;
    await editing.selectWall(t, id);
    view = board.painter(t);
    expect(view.measuredWalls, {id});
    expect(view.labelBounds!.keys, [id]);
    await t.tapAt(t.getTopLeft(board.canvas) + view.labelBounds![id]!.center);
    await t.pumpAndSettle();
    expect(find.byType(DimensionDialog), findsOneWidget);
    final editable = t.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);
    expect(
        editable.controller.selection,
        TextSelection(
            baseOffset: 0, extentOffset: editable.controller.text.length));
    await t.enterText(find.byType(TextFormField), '2.1');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(board.painter(t).model.length(id), closeTo(2100, .001));
    await t.tapAt(t.getTopLeft(board.canvas) + const Offset(20, 20));
    await t.pumpAndSettle();
    expect(board.painter(t).measuredWalls, isEmpty);

    view = board.painter(t);
    final wall = view.model.walls[id]!,
        corner = view.model.corners[wall.start]!;
    final attached = {
      for (final w in view.model.walls.values)
        if (w.start == wall.start || w.end == wall.start) w.id
    };
    final at = t.getTopLeft(board.canvas) + view.screen(corner);
    await t.tapAt(at);
    await t.pumpAndSettle();
    expect(board.painter(t).measuredWalls, attached);
    final before = board.painter(t).model.toJson();
    final drag = await t.startGesture(at);
    await drag.moveBy(const Offset(-12, -8));
    await t.pump();
    expect(board.painter(t).measuredWalls, attached);
    await drag.cancel();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), before);
    await t.tapAt(t.getTopLeft(board.canvas) + const Offset(20, 20));
    await t.pumpAndSettle();
    expect(board.painter(t).measuredWalls, isEmpty);
    await board.expandTools(t);
    await t.tap(find.byTooltip('Show labels'));
    await t.pumpAndSettle();
    expect(board.painter(t).measuredWalls,
        board.painter(t).model.walls.keys.toSet());
    expect(board.painter(t).model.toJson(), before);
    expect(t.takeException(), isNull);
  });
}
