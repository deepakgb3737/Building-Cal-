import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'drawing_screen_test.dart' as board;
import 'wall_resize_interaction_test.dart' as editing;

Future<void> press(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text));
  await t.tap(find.text(text));
  await t.pumpAndSettle();
}

void main() {
  test(
      'Locking a diagonal preserves coordinates and rejects ordinary exact resizing',
      () {
    final m = WallNetwork()
      ..addPolyline(
          [const DrawingPoint(.3, .7), const DrawingPoint(1234.567, 2345.678)]);
    final id = m.walls.keys.single, corners = Map.of(m.corners);
    m.lockLength(id);
    expect(m.isFixed(id), isTrue);
    expect(m.corners, corners);
    final locked = m.toJson();
    expect(() => m.setRoomWallLength(id, m.length(id) + 100),
        throwsA(isA<DrawingConflict>()));
    expect(m.toJson(), locked);
    m.unlock(id);
    m.setRoomWallLength(id, 3000);
    expect(m.length(id), closeTo(3000, .00001));
  });

  testWidgets(
      'Visible lock blocks dragging and shared-corner resizing, unlock restores editing',
      (t) async {
    final id = await editing.selectFirst(t);
    final unlocked = board.painter(t).model.toJson();
    expect(find.text('Lock length'), findsOneWidget);
    expect(find.text('Resize options'), findsNothing);
    await press(t, 'Lock length');
    expect(find.text('Unlock length'), findsOneWidget);
    var view = board.painter(t);
    final locked = view.model.toJson(), wall = view.model.walls[id]!;
    await board.collapseTools(t);
    var at = t.getTopLeft(board.canvas) +
        view.screen(
            (view.model.corners[wall.start]! + view.model.corners[wall.end]!) *
                .5);
    var drag = await t.startGesture(at);
    await drag.moveBy(const Offset(0, 30));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), locked);
    expect(find.text('Unlock this wall before moving or resizing it.'),
        findsOneWidget);
    at = t.getTopLeft(board.canvas) +
        view.screen(view.model.corners[wall.start]!);
    drag = await t.startGesture(at);
    await drag.moveBy(const Offset(25, 25));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), locked);
    view = board.painter(t);
    at = t.getTopLeft(board.canvas) +
        view.screen(
            (view.model.corners[wall.start]! + view.model.corners[wall.end]!) *
                .5);
    await t.tapAt(at);
    await t.pumpAndSettle();
    await press(t, 'Unlock length');
    expect(board.painter(t).model.toJson(), unlocked);
    drag = await t.startGesture(at);
    await drag.moveBy(const Offset(0, 30));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), isNot(unlocked));
    await board.expandTools(t);
    await t.ensureVisible(find.byTooltip('Undo'));
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), unlocked);
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), locked);
    await t.tap(find.byTooltip('Redo'));
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), unlocked);
    expect(t.takeException(), isNull);
  });

  for (final size in [const Size(240, 420), const Size(740, 360)]) {
    testWidgets('Lock and immediate unlock remain accessible on $size',
        (t) async {
      final id = await editing.selectFirst(t);
      t.view.physicalSize = size;
      t.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpAndSettle();
      await press(t, 'Lock length');
      expect(board.painter(t).model.isFixed(id), isTrue);
      await press(t, 'Unlock length');
      expect(board.painter(t).model.isFixed(id), isFalse);
      expect(t.takeException(), isNull);
    });
  }
}
