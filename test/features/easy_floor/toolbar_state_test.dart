import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/drawing_tool_palette.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'drawing_screen_test.dart' as board;
import 'natural_drawing_test.dart' as natural;
import 'shape_interaction_test.dart' as shapes;

void collapsed() {
  expect(find.byTooltip('Expand drawing tools'), findsOneWidget);
  expect(find.byTooltip('Collapse drawing tools'), findsNothing);
}

void main() {
  testWidgets(
      'Rebuilds, content changes and Hide UI preserve expansion and instance',
      (t) async {
    Future<void> show({bool review = false, bool hidden = false}) =>
        t.pumpWidget(MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
                body: Stack(children: [
              Offstage(
                  offstage: hidden,
                  child: Stack(children: [
                    DrawingToolPalette(
                      viewport: const Size(320, 600),
                      onInteract: () {},
                      primaryControls:
                          review ? null : const Text('Primary controls'),
                      child: Text(review ? 'Sketch review' : 'Drawing tools'),
                    )
                  ])),
            ]))));
    await show();
    final state = t.state(find.byType(DrawingToolPalette));
    await board.collapseTools(t);
    final position =
        t.getTopLeft(find.byKey(const ValueKey('drawingToolPalette')));
    for (var i = 0; i < 6; i++) {
      await show(review: i.isEven);
      collapsed();
      expect(t.getTopLeft(find.byKey(const ValueKey('drawingToolPalette'))),
          position);
      expect(t.state(find.byType(DrawingToolPalette)), same(state));
    }
    await show(hidden: true, review: true);
    expect(find.byTooltip('Expand drawing tools'), findsNothing);
    await show(review: true);
    collapsed();
    await board.expandTools(t);
    for (var i = 0; i < 4; i++) {
      await show(review: i.isEven);
      expect(find.byTooltip('Collapse drawing tools'), findsOneWidget);
    }
    await show(hidden: true);
    await show();
    expect(find.byTooltip('Collapse drawing tools'), findsOneWidget);
    expect(t.state(find.byType(DrawingToolPalette)), same(state));
  });

  testWidgets(
      'Repeated walls, corner edits, hide/show and rotation never reopen tools',
      (t) async {
    await board.open(t);
    await board.collapseTools(t);
    for (var i = 0; i < 3; i++) {
      await natural.stroke(
          t, [Offset(60, 60.0 + i * 40), Offset(240, 60.0 + i * 40)],
          finish: false);
      collapsed();
    }
    expect(board.painter(t).model.walls.length, 3);
    final v = board.painter(t);
    final corner = v.model.corners.values.first;
    final at = t.getTopLeft(board.canvas) + v.screen(corner);
    await t.dragFrom(at, const Offset(-20, -10));
    await t.pumpAndSettle();
    collapsed();
    await t.tap(find.byTooltip('Hide UI'));
    await t.pumpAndSettle();
    for (final size in [const Size(740, 360), const Size(320, 740)]) {
      t.view.physicalSize = size;
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('drawingToolPalette')), findsNothing);
      expect(find.byTooltip('Show Tools'), findsOneWidget);
    }
    await t.tap(find.byTooltip('Show Tools'));
    await t.pumpAndSettle();
    collapsed();
    for (final size in [const Size(740, 360), const Size(320, 740)]) {
      t.view.physicalSize = size;
      await t.pumpAndSettle();
      collapsed();
    }
    await board.expandTools(t);
    expect(find.byTooltip('Collapse drawing tools'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Preset resizing and placement keep the user chosen toolbar state',
      (t) async {
    await board.open(t);
    await shapes.menu(t, 'Shape presets', 'Rectangle');
    await t.tap(find.text('Preview'));
    await t.pumpAndSettle();
    expect(find.byTooltip('Collapse drawing tools'), findsOneWidget);
    await board.collapseTools(t);
    final view = board.painter(t);
    final handle = t.getTopLeft(board.canvas) + view.screen(view.presetHandle!);
    await t.dragFrom(handle, const Offset(25, 20));
    await t.pumpAndSettle();
    collapsed();
    expect(board.painter(t).preview, isNotEmpty);
    await board.expandTools(t);
    await t.ensureVisible(find.text('Place shape'));
    await t.tap(find.text('Place shape'));
    await t.pumpAndSettle();
    expect(find.byTooltip('Collapse drawing tools'), findsOneWidget);
    expect(board.painter(t).model.walls.length, 4);
    await board.collapseTools(t);
    await t.tap(find.byTooltip('Plan actions'));
    await t.pumpAndSettle();
    await t.tap(find.text('Select all'));
    await t.pumpAndSettle();
    collapsed();
    t.view.physicalSize = const Size(740, 360);
    await t.pumpAndSettle();
    collapsed();
    expect(t.takeException(), isNull);
  });
}
