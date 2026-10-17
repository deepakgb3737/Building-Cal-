import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/easy_floor_screen.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/dimension_dialog.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'drawing_screen_test.dart' as board;
import 'endpoint_connection_test.dart' show wall;
import 'annotation_interaction_test.dart' show undo;

Future<void> open(WidgetTester t,
    {double density = 1, double threshold = 8}) async {
  t.view.devicePixelRatio = density;
  t.view.physicalSize = Size(320 * density, 740 * density);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  await t.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: EasyFloorScreen(drawingMovementThreshold: threshold)));
  await t.pumpAndSettle();
  await board.tool(t, 'Wall');
  await board.collapseTools(t);
}

void clean(WidgetTester t) {
  final v = board.painter(t);
  expect(v.model.walls, isEmpty);
  expect(v.preview, isEmpty);
  expect(v.rawStroke, isEmpty);
  expect(find.text('Straighten and refine this sketch?'), findsNothing);
  expect(t.takeException(), isNull);
}

void main() {
  for (final kind in [
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus
  ]) {
    for (final density in [1.0, 3.0]) {
      testWidgets(
          '$kind at DPR $density: taps and jitter never create walls or history',
          (t) async {
        await open(t, density: density);
        final at = t.getTopLeft(board.canvas) + const Offset(120, 300);
        await t.tapAt(at, kind: kind);
        await t.pumpAndSettle();
        clean(t);
        final drag = await t.startGesture(at, kind: kind);
        for (final delta in [
          const Offset(3, 2),
          const Offset(-4, 1),
          const Offset(6, 2),
          const Offset(-3, -3),
          const Offset(1, 0)
        ]) {
          await drag.moveTo(at + delta);
          await t.pump();
          expect(board.painter(t).preview, isEmpty);
          expect(board.painter(t).model.walls, isEmpty);
        }
        await drag.up();
        await t.pumpAndSettle();
        clean(t);
        await board.expandTools(t);
        expect(
            t
                .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Undo'))
                .onSelected,
            isNull);
      });
    }
  }

  for (final factor in [.5, 1.0, 2.0]) {
    testWidgets(
        'Short intentional stroke at zoom $factor previews then commits once, with Undo/Redo',
        (t) async {
      await open(t);
      final origin = t.getTopLeft(board.canvas);
      if (factor != 1) {
        final first =
            await t.startGesture(origin + const Offset(120, 280), pointer: 1);
        final second =
            await t.startGesture(origin + const Offset(200, 280), pointer: 2);
        await first.moveTo(origin + Offset(160 - 40 * factor, 280));
        await second.moveTo(origin + Offset(160 + 40 * factor, 280));
        await t.pump();
        await second.up();
        await first.up();
        await t.pumpAndSettle();
        clean(t);
      }
      final scale = board.painter(t).scale;
      final at = origin + const Offset(100, 400);
      final drag = await t.startGesture(at);
      await drag.moveTo(at + const Offset(10, 0));
      await t.pump();
      expect(board.painter(t).model.walls, isEmpty);
      expect(board.painter(t).preview.length, 2);
      await drag.up();
      await t.pumpAndSettle();
      final model = board.painter(t).model;
      expect(model.walls.length, 1);
      expect(model.length(model.walls.keys.single), closeTo(10 / scale, .001));
      final after = model.toJson();
      await undo(t, 'Undo');
      clean(t);
      await undo(t, 'Redo');
      expect(board.painter(t).model.toJson(), after);
    });
  }

  testWidgets(
      'Configurable threshold rejects a short drag but accepts deliberate movement',
      (t) async {
    await open(t, threshold: 14);
    final at = t.getTopLeft(board.canvas) + const Offset(100, 300);
    final small = await t.startGesture(at);
    await small.moveTo(at + const Offset(12, 0));
    await small.up();
    await t.pumpAndSettle();
    clean(t);
    await wall(t, const Offset(100, 400), const Offset(116, 400));
    expect(board.painter(t).model.walls.length, 1);
  });

  testWidgets(
      'Returning a single-wall stroke to a tiny result does not commit it',
      (t) async {
    await open(t);
    final at = t.getTopLeft(board.canvas) + const Offset(100, 300);
    final drag = await t.startGesture(at);
    await drag.moveTo(at + const Offset(60, 0));
    await t.pump();
    expect(board.painter(t).preview.length, 2);
    await drag.moveTo(at + const Offset(2, 0));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    clean(t);
  });

  for (final interrupted in [false, true]) {
    testWidgets(
        '${interrupted ? 'Second finger' : 'Pointer cancellation'} discards preview without history',
        (t) async {
      await open(t);
      final origin = t.getTopLeft(board.canvas);
      final first =
          await t.startGesture(origin + const Offset(100, 300), pointer: 1);
      await first.moveTo(origin + const Offset(180, 330));
      await t.pump();
      expect(board.painter(t).preview.length, 2);
      if (interrupted) {
        final second =
            await t.startGesture(origin + const Offset(240, 300), pointer: 2);
        await t.pump();
        expect(board.painter(t).preview, isEmpty);
        await second.moveBy(const Offset(10, 10));
        await second.up();
        await first.moveTo(origin + const Offset(100, 400));
        await first.up();
      } else {
        await first.cancel();
      }
      await t.pumpAndSettle();
      clean(t);
      await wall(t, const Offset(100, 420), const Offset(180, 420));
      expect(board.painter(t).model.walls.length, 1);
    });
  }

  testWidgets(
      'Wall/corner jitter, toolbar actions and dimension editing cannot add walls',
      (t) async {
    await open(t);
    await wall(t, const Offset(60, 300), const Offset(240, 300));
    final before = board.painter(t).model.toJson();
    final origin = t.getTopLeft(board.canvas);
    for (final at in [const Offset(60, 300), const Offset(150, 300)]) {
      final drag =
          await t.startGesture(origin + at, kind: PointerDeviceKind.mouse);
      await drag.moveBy(const Offset(3, 2));
      await drag.up();
      await t.pumpAndSettle();
      expect(board.painter(t).model.toJson(), before);
    }
    await board.expandTools(t);
    await t.tap(find.byTooltip('Hide labels'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Show labels'));
    await t.pumpAndSettle();
    await t.tapAt(origin + const Offset(150, 300));
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), before);
    await t.tap(find.text('Enter length'));
    await t.pumpAndSettle();
    expect(find.byType(DimensionDialog), findsOneWidget);
    await t.enterText(find.byType(TextFormField), '2.25');
    await t.tap(find.text('Apply'));
    await t.pumpAndSettle();
    expect(board.painter(t).model.walls.length, 1);
  });

  testWidgets('App interruption cancels the stroke and allows the next drawing',
      (t) async {
    await open(t);
    final origin = t.getTopLeft(board.canvas);
    final drag = await t.startGesture(origin + const Offset(100, 300));
    await drag.moveBy(const Offset(70, 20));
    await t.pump();
    expect(board.painter(t).preview.length, 2);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await t.pumpAndSettle();
    clean(t);
    await drag.up();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    await wall(t, const Offset(100, 420), const Offset(180, 420));
    expect(board.painter(t).model.walls.length, 1);
  });
}
