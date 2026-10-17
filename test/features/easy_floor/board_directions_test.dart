import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/board_directions.dart';
import 'drawing_screen_test.dart' as board;

void orientation(WidgetTester t) {
  final n = t.getCenter(find.text('N')), s = t.getCenter(find.text('S'));
  final e = t.getCenter(find.text('E')), w = t.getCenter(find.text('W'));
  expect(n.dy, lessThan(s.dy));
  expect(n.dx, closeTo(s.dx, .001));
  expect(w.dx, lessThan(e.dx));
  expect(w.dy, closeTo(e.dy, .001));
  expect(find.text('Plan axes'), findsOneWidget);
}

void main() {
  testWidgets(
      'Plan directions ignore touches and stay fixed through drawing, navigation and Hide UI',
      (t) async {
    await board.open(t);
    await board.collapseTools(t);
    final indicator = find.byType(BoardDirections);
    final original = t.getRect(indicator);
    orientation(t);
    final ignored = t.widget<IgnorePointer>(
        find.descendant(of: indicator, matching: find.byType(IgnorePointer)));
    expect(ignored.ignoring, isTrue);
    final draw = await t.startGesture(original.center);
    await draw.moveBy(const Offset(140, 0));
    await t.pump();
    await draw.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.walls.length, 1);
    expect(t.getRect(indicator), original);
    final geometry = board.painter(t).model.toJson();
    final offset = t.getTopLeft(board.canvas);
    final a = await t.startGesture(offset + const Offset(100, 260), pointer: 1);
    final b = await t.startGesture(offset + const Offset(220, 260), pointer: 2);
    await a.moveBy(const Offset(20, 20));
    await b.moveBy(const Offset(20, 20));
    await t.pump();
    expect(t.getRect(indicator), original);
    await a.moveBy(const Offset(-25, 0));
    await b.moveBy(const Offset(25, 0));
    await t.pump();
    expect(t.getRect(indicator), original);
    orientation(t);
    await a.up();
    await b.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), geometry);
    await t.tap(find.byTooltip('Hide UI'));
    await t.pumpAndSettle();
    expect(t.getRect(indicator), original);
    orientation(t);
    await t.tap(find.byTooltip('Show Tools'));
    await t.pumpAndSettle();
    expect(t.getRect(indicator), original);
    expect(board.painter(t).model.toJson(), geometry);
    expect(t.takeException(), isNull);
  });

  for (final size in [const Size(240, 420), const Size(740, 360)]) {
    testWidgets(
        'Fixed plan reference fits $size with enlarged text in both modes',
        (t) async {
      await board.open(t);
      t.view.physicalSize = size;
      t.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpAndSettle();
      for (final control in ['Hide UI', 'Show Tools']) {
        orientation(t);
        final viewport = t.getRect(board.canvas),
            rect = t.getRect(find.byType(BoardDirections));
        expect(viewport.contains(rect.topLeft), isTrue);
        expect(viewport.contains(rect.bottomRight), isTrue);
        await t.tap(find.byTooltip(control));
        await t.pumpAndSettle();
      }
      expect(board.painter(t).model.walls, isEmpty);
      expect(t.takeException(), isNull);
    });
  }
}
