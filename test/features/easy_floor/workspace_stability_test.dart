import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'drawing_screen_test.dart' as board;
import 'advanced_interaction_test.dart' as editing;

Finder get palette => find.byKey(const ValueKey('drawingToolPalette'));

void main() {
  for (final collapsed in [false, true]) {
    testWidgets(
        'Cancelled ${collapsed ? 'collapsed' : 'expanded'} toolbar drag restores its position',
        (t) async {
      await board.open(t);
      if (collapsed) await board.collapseTools(t);
      final rect = t.getRect(palette), view = board.painter(t);
      final before = view.model.toJson();
      final drag = await t.startGesture(
          t.getCenter(find.byKey(const ValueKey('moveDrawingTools'))));
      await drag.moveBy(const Offset(0, -80));
      await t.pump();
      expect(t.getRect(palette), isNot(rect));
      await drag.cancel();
      await t.pumpAndSettle();
      expect(t.getRect(palette), rect);
      expect(board.painter(t).model.toJson(), before);
      expect(board.painter(t).origin, view.origin);
      expect(board.painter(t).scale, view.scale);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('Selection and expanded inspectors never push the toolbar away',
      (t) async {
    await board.open(t);
    await board.outline(t);
    final rect = t.getRect(palette), view = board.painter(t);
    final before = view.model.toJson();
    final wall = view.model.walls.values.first;
    await editing.selectWall(t, wall.id);
    expect(t.getRect(palette), rect);
    await board.moreWallOptions(t);
    expect(t.getRect(palette), rect);
    final context = find.ancestor(
        of: find.byType(ExpansionTile),
        matching:
            find.byWidgetPredicate((w) => w is Material && w.key is GlobalKey));
    expect(context, findsOneWidget);
    expect(t.getRect(context).overlaps(rect), isFalse);
    final at = t.getTopLeft(board.canvas) +
        view.screen(view.model.corners[wall.start]!);
    await t.tapAt(at);
    await t.pumpAndSettle();
    expect(t.getRect(palette), rect);
    expect(find.text('Selected corner'), findsOneWidget);
    await t.tapAt(t.getTopLeft(board.canvas) + const Offset(160, 140));
    await t.pumpAndSettle();
    expect(find.text('Connected shape · 4 walls'), findsOneWidget);
    expect(t.getRect(palette), rect);
    expect(board.painter(t).model.toJson(), before);
    expect(t.takeException(), isNull);
  });

  testWidgets('Cancel reuses the More slot without reflowing narrow tool rows',
      (t) async {
    await board.open(t);
    t.view.physicalSize = const Size(240, 740);
    t.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpAndSettle();
    final before = t.getRect(palette);
    final start = t.getTopLeft(board.canvas) + const Offset(50, 50);
    final drag = await t.startGesture(start);
    await drag.moveBy(const Offset(100, 0));
    await t.pump();
    expect(find.byTooltip('Cancel action'), findsOneWidget);
    expect(find.byTooltip('More drawing tools'), findsNothing);
    expect(t.getRect(palette), before);
    await drag.cancel();
    await t.pumpAndSettle();
    expect(find.byTooltip('More drawing tools'), findsOneWidget);
    expect(t.getRect(palette), before);
    expect(board.painter(t).model.walls, isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Large-text tools leave space for contextual editing on a narrow screen',
      (t) async {
    await board.open(t);
    await board.outline(t);
    final id = board.painter(t).model.walls.keys.first;
    t.view.physicalSize = const Size(240, 420);
    t.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpAndSettle();
    expect(t.getSize(palette).height,
        lessThanOrEqualTo(t.getSize(board.canvas).height / 2));
    await editing.selectWall(t, id);
    await t.ensureVisible(find.text('Lock length'));
    expect(find.text('Lock length').hitTestable(), findsOneWidget);
    await t.tap(find.text('Lock length'));
    await t.pumpAndSettle();
    expect(board.painter(t).model.isFixed(id), isTrue);
    expect(t.takeException(), isNull);
  });
}
