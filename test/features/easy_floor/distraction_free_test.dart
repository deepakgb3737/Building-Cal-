import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'drawing_screen_test.dart' as board;
import 'wall_resize_interaction_test.dart' as editing;

Future<void> toggle(WidgetTester t, String tooltip) async {
  await t.tap(find.byTooltip(tooltip));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
      'Hide UI preserves palette position, collapse state, selection and camera',
      (t) async {
    await editing.selectFirst(t);
    await t.drag(
        find.byKey(const ValueKey('moveDrawingTools')), const Offset(-25, -30));
    await t.pumpAndSettle();
    await board.collapseTools(t);
    final palette = t.getRect(find.byKey(const ValueKey('drawingToolPalette')));
    final view = board.painter(t), geometry = view.model.toJson();
    final bounds = t.getRect(board.canvas);
    await toggle(t, 'Hide UI');
    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const ValueKey('drawingToolPalette')), findsNothing);
    expect(find.text('Enter length'), findsNothing);
    expect(find.byTooltip('Show Tools'), findsOneWidget);
    expect(t.getRect(board.canvas).height, bounds.height + kToolbarHeight);
    expect(t.getTopLeft(board.canvas) + board.painter(t).origin,
        bounds.topLeft + view.origin);
    expect(board.painter(t).scale, view.scale);
    expect(board.painter(t).model.toJson(), geometry);
    expect(board.painter(t).measuredWalls, view.measuredWalls);
    await toggle(t, 'Show Tools');
    expect(find.text('Enter length'), findsOneWidget);
    expect(find.byTooltip('Expand drawing tools'), findsOneWidget);
    expect(
        t.getRect(find.byKey(const ValueKey('drawingToolPalette'))), palette);
    expect(board.painter(t).selectedWall, view.selectedWall);
    expect(t.takeException(), isNull);
  });

  testWidgets('Hide UI does not interrupt an active wall edit or its Undo',
      (t) async {
    final id = await editing.selectFirst(t);
    await board.collapseTools(t);
    final view = board.painter(t), wall = view.model.walls[id]!;
    final before = view.model.toJson();
    final at = t.getTopLeft(board.canvas) +
        (view.screen(view.model.corners[wall.start]!) +
                view.screen(view.model.corners[wall.end]!)) /
            2;
    final drag = await t.startGesture(at);
    await drag.moveTo(at + const Offset(0, 20));
    await t.pump();
    final live = board.painter(t).model.toJson();
    // Invoke the control while another pointer owns the canvas gesture.
    t
        .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.visibility_off_outlined))
        .onPressed!();
    await t.pump();
    expect(board.painter(t).model.toJson(), live);
    expect(find.byTooltip('Hide UI'), findsOneWidget);
    await drag.moveTo(at + const Offset(0, 30));
    await t.pump();
    expect(board.painter(t).measuredWalls, contains(id));
    await drag.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), isNot(before));
    expect(find.byTooltip('Show Tools'), findsOneWidget);
    expect(find.text('Enter length'), findsNothing);
    await toggle(t, 'Show Tools');
    await board.expandTools(t);
    await t.ensureVisible(find.byTooltip('Undo'));
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), before);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Hidden drawing keeps feedback and does not reopen the collapsed palette',
      (t) async {
    await board.open(t);
    await board.collapseTools(t);
    await toggle(t, 'Hide UI');
    final origin = t.getTopLeft(board.canvas);
    final drag = await t.startGesture(origin + const Offset(60, 100));
    await drag.moveTo(origin + const Offset(250, 100));
    await t.pump();
    expect(board.painter(t).preview.length, greaterThan(1));
    expect(board.painter(t).guides, isNotEmpty);
    expect(find.byTooltip('Show Tools'), findsOneWidget);
    for (final point in [
      const Offset(250, 250),
      const Offset(60, 250),
      const Offset(60, 100)
    ]) {
      await drag.moveTo(origin + point);
      await t.pump();
    }
    await drag.up();
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('drawingToolPalette')), findsNothing);
    await toggle(t, 'Show Tools');
    expect(find.byTooltip('Expand drawing tools'), findsOneWidget);
    await board.expandTools(t);
    expect(find.text('Straighten and refine this sketch?'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'A queued hide waits for both pinch fingers without changing geometry',
      (t) async {
    await board.open(t);
    await board.outline(t);
    await board.collapseTools(t);
    final before = board.painter(t).model.toJson();
    final origin = t.getTopLeft(board.canvas);
    final first =
        await t.startGesture(origin + const Offset(100, 300), pointer: 1);
    final second =
        await t.startGesture(origin + const Offset(200, 300), pointer: 2);
    await second.moveTo(origin + const Offset(240, 300));
    await t.pump();
    t
        .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.visibility_off_outlined))
        .onPressed!();
    await first.up();
    await t.pumpAndSettle();
    expect(find.byTooltip('Hide UI'), findsOneWidget);
    await second.up();
    await t.pumpAndSettle();
    expect(find.byTooltip('Show Tools'), findsOneWidget);
    expect(board.painter(t).model.toJson(), before);
    expect(board.painter(t).preview, isEmpty);
    expect(t.takeException(), isNull);
  });

  for (final size in [const Size(240, 420), const Size(740, 320)]) {
    testWidgets('Hide and restore tools at $size with enlarged text',
        (t) async {
      await board.open(t);
      t.view.physicalSize = size;
      t.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpAndSettle();
      await toggle(t, 'Hide UI');
      final button = t.getRect(find.byTooltip('Show Tools'));
      expect(button.width, greaterThanOrEqualTo(48));
      expect((Offset.zero & size).contains(button.center), isTrue);
      await toggle(t, 'Show Tools');
      expect(find.byTooltip('Collapse drawing tools'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
