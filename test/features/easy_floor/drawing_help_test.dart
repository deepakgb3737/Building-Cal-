import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'drawing_screen_test.dart' as board;
import 'advanced_interaction_test.dart' as editing;

void main() {
  testWidgets(
      'Empty-canvas guidance does not intercept drawing or appear in Hide UI',
      (t) async {
    await board.open(t);
    expect(find.text('Sketch your first room'), findsOneWidget);
    await t.tap(find.byTooltip('Hide UI'));
    await t.pumpAndSettle();
    expect(find.text('Sketch your first room'), findsNothing);
    await t.tap(find.byTooltip('Show Tools'));
    await t.pumpAndSettle();
    expect(find.text('Sketch your first room'), findsOneWidget);
    await board.collapseTools(t);
    final center = t.getCenter(find.text('Sketch your first room'));
    final gesture = await t.startGesture(center);
    await gesture.moveTo(center + const Offset(100, 0));
    await t.pump();
    expect(find.text('Sketch your first room'), findsNothing);
    expect(board.painter(t).preview.length, 2);
    await gesture.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.walls.length, 1);
    expect(find.text('Sketch your first room'), findsNothing);
    expect(t.takeException(), isNull);
  });

  for (final size in [const Size(240, 420), const Size(740, 320)]) {
    testWidgets(
        'Drawing help is scrollable at $size and leaves the plan unchanged',
        (t) async {
      await board.open(t);
      await board.outline(t);
      final before = board.painter(t).model.toJson();
      final origin = board.painter(t).origin, scale = board.painter(t).scale;
      t.view.physicalSize = size;
      t.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpAndSettle();
      await editing.menu(t, 'More drawing tools', 'Drawing help');
      expect(find.text('Add a connected wall'), findsOneWidget);
      await t.ensureVisible(find.text('Back to drawing'));
      await t.tap(find.text('Back to drawing'));
      await t.pumpAndSettle();
      expect(board.painter(t).model.toJson(), before);
      expect(board.painter(t).origin, origin);
      expect(board.painter(t).scale, scale);
      expect(find.byType(BottomSheet), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
}
