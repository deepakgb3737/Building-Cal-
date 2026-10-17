import 'package:flutter_test/flutter_test.dart';
import 'drawing_screen_test.dart' as board;

void main() {
  for (final action in ['draw', 'wall', 'corner']) {
    testWidgets('Two-finger pan interrupts $action without changing the plan',
        (t) async {
      await board.open(t);
      await board.outline(t);
      await board.collapseTools(t);
      final view = board.painter(t), wall = view.model.walls.values.first;
      final original = view.model.toJson();
      final offset = t.getTopLeft(board.canvas);
      final at = switch (action) {
        'wall' => view.screen(
            (view.model.corners[wall.start]! + view.model.corners[wall.end]!) *
                .5),
        'corner' => view.screen(view.model.corners[wall.start]!),
        _ => const Offset(90, 300),
      };
      final a = await t.startGesture(offset + at, pointer: 1);
      final moved = at + const Offset(20, 30);
      await a.moveTo(offset + moved);
      await t.pump();
      final beforeNavigation = board.painter(t);
      const other = Offset(180, 280);
      final b = await t.startGesture(offset + other, pointer: 2);
      await t.pump();
      expect((board.painter(t).origin - beforeNavigation.origin).distance,
          lessThan(1e-7));
      expect(board.painter(t).scale, closeTo(beforeNavigation.scale, 1e-9));
      expect(board.painter(t).model.toJson(), original);
      const translation = Offset(-25, 45);
      await a.moveTo(offset + moved + translation);
      await b.moveTo(offset + other + translation);
      await t.pump();
      var next = board.painter(t);
      expect(next.scale, closeTo(beforeNavigation.scale, 1e-9));
      expect((next.origin - beforeNavigation.origin - translation).distance,
          lessThan(1e-7));
      final navigationOrigin = next.origin;
      await b.up();
      await a.moveBy(const Offset(5, 5));
      await t.pump();
      expect((board.painter(t).origin - navigationOrigin).distance,
          lessThan(1e-7));
      expect(board.painter(t).model.toJson(), original);
      // A replacement second finger must rebase, not jump to the old midpoint.
      final c = await t.startGesture(offset + other, pointer: 3);
      await t.pump();
      expect((board.painter(t).origin - navigationOrigin).distance,
          lessThan(1e-7));
      await a.moveBy(const Offset(10, 10));
      await c.moveBy(const Offset(10, 10));
      await t.pump();
      next = board.painter(t);
      expect((next.origin - navigationOrigin - const Offset(10, 10)).distance,
          lessThan(1e-7));
      await a.up();
      await c.up();
      await t.pumpAndSettle();
      expect(board.painter(t).model.toJson(), original);
      expect(board.painter(t).preview, isEmpty);
      // Navigation is not an Undo entry.
      await board.expandTools(t);
      await t.ensureVisible(find.byTooltip('Undo'));
      await t.tap(find.byTooltip('Undo'));
      await t.pumpAndSettle();
      expect(board.painter(t).model.walls, isEmpty);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
      'Two remaining fingers can navigate after a third pointer is cancelled',
      (t) async {
    await board.open(t);
    await board.outline(t);
    await board.collapseTools(t);
    final offset = t.getTopLeft(board.canvas);
    final original = board.painter(t).model.toJson();
    final a = await t.startGesture(offset + const Offset(80, 280), pointer: 1);
    final b = await t.startGesture(offset + const Offset(220, 280), pointer: 2);
    final c = await t.startGesture(offset + const Offset(150, 340), pointer: 3);
    await c.cancel();
    await t.pump();
    final before = board.painter(t);
    await a.moveBy(const Offset(20, 25));
    await b.moveBy(const Offset(20, 25));
    await t.pump();
    final after = board.painter(t);
    expect(after.scale, closeTo(before.scale, 1e-9));
    expect((after.origin - before.origin - const Offset(20, 25)).distance,
        lessThan(1e-7));
    expect(after.model.toJson(), original);
    await a.up();
    await b.up();
    await t.pumpAndSettle();
    expect(board.painter(t).preview, isEmpty);
    expect(t.takeException(), isNull);
  });
}
