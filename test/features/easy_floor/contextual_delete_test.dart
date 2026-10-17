import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'drawing_screen_test.dart' as board;
import 'advanced_interaction_test.dart' as editing;
import 'annotation_interaction_test.dart' as text;

Finder get delete => find.byTooltip('Delete selected geometry');

Future<void> remove(WidgetTester t) async {
  await t.ensureVisible(delete);
  await t.tap(delete);
  await t.pumpAndSettle();
}

void main() {
  for (final size in [const Size(240, 420), const Size(640, 320)]) {
    testWidgets('Contextual Delete remains usable on $size with enlarged text',
        (t) async {
      await board.open(t);
      await board.outline(t);
      await board.collapseTools(t);
      t.view.physicalSize = size;
      t.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpAndSettle();
      final model = board.painter(t).model, before = model.toJson();
      await editing.selectWall(t, model.walls.keys.first);
      await remove(t);
      expect(board.painter(t).model.walls.length, 3);
      await text.undo(t, 'Undo');
      expect(board.painter(t).model.toJson(), before);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
      'Delete is hidden without selection; contextual single-wall deletion is exact and undoable',
      (t) async {
    await board.open(t);
    expect(delete, findsNothing);
    await board.outline(t);
    await text.add(t, 'Room A', const Offset(90, 120));
    await board.expandTools(t);
    await t.ensureVisible(find.widgetWithText(ChoiceChip, 'Text'));
    await t.tap(find.widgetWithText(ChoiceChip, 'Text'));
    await t.pumpAndSettle();
    await board.collapseTools(t);
    final before = board.painter(t).model.toJson();
    final notes = text.textView(t).annotations.toJson();
    final wall = board.painter(t).model.walls.values.first;
    await editing.selectWall(t, wall.id);
    expect(find.text('Delete'), findsOneWidget);
    expect(delete, findsOneWidget);
    await remove(t);
    final after = board.painter(t).model;
    expect(after.walls.length, 3);
    expect(after.walls.containsKey(wall.id), isFalse);
    expect(after.toJson()['walls'],
        (before['walls'] as List).where((row) => row[0] != wall.id).toList());
    expect(after.toJson()['corners'], before['corners']);
    expect(WallNetwork.fromJson(after.toJson()).toJson(), after.toJson());
    expect(text.textView(t).annotations.toJson(), notes);
    expect(delete, findsNothing);
    await text.undo(t, 'Undo');
    expect(board.painter(t).model.toJson(), before);
    expect(text.textView(t).annotations.toJson(), notes);
    await text.undo(t, 'Redo');
    expect(board.painter(t).model.walls.containsKey(wall.id), isFalse);
  });

  for (final walls in [true, false]) {
    testWidgets(
        'Select all deletes the entire ${walls ? 'plan' : 'text-only drawing'} and Undo restores both layers',
        (t) async {
      await board.open(t);
      if (walls) await board.outline(t);
      await text.add(t, 'Site note', const Offset(80, 110));
      final before = board.painter(t).model.toJson();
      final notes = text.textView(t).annotations.toJson();
      await editing.menu(t, 'Plan actions', 'Select all');
      expect(find.byTooltip('Expand drawing tools'), findsOneWidget);
      await board.expandTools(t);
      expect(find.text('Entire drawing selected'), findsOneWidget);
      expect(text.textView(t).selected,
          text.textView(t).annotations.items.keys.toSet());
      await remove(t);
      expect(board.painter(t).model.walls, isEmpty);
      expect(board.painter(t).model.corners, isEmpty);
      expect(text.textView(t).annotations.items, isEmpty);
      expect(delete, findsNothing);
      await text.undo(t, 'Undo');
      expect(board.painter(t).model.toJson(), before);
      expect(text.textView(t).annotations.toJson(), notes);
      await text.undo(t, 'Redo');
      expect(board.painter(t).model.walls, isEmpty);
      expect(text.textView(t).annotations.items, isEmpty);
    });
  }

  testWidgets('An old Delete callback cannot delete during wall drag or pinch',
      (t) async {
    await board.open(t);
    await board.outline(t);
    await board.collapseTools(t);
    final id = board.painter(t).model.walls.keys.first;
    await editing.selectWall(t, id);
    final before = board.painter(t).model.toJson();
    final action = t
        .widget<TextButton>(find.widgetWithText(TextButton, 'Delete'))
        .onPressed!;
    final at = editing.midpoint(t, id);
    final a = await t.startGesture(at, pointer: 1);
    await a.moveTo(at + const Offset(0, 30));
    await t.pump();
    expect(delete, findsNothing);
    action();
    await t.pump();
    expect(board.painter(t).model.walls.length, 4);
    final origin = t.getTopLeft(board.canvas);
    final b = await t.startGesture(origin + const Offset(280, 280), pointer: 2);
    await b.moveTo(origin + const Offset(290, 300));
    await t.pump();
    expect(delete, findsNothing);
    action();
    await t.pump();
    expect(board.painter(t).model.toJson(), before);
    await b.up();
    await a.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), before);
    await text.undo(t, 'Undo');
    expect(board.painter(t).model.walls, isEmpty);
  });

  testWidgets('Text Delete is hidden when there is no text selection',
      (t) async {
    await board.open(t);
    await text.textTool(t);
    expect(find.byTooltip('Delete text'), findsNothing);
  });
}
