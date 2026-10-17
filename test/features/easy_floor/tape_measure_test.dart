import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/drawing_painter.dart';
import 'drawing_screen_test.dart' as board;
import 'endpoint_connection_test.dart' show wall;
import 'annotation_interaction_test.dart' show undo;
import 'measurement_layout_test.dart' show paint;
import 'shape_interaction_test.dart' show menu;

Future<void> tape(WidgetTester t) async {
  await board.expandTools(t);
  await t.tap(find.byTooltip('Tape Measure'));
  await t.pumpAndSettle();
  await board.collapseTools(t);
}

double distance(WidgetTester t) {
  final value = board.painter(t).tape!;
  return (value.$2 - value.$1).length;
}

Future<void> measure(WidgetTester t, Offset start, Offset end) async {
  final origin = t.getTopLeft(board.canvas);
  final gesture = await t.startGesture(origin + start);
  await gesture.moveTo(origin + end);
  await t.pump();
  await gesture.up();
  await t.pumpAndSettle();
}

void main() {
  test(
      'Tape label avoids toolbar bounds and does not populate wall label targets',
      () {
    final model = WallNetwork()
      ..addPolyline([const DrawingPoint(0, 0), const DrawingPoint(2000, 0)]);
    final obstacles = [
      const Rect.fromLTWH(0, 0, 320, 100),
      const Rect.fromLTWH(0, 300, 320, 100)
    ];
    final wallLabels = <int, Rect>{};
    final view = DrawingPainter(
        model: model,
        origin: const Offset(40, 130),
        scale: .1,
        unit: DrawingUnit.metres,
        preview: [],
        showAllMeasurements: true,
        tape: (const DrawingPoint(0, 0), const DrawingPoint(1800, 800)),
        labelObstacles: obstacles,
        labelBounds: wallLabels);
    final before = model.toJson();
    paint(view);
    expect(view.tapeLabelBounds, isNotNull);
    for (final obstacle in obstacles) {
      expect(view.tapeLabelBounds!.overlaps(obstacle), isFalse);
    }
    expect(wallLabels, isEmpty);
    expect(model.toJson(), before);
  });
  testWidgets(
      'Tape survives unit changes and rotation; leaving during a drag is safe',
      (t) async {
    await board.open(t);
    await board.collapseTools(t);
    await wall(t, const Offset(60, 100), const Offset(260, 100));
    final geometry = board.painter(t).model.toJson();
    await tape(t);
    await measure(t, const Offset(80, 180), const Offset(200, 260));
    final previous = board.painter(t).tape;
    for (final unit in DrawingUnit.values) {
      await menu(t, 'Measurement unit', unit.name);
      expect(board.painter(t).unit, unit);
      expect(board.painter(t).tape, previous);
      expect(board.painter(t).model.toJson(), geometry);
    }
    for (final size in [const Size(240, 420), const Size(740, 360)]) {
      t.view.physicalSize = size;
      await t.pumpAndSettle();
      expect(board.painter(t).tape, previous);
      final rect = board.painter(t).tapeLabelBounds;
      if (rect != null) {
        expect((Offset.zero & t.getSize(board.canvas)).contains(rect.center),
            isTrue);
      }
      expect(t.takeException(), isNull);
    }
    t.view.physicalSize = const Size(320, 740);
    await t.pumpAndSettle();
    await board.collapseTools(t);
    final origin = t.getTopLeft(board.canvas);
    final drag = await t.startGesture(origin + const Offset(100, 360));
    await drag.moveBy(const Offset(60, 0));
    await t.pump();
    await board.expandTools(t);
    await t.tap(find.byTooltip('Tape Measure'));
    await t.pumpAndSettle();
    await drag.up();
    await t.pumpAndSettle();
    expect(board.painter(t).tape, isNull);
    expect(board.painter(t).model.toJson(), geometry);
    await undo(t, 'Undo');
    expect(board.painter(t).model.walls, isEmpty);
  });
  for (final delta in [
    const Offset(100, 0),
    const Offset(0, 100),
    const Offset(60, 80)
  ]) {
    testWidgets('Tape measures $delta live without walls or history',
        (t) async {
      await board.open(t);
      await tape(t);
      final before = board.painter(t).model.toJson();
      final scale = board.painter(t).scale;
      final origin = t.getTopLeft(board.canvas);
      final drag = await t.startGesture(origin + const Offset(80, 180));
      await drag.moveTo(origin + const Offset(80, 180) + delta);
      await t.pump();
      expect(distance(t), closeTo(delta.distance / scale, .001));
      expect(board.painter(t).tapeLabelBounds, isNotNull);
      await drag.up();
      await t.pumpAndSettle();
      expect(distance(t), closeTo(delta.distance / scale, .001));
      expect(board.painter(t).model.toJson(), before);
      await board.expandTools(t);
      expect(
          t
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Undo'))
              .onSelected,
          isNull);
      await t.tap(find.widgetWithText(ChoiceChip, 'Clear'));
      await t.pumpAndSettle();
      expect(board.painter(t).tape, isNull);
      expect(board.painter(t).model.toJson(), before);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
      'Tape snaps to corners and wall edges without reconnecting geometry',
      (t) async {
    await board.open(t);
    await board.collapseTools(t);
    await wall(t, const Offset(60, 100), const Offset(260, 100));
    final before = board.painter(t).model.toJson();
    await tape(t);
    await measure(t, const Offset(64, 104), const Offset(180, 106));
    expect(distance(t), closeTo(1200, .001));
    expect(board.painter(t).model.toJson(), before);
    await board.expandTools(t);
    await t.tap(find.byTooltip('Snap tape endpoints'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ChoiceChip, 'Clear'));
    await t.pumpAndSettle();
    await board.collapseTools(t);
    await measure(t, const Offset(64, 104), const Offset(180, 106));
    expect(distance(t), closeTo(const Offset(116, 2).distance * 10, .001));
    expect(board.painter(t).model.toJson(), before);
    await undo(t, 'Undo');
    expect(board.painter(t).model.walls, isEmpty);
  });
  testWidgets(
      'Tape handles adjust independently, cancel restores prior measurement',
      (t) async {
    await board.open(t);
    await tape(t);
    await measure(t, const Offset(80, 180), const Offset(200, 180));
    await measure(t, const Offset(80, 180), const Offset(80, 220));
    expect(distance(t), closeTo(const Offset(120, -40).distance * 10, .001));
    final previous = board.painter(t).tape;
    final origin = t.getTopLeft(board.canvas);
    final drag = await t.startGesture(origin + const Offset(200, 180));
    await drag.moveBy(const Offset(0, 80));
    await t.pump();
    await drag.cancel();
    await t.pumpAndSettle();
    expect(board.painter(t).tape, previous);
    expect(board.painter(t).model.walls, isEmpty);
  });
  testWidgets(
      'Second finger cancels tape edit and zoom never changes distances',
      (t) async {
    await board.open(t);
    await tape(t);
    await measure(t, const Offset(80, 180), const Offset(200, 180));
    final previous = board.painter(t).tape;
    final origin = t.getTopLeft(board.canvas);
    final first =
        await t.startGesture(origin + const Offset(80, 300), pointer: 1);
    await first.moveBy(const Offset(30, 0));
    await t.pump();
    final second =
        await t.startGesture(origin + const Offset(240, 300), pointer: 2);
    await first.moveBy(const Offset(-20, 20));
    await second.moveBy(const Offset(20, 20));
    await t.pump();
    expect(board.painter(t).tape, previous);
    await first.up();
    await second.up();
    await t.pumpAndSettle();
    expect(distance(t), closeTo(1200, .001));
    final scale = board.painter(t).scale;
    await measure(t, const Offset(40, 360), const Offset(140, 360));
    expect(distance(t), closeTo(100 / scale, .001));
    expect(board.painter(t).model.walls, isEmpty);
  });
  for (final unit in DrawingUnit.values) {
    test('Tape label renders in ${unit.symbol} at different zooms', () {
      for (final scale in [.05, .1, .2]) {
        final view = DrawingPainter(
            model: WallNetwork(),
            origin: const Offset(40, 80),
            scale: scale,
            unit: unit,
            preview: [],
            tape: (const DrawingPoint(0, 0), const DrawingPoint(600, 800)));
        paint(view);
        expect(view.tapeLabelBounds, isNotNull);
        expect(
            (Offset.zero & const Size(320, 400))
                .contains(view.tapeLabelBounds!.center),
            isTrue);
      }
    });
  }
}
