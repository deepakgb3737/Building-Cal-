import 'package:flutter_test/flutter_test.dart';
import 'drawing_screen_test.dart' as board;

void main() {
  for (final corner in [false, true]) {
    for (final cancel in [false, true]) {
      testWidgets(
          'Pinch interrupts ${corner ? 'corner' : 'wall'} editing safely (${cancel ? 'cancel' : 'release'})',
          (t) async {
        await board.open(t);
        await board.outline(t);
        await board.collapseTools(t);
        final view = board.painter(t), wall = view.model.walls.values.first;
        final original = view.model.toJson();
        final offset = t.getTopLeft(board.canvas);
        final point = corner
            ? view.model.corners[wall.start]!
            : (view.model.corners[wall.start]! +
                    view.model.corners[wall.end]!) *
                .5;
        final at = offset + view.screen(point);
        final first = await t.startGesture(at, pointer: 1);
        await first.moveTo(at + const Offset(25, 30));
        await t.pump();
        expect(board.painter(t).model.toJson(), isNot(original));
        final second =
            await t.startGesture(offset + const Offset(250, 320), pointer: 2);
        await t.pump();
        expect(board.painter(t).model.toJson(), original);
        await second.moveBy(const Offset(20, 15));
        await t.pump();
        if (cancel) {
          await second.cancel();
        } else {
          await second.up();
        }
        // The remaining finger must stay navigation-only, even over geometry.
        await first.moveTo(offset + const Offset(150, 180));
        await t.pump();
        expect(board.painter(t).model.toJson(), original);
        expect(board.painter(t).preview, isEmpty);
        await first.up();
        await t.pumpAndSettle();
        await board.expandTools(t);
        await t.ensureVisible(find.byTooltip('Undo'));
        await t.tap(find.byTooltip('Undo'));
        await t.pumpAndSettle();
        expect(board.painter(t).model.walls, isEmpty);
        await t.ensureVisible(find.byTooltip('Redo'));
        await t.tap(find.byTooltip('Redo'));
        await t.pumpAndSettle();
        expect(board.painter(t).model.toJson(), original);
        await board.collapseTools(t);
        final restored = board.painter(t);
        final middle = (restored.model.corners[wall.start]! +
                restored.model.corners[wall.end]!) *
            .5;
        final nextAt = offset + restored.screen(middle);
        final next = await t.startGesture(nextAt);
        await next.moveBy(const Offset(0, 25));
        await t.pump();
        expect(board.painter(t).model.toJson(), isNot(original));
        await next.cancel();
        await t.pumpAndSettle();
        expect(board.painter(t).model.toJson(), original);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'A cancelled stationary hold cannot turn the next drag into drawing',
      (t) async {
    await board.open(t);
    await board.outline(t);
    await board.collapseTools(t);
    final view = board.painter(t), wall = view.model.walls.values.first;
    final original = view.model.toJson();
    final at = t.getTopLeft(board.canvas) +
        view.screen(
            (view.model.corners[wall.start]! + view.model.corners[wall.end]!) *
                .5);
    final hold = await t.startGesture(at);
    await t.pump(const Duration(milliseconds: 500));
    await hold.cancel();
    await t.pumpAndSettle();
    final next = await t.startGesture(at);
    await next.moveBy(const Offset(0, 30));
    await t.pump();
    expect(board.painter(t).selectedWall, wall.id);
    expect(board.painter(t).preview, isEmpty);
    expect(board.painter(t).model.toJson(), isNot(original));
    await next.cancel();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), original);
    expect(t.takeException(), isNull);
  });
}
