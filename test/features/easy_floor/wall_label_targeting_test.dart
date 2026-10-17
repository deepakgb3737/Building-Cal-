import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/drawing_painter.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/dimension_dialog.dart';
import 'drawing_screen_test.dart' as board;
import 'advanced_interaction_test.dart' as editing;

void main() {
  const first = Rect.fromLTWH(20, 20, 40, 20);
  const second = Rect.fromLTWH(70, 20, 40, 20);
  test(
      'Overlapping enlarged label targets choose the nearest, not the first entry',
      () {
    for (final labels in [
      {1: first, 2: second},
      {2: second, 1: first}
    ]) {
      expect(nearestWallLabel(labels, const Offset(65.5, 30), padding: 6), 2);
      expect(nearestWallLabel(labels, const Offset(64.5, 30), padding: 6), 1);
      expect(
          nearestWallLabel(labels, const Offset(65.5, 30),
              padding: 6, preferredWall: 1),
          2);
    }
  });

  test('Equal-distance labels keep the selected wall, otherwise use stable IDs',
      () {
    for (final labels in [
      {1: first, 2: second},
      {2: second, 1: first}
    ]) {
      expect(nearestWallLabel(labels, const Offset(65, 30), padding: 6), 1);
      expect(
          nearestWallLabel(labels, const Offset(65, 30),
              padding: 6, preferredWall: 2),
          2);
    }
  });

  test('Direct label hits and screen-sized tolerance remain distinct', () {
    final labels = {1: first, 2: second};
    expect(nearestWallLabel(labels, const Offset(65, 30)), isNull);
    expect(nearestWallLabel(labels, const Offset(65, 30), padding: 6), 1);
    expect(nearestWallLabel(labels, const Offset(75, 30), preferredWall: 1), 2);
    expect(nearestWallLabel(labels, const Offset(117, 30), padding: 6), isNull);
    const shift = Offset(300, -10);
    expect(
        nearestWallLabel({
          for (final e in labels.entries) e.key: e.value.shift(shift)
        }, const Offset(65.5, 30) + shift, padding: 6),
        2);
    expect(labels, {1: first, 2: second});
  });

  testWidgets('A stale deleted-wall label cannot open a dimension editor',
      (t) async {
    await board.open(t);
    await board.outline(t);
    await board.collapseTools(t);
    final id = board.painter(t).model.walls.keys.first;
    await editing.selectWall(t, id);
    await t.tap(find.byTooltip('Delete selected geometry'));
    await t.pumpAndSettle();
    final view = board.painter(t);
    expect(view.model.walls.containsKey(id), isFalse);
    // Simulate a pointer arriving before the post-deletion paint refreshes the cache.
    view.labelBounds![id] = const Rect.fromLTWH(25, 300, 60, 20);
    final before = view.model.toJson();
    await t.tapAt(t.getTopLeft(board.canvas) + const Offset(55, 310));
    await t.pumpAndSettle();
    expect(find.byType(DimensionDialog), findsNothing);
    expect(board.painter(t).model.toJson(), before);
    expect(t.takeException(), isNull);
  });
}
