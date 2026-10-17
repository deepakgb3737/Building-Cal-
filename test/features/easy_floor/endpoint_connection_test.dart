import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'drawing_screen_test.dart' as board;

Future<void> wall(WidgetTester t, Offset a, Offset b) async {
  final offset = t.getTopLeft(board.canvas);
  final drag = await t.startGesture(offset + a);
  await drag.moveTo(offset + b);
  await t.pump();
  await drag.up();
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
      'Drawing a new wall near an endpoint previews a shared connection',
      (t) async {
    await board.open(t);
    await board.tool(t, 'Wall');
    await board.collapseTools(t);
    await wall(t, const Offset(60, 100), const Offset(140, 100));
    final offset = t.getTopLeft(board.canvas);
    final drag = await t.startGesture(offset + const Offset(220, 180));
    await drag.moveTo(offset + const Offset(151, 108));
    await t.pump();
    final preview = board.painter(t);
    expect(preview.connection, isNotNull);
    final existing = preview.model.walls.values.single.end;
    await drag.up();
    await t.pumpAndSettle();
    final model = board.painter(t).model;
    expect(model.walls.length, 2);
    expect(model.corners.length, 3);
    expect(
        model.walls.values
            .every((w) => w.start == existing || w.end == existing),
        isTrue);
    expect(t.takeException(), isNull);
  });
  for (final scale in [.02, .1, 1.0]) {
    for (final delta in [
      const Offset(100, 0),
      const Offset(0, 100),
      const Offset(100, 100)
    ]) {
      test('Connections retain shared topology at scale $scale along $delta',
          () {
        DrawingPoint p(double x, double y) =>
            DrawingPoint(x / scale, y / scale);
        final model = WallNetwork()
          ..addPolyline([p(0, 0), p(delta.dx, delta.dy)])
          ..addPolyline([p(250, 200), p(250, 300)]);
        final moving = model.walls.values.last.end;
        final target = model.corners[model.walls.values.first.end]!;
        final snapped =
            model.snap(target + p(5, 5), 16 / scale, excludeCorner: moving);
        model.moveCorners({moving: snapped}, join: true);
        final shared = model.nearestCorner(snapped, .001)!;
        expect(model.corners.length, 3);
        expect(
            model.walls.values
                .where((w) => w.start == shared || w.end == shared)
                .length,
            2);
        final linked = model.walls.values.map((w) => w.id).toList();
        model.moveCorners({shared: snapped + p(0, -20)}, join: true);
        expect(
            model.walls.values
                .every((w) => w.start == shared || w.end == shared),
            isTrue);
        expect(model.walls.keys, containsAll(linked));
        final far = p(400, 400);
        expect(
            (model.snap(far, 16 / scale, excludeCorner: shared) - far).length,
            0);
      });
    }
  }
  for (final junction in [false, true]) {
    testWidgets(
        'Endpoint drag previews and commits a shared ${junction ? 'junction' : 'corner'}',
        (t) async {
      await board.open(t);
      await board.tool(t, 'Wall');
      await board.collapseTools(t);
      await wall(t, const Offset(60, 100), const Offset(140, 100));
      await wall(t, const Offset(220, 180), const Offset(270, 230));
      var view = board.painter(t);
      final original = view.model.toJson();
      final moving = view.model.walls.values.last.end;
      final offset = t.getTopLeft(board.canvas);
      await t.tapAt(offset + view.screen(view.model.corners[moving]!));
      await t.pumpAndSettle();
      final drag = await t
          .startGesture(offset + view.screen(view.model.corners[moving]!));
      await drag.moveBy(const Offset(0, 25));
      await t.pump();
      expect(board.painter(t).connection, isNull);
      await drag.moveTo(offset +
          (junction ? const Offset(100, 112) : const Offset(151, 108)));
      await t.pump();
      view = board.painter(t);
      expect(view.connection, isNotNull);
      final connectedAt = view.connection!;
      await drag.up();
      await t.pumpAndSettle();
      view = board.painter(t);
      final shared = view.model.nearestCorner(connectedAt, .001)!;
      expect(
          view.model.walls.values
              .where((w) => w.start == shared || w.end == shared)
              .length,
          junction ? 3 : 2);
      expect(view.model.corners.length, junction ? 4 : 3);
      final joined = view.model.toJson();
      final move = await t
          .startGesture(offset + view.screen(view.model.corners[shared]!));
      await move.moveBy(const Offset(0, -30));
      await t.pump();
      expect(board.painter(t).model.toJson(), isNot(joined));
      await move.cancel();
      await t.pumpAndSettle();
      expect(board.painter(t).model.toJson(), joined);
      await board.expandTools(t);
      await t.ensureVisible(find.byTooltip('Undo'));
      await t.tap(find.byTooltip('Undo'));
      await t.pumpAndSettle();
      expect(board.painter(t).model.toJson(), original);
      await t.ensureVisible(find.byTooltip('Redo'));
      await t.tap(find.byTooltip('Redo'));
      await t.pumpAndSettle();
      expect(board.painter(t).model.toJson(), joined);
      expect(t.takeException(), isNull);
    });
  }
}
