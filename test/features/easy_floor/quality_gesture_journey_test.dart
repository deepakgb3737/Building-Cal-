import 'package:flutter_test/flutter_test.dart';
import 'drawing_screen_test.dart' as board;
import 'endpoint_connection_test.dart' show wall;
import 'annotation_interaction_test.dart' show undo;

void main() {
  testWidgets(
      'Interrupted three-finger edit recovers into joining and exact Undo/Redo',
      (t) async {
    await board.open(t, showLabels: false);
    await board.tool(t, 'Wall');
    await board.collapseTools(t);
    await wall(t, const Offset(60, 100), const Offset(140, 100));
    await wall(t, const Offset(220, 200), const Offset(220, 280));
    final original = board.painter(t).model.toJson();
    final offset = t.getTopLeft(board.canvas);
    final first =
        await t.startGesture(offset + const Offset(220, 240), pointer: 1);
    await first.moveBy(const Offset(-25, -20));
    await t.pump();
    expect(board.painter(t).model.toJson(), isNot(original));
    final second =
        await t.startGesture(offset + const Offset(100, 350), pointer: 2);
    final third =
        await t.startGesture(offset + const Offset(250, 350), pointer: 3);
    await t.pump();
    expect(board.painter(t).model.toJson(), original);
    await third.cancel();
    await second.moveBy(const Offset(10, 5));
    await first.moveBy(const Offset(-10, 5));
    await t.pump();
    await second.up();
    await first.moveTo(offset + const Offset(140, 100));
    await first.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), original);
    expect(board.painter(t).preview, isEmpty);
    final v = board.painter(t), moving = v.model.walls.values.last;
    final target = v.model.corners[v.model.walls.values.first.end]!;
    final a = v.model.corners[moving.start]!, b = v.model.corners[moving.end]!;
    final midpoint = v.screen((a + b) * .5);
    final shift = v.screen(target) - v.screen(a);
    final join = await t.startGesture(offset + midpoint);
    await join.moveTo(offset + midpoint + shift);
    await t.pump();
    expect(board.painter(t).connection, isNotNull);
    await join.up();
    await t.pumpAndSettle();
    final joined = board.painter(t).model;
    expect(joined.walls.length, 2);
    expect(joined.corners.length, 3);
    final after = joined.toJson();
    await undo(t, 'Undo');
    expect(board.painter(t).model.toJson(), original);
    await undo(t, 'Redo');
    expect(board.painter(t).model.toJson(), after);
    expect(t.takeException(), isNull);
  });
}
