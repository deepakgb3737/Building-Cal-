import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/drawing_tool_palette.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'drawing_screen_test.dart' as board;

Finder get palette => find.byKey(const ValueKey('drawingToolPalette'));
Finder get handle => find.byKey(const ValueKey('moveDrawingTools'));

void main() {
  testWidgets(
      'Floating tools reserve no canvas space and collapse to a small handle',
      (t) async {
    await board.open(t);
    final bounds = t.getRect(board.canvas);
    expect(bounds.height, greaterThan(600));
    expect(t.getSize(palette).width, lessThanOrEqualTo(bounds.width));
    await board.collapseTools(t);
    expect(t.getSize(palette), const Size(96, 48));
    expect(t.getRect(board.canvas), bounds);
    expect(find.text('Wall'), findsNothing);
    await board.expandTools(t);
    expect(t.getRect(board.canvas), bounds);
    expect(find.text('Wall'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Moving and clamping the palette never changes geometry or camera',
      (t) async {
    await board.open(t);
    await board.outline(t);
    final view = board.painter(t), before = view.model.toJson();
    final start = t.getTopLeft(palette);
    await t.drag(handle, const Offset(-70, -120));
    await t.pumpAndSettle();
    expect(
        (t.getTopLeft(palette) -
                Offset(
                    (start.dx - 70)
                        .clamp(t.getTopLeft(board.canvas).dx, double.infinity),
                    start.dy - 120))
            .distance,
        lessThan(.001));
    expect(board.painter(t).origin, view.origin);
    expect(board.painter(t).scale, view.scale);
    expect(board.painter(t).model.toJson(), before);
    await t.drag(handle, const Offset(-2000, -2000));
    await t.pumpAndSettle();
    expect(t.getTopLeft(palette), t.getTopLeft(board.canvas));
    await t.ensureVisible(find.byTooltip('Undo'));
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(board.painter(t).model.walls, isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Sketch review is accessible without reopening the collapsed tools',
      (t) async {
    await board.open(t);
    await board.collapseTools(t);
    final origin = t.getTopLeft(board.canvas);
    final stroke = await t.startGesture(origin + const Offset(60, 60));
    for (final point in [
      const Offset(260, 60),
      const Offset(260, 220),
      const Offset(60, 220),
      const Offset(60, 60)
    ]) {
      await stroke.moveTo(origin + point);
      await t.pump();
    }
    await stroke.up();
    await t.pumpAndSettle();
    expect(find.byTooltip('Expand drawing tools'), findsOneWidget);
    expect(find.text('Straighten and refine this sketch?'), findsOneWidget);
    expect(find.text('Keep Original').hitTestable(), findsOneWidget);
    await board.expandTools(t);
    expect(find.text('Straighten and refine this sketch?'), findsOneWidget);
    expect(find.byTooltip('Collapse drawing tools'), findsOneWidget);
    expect(board.painter(t).model.walls, isEmpty);
    await board.collapseTools(t);
    await t.tap(find.text('Yes, Straighten'));
    await t.pumpAndSettle();
    expect(find.byTooltip('Expand drawing tools'), findsOneWidget);
    await t.tap(find.text('Accept refinement'));
    await t.pumpAndSettle();
    expect(board.painter(t).model.walls.length, 4);
    expect(find.text('Accept refinement'), findsNothing);
    expect(find.byTooltip('Expand drawing tools'), findsOneWidget);
  });

  testWidgets(
      'Palette stays inside tiny and landscape viewports with large text',
      (t) async {
    await board.open(t);
    for (final size in [
      const Size(240, 420),
      const Size(740, 320),
      const Size(320, 640)
    ]) {
      t.view.physicalSize = size;
      t.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpAndSettle();
      final canvas = t.getRect(board.canvas), tools = t.getRect(palette);
      expect(canvas.contains(tools.topLeft), isTrue);
      expect(canvas.right, greaterThanOrEqualTo(tools.right));
      expect(canvas.bottom, greaterThanOrEqualTo(tools.bottom));
      await board.collapseTools(t);
      await board.expandTools(t);
      expect(t.takeException(), isNull);
    }
  });

  testWidgets(
      'Palette controls scroll and dragging is isolated from background gestures',
      (t) async {
    var backgroundTaps = 0, interactions = 0;
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: LayoutBuilder(
              builder: (_, bounds) => Stack(children: [
                    Positioned.fill(
                        child: GestureDetector(
                            onTap: () => backgroundTaps++,
                            behavior: HitTestBehavior.opaque)),
                    DrawingToolPalette(
                        viewport: bounds.biggest,
                        onInteract: () => interactions++,
                        child: Column(children: [
                          for (var i = 0; i < 20; i++)
                            TextButton(onPressed: () {}, child: Text('Tool $i'))
                        ])),
                  ])),
        )));
    await t.ensureVisible(find.text('Tool 19'));
    await t.tap(find.text('Tool 19'));
    await t.drag(handle, const Offset(-60, -60));
    await t.pumpAndSettle();
    expect(interactions, 1);
    expect(backgroundTaps, 0);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Moving tools cancels an unfinished stroke rather than committing it',
      (t) async {
    await board.open(t);
    final origin = t.getTopLeft(board.canvas);
    final drawing =
        await t.startGesture(origin + const Offset(50, 80), pointer: 1);
    await drawing.moveTo(origin + const Offset(200, 80));
    await t.pump();
    final moving = await t.startGesture(t.getCenter(handle), pointer: 2);
    await moving.moveBy(const Offset(-40, -50));
    await t.pump();
    await moving.up();
    await drawing.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.walls, isEmpty);
    expect(board.painter(t).preview, isEmpty);
    expect(t.takeException(), isNull);
  });
}
