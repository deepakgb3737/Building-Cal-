import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_history.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'drawing_screen_test.dart' as board;
import 'natural_drawing_test.dart' as drawing;

void main() {
  test(
      'Midpoint versus endpoint targeting is stable for diagonal walls and zoom levels',
      () {
    const p = DrawingPoint.new;
    for (final scale in [.02, .1, 1.0]) {
      for (final direction in [p(1, 0), p(0, 1), p(.6, .8)]) {
        final model = WallNetwork()
          ..addPolyline([p(0, 0), direction * (24 / scale)]);
        final wall = model.walls.values.single;
        final before = model.toJson();
        final normal = p(-direction.y, direction.x);
        ({int? corner, int? wall}) hit(DrawingPoint point) =>
            model.hitTest(point,
                cornerRadius: 22 / scale,
                wallRadius: 16 / scale,
                endpointRadius: 6 / scale);
        final middle = hit(direction * (12 / scale) + normal * (2 / scale));
        expect(middle.corner, isNull);
        expect(middle.wall, wall.id);
        expect(hit(direction * (2 / scale)).corner, wall.start);
        expect(hit(direction * (22 / scale)).corner, wall.end);
        expect(hit(normal * (100 / scale)).wall, isNull);
        expect(model.toJson(), before);
      }
    }
  });

  test('Shared T and cross junction corners retain priority over nearby walls',
      () {
    const p = DrawingPoint.new;
    final model = WallNetwork()..addPolyline([p(0, 0), p(3000, 0)]);
    model.addPolyline([p(1500, -1500), p(1500, 1500)]);
    final corner = model.nearestCorner(p(1500, 0), 1)!;
    final target = model.hitTest(p(1510, 5),
        cornerRadius: 220, wallRadius: 160, endpointRadius: 60);
    expect(target.corner, corner);
    expect(target.wall, isNull);
    model.moveCorners({corner: p(1600, 100)}, join: true);
    expect(
        model.walls.values
            .where((w) => w.start == corner || w.end == corner)
            .length,
        4);
    expect(WallNetwork.fromJson(model.toJson()).toJson(), model.toJson());
  });

  test('Calibration without coordinate changes remains undoable', () {
    final model = WallNetwork()
      ..addPolyline(const [DrawingPoint(0, 0), DrawingPoint(2000, 0)]);
    final history = DrawingHistory()..commit(model);
    final before = history.revision;
    model.calibrateFromWall(model.walls.keys.single, 2000);
    history.commit(model);
    expect(history.revision, isNot(before));
    expect(history.undo().calibrated, isFalse);
    expect(history.redo().calibrated, isTrue);
  });

  testWidgets('Dragging a short wall midpoint moves the wall, not its corner',
      (t) async {
    await board.open(t);
    await board.tool(t, 'Wall');
    await drawing.stroke(t, const [Offset(90, 80), Offset(114, 80)]);
    await board.collapseTools(t);
    final view = board.painter(t), wall = view.model.walls.values.single;
    final a = view.model.corners[wall.start]!,
        b = view.model.corners[wall.end]!;
    final midpoint = t.getTopLeft(board.canvas) + view.screen((a + b) * .5);
    final drag = await t.startGesture(midpoint);
    await drag.moveTo(midpoint + const Offset(0, 30));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    final edited = board.painter(t).model;
    expect(edited.length(wall.id), closeTo((b - a).length, .001));
    expect(edited.corners[wall.start]!.y, closeTo(a.y + 300, .001));
    expect(edited.corners[wall.end]!.y, closeTo(b.y + 300, .001));
    await board.expandTools(t);
    await t.ensureVisible(find.byTooltip('Undo'));
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    final restored = board.painter(t).model;
    expect(restored.corners[wall.start]!.y, a.y);
    expect(restored.corners[wall.end]!.y, b.y);
    await t.ensureVisible(find.byTooltip('Redo'));
    await t.tap(find.byTooltip('Redo'));
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), edited.toJson());
  });
}
