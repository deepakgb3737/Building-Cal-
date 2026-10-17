import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/dimension_dialog.dart';
import 'drawing_screen_test.dart' as board;
import 'wall_resize_interaction_test.dart' as editing;
import 'accessible_lock_test.dart' show press;
import 'annotation_interaction_test.dart' show undo;

void main() {
  testWidgets('An impossible split can be corrected without reopening the form',
      (t) async {
    await editing.selectFirst(t);
    final before = board.painter(t).model.toJson();
    await board.moreWallOptions(t);
    await press(t, 'Split wall');
    final input = find.byType(TextFormField);
    await t.enterText(input, '3');
    await t.tap(find.text('Apply'));
    await t.pumpAndSettle();
    expect(find.byType(DimensionDialog), findsOneWidget);
    expect(
        find.text('Each split part must be at least 10 mm.'), findsOneWidget);
    expect(board.painter(t).model.toJson(), before);
    await t.enterText(input, '1');
    await t.tap(find.text('Apply'));
    await t.pumpAndSettle();
    expect(find.byType(DimensionDialog), findsNothing);
    expect(board.painter(t).model.walls.length, 5);
    await undo(t, 'Undo');
    expect(board.painter(t).model.toJson(), before);
    await undo(t, 'Redo');
    expect(board.painter(t).model.walls.length, 5);
    expect(t.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(740, 360)]) {
    testWidgets('Conflicting exact entry stays editable on $size', (t) async {
      final id = await editing.selectFirst(t);
      await press(t, 'Lock length');
      final locked = board.painter(t).model.toJson();
      var view = board.painter(t);
      await t.tapAt(t.getTopLeft(board.canvas) + view.labelBounds![id]!.center);
      await t.pumpAndSettle();
      t.view.physicalSize = size;
      await t.pumpAndSettle();
      final input = find.byType(TextFormField);
      await t.enterText(input, '2.4');
      await t.tap(find.text('Apply'));
      await t.pumpAndSettle();
      expect(find.byType(DimensionDialog), findsOneWidget);
      expect(find.text('Unlock this wall before changing its length.'),
          findsOneWidget);
      expect(t.widget<TextFormField>(input).controller!.text, '2.4');
      expect(board.painter(t).model.toJson(), locked);
      await t.enterText(input, '2.5');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(find.byType(DimensionDialog), findsOneWidget);
      expect(board.painter(t).model.toJson(), locked);
      expect(find.text('Cancel').hitTestable(), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      t.view.physicalSize = const Size(320, 740);
      await t.pumpAndSettle();
      await press(t, 'Unlock length');
      final unlocked = board.painter(t).model.toJson();
      view = board.painter(t);
      await t.tapAt(t.getTopLeft(board.canvas) + view.labelBounds![id]!.center);
      await t.pumpAndSettle();
      await t.enterText(input, '2.4');
      await t.tap(find.text('Apply'));
      await t.pumpAndSettle();
      expect(find.byType(DimensionDialog), findsNothing);
      expect(board.painter(t).model.length(id), closeTo(2400, .001));
      await undo(t, 'Undo');
      expect(board.painter(t).model.toJson(), unlocked);
      await undo(t, 'Undo');
      expect(board.painter(t).model.toJson(), locked);
      expect(t.takeException(), isNull);
    });
  }
}
