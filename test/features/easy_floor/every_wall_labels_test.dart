import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/floor_document.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/dimension_dialog.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/drawing_painter.dart';
import 'drawing_screen_test.dart' as board;
import 'natural_drawing_test.dart' as drawing;
import 'measurement_layout_test.dart' as layout;

void main() {
  test(
      'New plans show essential labels; both saved visibility choices are respected',
      () {
    expect(const DocumentSettings().showLabels, isTrue);
    final saved = const DocumentSettings(showLabels: false).toJson();
    expect(DocumentSettings.fromJson(saved).showLabels, isFalse);
    expect(
        DocumentSettings.fromJson(
                const DocumentSettings(showLabels: true).toJson())
            .showLabels,
        isTrue);
  });

  test('Crowded short-wall label uses clear space beyond the local search', () {
    final model = WallNetwork()
      ..addPolyline(
          [const DrawingPoint(1500, 1500), const DrawingPoint(1600, 1500)]);
    final bounds = <int, Rect>{};
    final painter = DrawingPainter(
        model: model,
        origin: Offset.zero,
        scale: .1,
        unit: DrawingUnit.mm,
        preview: [],
        selectedWall: model.walls.keys.single,
        labelBounds: bounds,
        labelObstacles: [const Rect.fromLTWH(0, 0, 320, 300)]);
    layout.paint(painter);
    expect(bounds.keys.toSet(), model.walls.keys.toSet());
    expect(bounds.values.single.top, greaterThanOrEqualTo(300));
  });

  testWidgets(
      'Every segment label follows partitions, diagonals, corner moves and resizing',
      (t) async {
    await board.open(t);
    await board.outline(t);
    await board.collapseTools(t);
    var view = board.painter(t);
    expect(view.labelBounds!.length, 2);
    await drawing.stroke(t, const [Offset(160, 60), Offset(160, 220)],
        hold: true);
    view = board.painter(t);
    expect(view.model.walls.length, 7);
    expect(view.labelBounds!.keys.toSet(), view.model.walls.keys.toSet());
    // Keep the new stroke clear of the now-interactive measurement labels.
    await drawing.stroke(t, const [Offset(40, 340), Offset(60, 370)]);
    view = board.painter(t);
    final diagonal = view.model.walls.keys.last;
    expect(view.model.walls.length, 8);
    expect(view.labelBounds!.keys.toSet(), view.model.walls.keys.toSet());
    await t.tap(find.byTooltip('Hide UI'));
    await t.pumpAndSettle();
    view = board.painter(t);
    final corner = view.model.corners.keys.first;
    final drag = await t.startGesture(
        t.getTopLeft(board.canvas) + view.screen(view.model.corners[corner]!));
    await drag.moveBy(const Offset(-10, -20));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    view = board.painter(t);
    expect(view.labelBounds!.keys.toSet(), view.model.walls.keys.toSet());
    final ids = view.model.walls.keys.toList();
    for (final id in ids) {
      view = board.painter(t);
      final rect = view.labelBounds![id]!;
      await t.tapAt(t.getTopLeft(board.canvas) + rect.center);
      await t.pumpAndSettle();
      expect(t.widget<DimensionDialog>(find.byType(DimensionDialog)).valueMm,
          closeTo(view.model.length(id), .000001));
      if (id == diagonal) {
        final desired = view.model.length(id) + 100;
        await t.enterText(find.byType(TextFormField), view.unit.input(desired));
        await t.tap(find.text('Apply'));
        await t.pumpAndSettle();
        expect(board.painter(t).model.length(id), closeTo(desired, .000001));
      } else {
        await t.tap(find.text('Cancel'));
      }
      await t.pumpAndSettle();
    }
    view = board.painter(t);
    expect(view.labelBounds!.keys.toSet(), view.model.walls.keys.toSet());
    expect(t.takeException(), isNull);
  });
}
