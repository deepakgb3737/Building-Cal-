import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_resize.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/wall_resize_options.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/dimension_dialog.dart';
import 'drawing_screen_test.dart' as board;

Future<int> selectFirst(WidgetTester t) async {
  await board.open(t);
  await board.outline(t);
  final view = board.painter(t), wall = view.model.walls.values.first;
  await t.tapAt(t.getTopLeft(board.canvas) +
      (view.screen(view.model.corners[wall.start]!) +
              view.screen(view.model.corners[wall.end]!)) /
          2);
  await t.pumpAndSettle();
  return wall.id;
}

void main() {
  testWidgets('Exact dimension dialog applies chosen fixed endpoint',
      (t) async {
    final id = await selectFirst(t);
    final before = board.painter(t).model;
    final wall = before.walls[id]!,
        end = before.corners[before.walls[id]!.end]!;
    await board.moreWallOptions(t);
    await t.ensureVisible(find.text('Resize options'));
    await t.tap(find.text('Resize options'));
    await t.pumpAndSettle();
    expect(
        find.text('How would you like to resize this wall?'), findsOneWidget);
    await t.ensureVisible(find.byType(WallResizeOptions));
    await t.tap(find.byType(WallResizeOptions));
    await t.pumpAndSettle();
    await t.tap(find.text(WallResizeAnchor.end.label).last);
    await t.pumpAndSettle();
    await t.enterText(
        find
            .descendant(
                of: find.byType(DimensionDialog),
                matching: find.byType(TextFormField))
            .first,
        '2.4');
    await t.tap(find.text('Apply'));
    await t.pumpAndSettle();
    final edited = board.painter(t).model;
    expect(edited.length(id), closeTo(2400, .001));
    expect((edited.corners[wall.end]! - end).length, lessThan(.001));
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Centered drag length keeps midpoint fixed and cancel restores endpoints',
      (t) async {
    final id = await selectFirst(t);
    final original = board.painter(t).model.toJson();
    final view = board.painter(t), wall = view.model.walls[id]!;
    final center =
        (view.model.corners[wall.start]! + view.model.corners[wall.end]!) * .5;
    final at = t.getTopLeft(board.canvas) + view.screen(center);
    await board.moreWallOptions(t);
    await t.ensureVisible(find.text('Drag length'));
    await t.tap(find.text('Drag length'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byType(WallResizeOptions));
    await t.tap(find.byType(WallResizeOptions));
    await t.pumpAndSettle();
    await t.tap(find.text(WallResizeAnchor.center.label).last);
    await t.pumpAndSettle();
    final drag = await t.startGesture(at);
    await drag.moveTo(at + const Offset(30, 0));
    await t.pump();
    final moving = board.painter(t).model;
    expect(moving.length(id), closeTo(2600, .001));
    expect(
        ((moving.corners[wall.start]! + moving.corners[wall.end]!) * .5 -
                center)
            .length,
        lessThan(.001));
    await drag.cancel();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), original);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Length-mode endpoint drag preserves opposite endpoint and wall direction',
      (t) async {
    final id = await selectFirst(t);
    final view = board.painter(t), wall = view.model.walls[id]!;
    final a = view.model.corners[wall.start]!,
        b = view.model.corners[wall.end]!;
    final end = t.getTopLeft(board.canvas) + view.screen(b);
    await board.moreWallOptions(t);
    await t.ensureVisible(find.text('Drag length'));
    await t.tap(find.text('Drag length'));
    await t.pumpAndSettle();
    final drag = await t.startGesture(end);
    await drag.moveTo(end + const Offset(20, 25));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    final edited = board.painter(t).model;
    expect(edited.length(id), closeTo(2200, .001));
    expect((edited.corners[wall.start]! - a).length, lessThan(.001));
    expect(edited.corners[wall.end]!.y, b.y);
    expect(find.text('How would you like to resize this wall?'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
