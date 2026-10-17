import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_shapes.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'drawing_screen_test.dart' as board;

WallNetwork rectangle(double x, double y, double width, double height) =>
    WallNetwork()
      ..addPolyline([
        DrawingPoint(x, y),
        DrawingPoint(x + width, y),
        DrawingPoint(x + width, y + height),
        DrawingPoint(x, y + height),
        DrawingPoint(x, y)
      ]);

void main() {
  test('Irregular angled outlines select correctly in either winding direction',
      () {
    const points = [
      DrawingPoint(0, 0),
      DrawingPoint(2200, 300),
      DrawingPoint(2600, 2000),
      DrawingPoint(1100, 1700),
      DrawingPoint(0, 2200),
      DrawingPoint(0, 0)
    ];
    for (final stroke in [points, points.reversed.toList()]) {
      final m = WallNetwork()..addPolyline(stroke);
      final selected = m.enclosedComponentAt(const DrawingPoint(500, 500));
      expect(selected, m.walls.keys.toSet());
      final lengths = {for (final id in selected) id: m.length(id)};
      m.moveRoom(selected, const DrawingPoint(400, 300));
      for (final id in selected) {
        expect(m.length(id), closeTo(lengths[id]!, 1e-8));
      }
    }
  });
  test('Room alignment snaps one rigid offset without merging nearby rooms',
      () {
    final m = rectangle(0, 0, 1000, 1000)
      ..addPolyline([
        const DrawingPoint(3000, 2000),
        const DrawingPoint(4000, 2000),
        const DrawingPoint(4000, 3000),
        const DrawingPoint(3000, 3000),
        const DrawingPoint(3000, 2000)
      ]);
    final ids = m.enclosedComponentAt(const DrawingPoint(500, 500));
    final applied =
        m.moveRoom(ids, const DrawingPoint(1990, 500), alignmentRadius: 60);
    expect(applied.x, 2000);
    expect(applied.y, 500);
    expect(m.corners.length, 8);
    expect(m.walls.length, 8);
  });

  test('Unsafe alignment falls back to the valid requested gap', () {
    final m = rectangle(0, 0, 1000, 1000)
      ..addPolyline([
        const DrawingPoint(3000, 0),
        const DrawingPoint(4000, 0),
        const DrawingPoint(4000, 1000),
        const DrawingPoint(3000, 1000),
        const DrawingPoint(3000, 0)
      ]);
    final ids = m.enclosedComponentAt(const DrawingPoint(500, 500));
    final applied =
        m.moveRoom(ids, const DrawingPoint(1990, 200), alignmentRadius: 60);
    expect(applied.x, 1990);
    expect(applied.y, 200);
    expect(m.corners.length, 8);
    expect(() => WallNetwork.fromJson(m.toJson()), returnsNormally);
  });
  for (final kind in [
    ShapePreset.square,
    ShapePreset.rectangle,
    ShapePreset.lShape,
    ShapePreset.uShape,
    ShapePreset.tShape,
    ShapePreset.triangle
  ]) {
    test(
        '${kind.label} interior selects and translates one unchanged connected shape',
        () {
      final m = WallNetwork()
        ..addPolyline(
            ShapeSpec(kind, 3000, 2400, 0).points(const DrawingPoint(0, 0)));
      final ids = m.enclosedComponentAt(const DrawingPoint(100, 100));
      expect(ids, m.walls.keys.toSet());
      m.lockLength(ids.first);
      final constraints = m.constraintSignature;
      final points = Map.of(m.corners),
          lengths = {for (final id in ids) id: m.length(id)};
      m.moveRoom(ids, const DrawingPoint(725, -350));
      for (final entry in points.entries) {
        expect(m.corners[entry.key]!.x, closeTo(entry.value.x + 725, 1e-8));
        expect(m.corners[entry.key]!.y, closeTo(entry.value.y - 350, 1e-8));
      }
      for (final id in ids) {
        expect(m.length(id), closeTo(lengths[id]!, 1e-8));
      }
      expect(m.constraintSignature, constraints);
      expect(() => WallNetwork.fromJson(m.toJson()), returnsNormally);
    });
  }

  test(
      'Shared rooms and interior partitions select the complete connected network',
      () {
    final m = rectangle(0, 0, 3000, 2000)
      ..addPolyline(
          [const DrawingPoint(1500, 0), const DrawingPoint(1500, 2000)])
      ..addPolyline(
          [const DrawingPoint(0, 1000), const DrawingPoint(500, 1000)]);
    final ids = m.walls.keys.toSet();
    expect(m.enclosedComponentAt(const DrawingPoint(500, 500)), ids);
    expect(m.enclosedComponentAt(const DrawingPoint(2500, 500)), ids);
    expect(m.enclosedComponentAt(const DrawingPoint(2500, 3000)), isEmpty);
    m.moveRoom(ids, const DrawingPoint(100, 200));
    expect(m.walls.keys.toSet(), ids);
  });

  test('Open outlines and concave cut-outs are not rooms', () {
    final m = WallNetwork()
      ..addPolyline([
        const DrawingPoint(0, 0),
        const DrawingPoint(2000, 0),
        const DrawingPoint(2000, 2000)
      ]);
    expect(m.enclosedComponentAt(const DrawingPoint(500, 500)), isEmpty);
    final l = WallNetwork()
      ..addPolyline(const ShapeSpec(ShapePreset.lShape, 3000, 3000, 0)
          .points(const DrawingPoint(0, 0)));
    expect(l.enclosedComponentAt(const DrawingPoint(2500, 2500)), isEmpty);
    expect(l.enclosedComponentAt(const DrawingPoint(1000, 0)), isEmpty);
  });

  test('Independent rooms do not merge, overlap, contain or change one another',
      () {
    final m = rectangle(0, 0, 1000, 1000)
      ..addPolyline([
        const DrawingPoint(3000, 0),
        const DrawingPoint(5000, 0),
        const DrawingPoint(5000, 2000),
        const DrawingPoint(3000, 2000),
        const DrawingPoint(3000, 0)
      ]);
    final selected = m.enclosedComponentAt(const DrawingPoint(500, 500));
    final before = m.toJson();
    for (final delta in [
      const DrawingPoint(2000, 0),
      const DrawingPoint(2500, 500),
      const DrawingPoint(3500, 500)
    ]) {
      expect(
          () => m.moveRoom(selected, delta), throwsA(isA<DrawingConflict>()));
      expect(m.toJson(), before);
    }
    final neighbours = {
      for (final w in m.walls.values.where((w) => !selected.contains(w.id)))
        w.start,
      for (final w in m.walls.values.where((w) => !selected.contains(w.id)))
        w.end
    };
    final fixed = {for (final id in neighbours) id: m.corners[id]};
    m.moveRoom(selected, const DrawingPoint(1990, 0));
    for (final id in neighbours) {
      expect(m.corners[id], fixed[id]);
    }
    expect(m.corners.length, 8);
    expect(() => WallNetwork.fromJson(m.toJson()), returnsNormally);
  });

  testWidgets(
      'Tap and drag room interior moves every wall, one Undo restores it',
      (t) async {
    await board.open(t);
    await board.outline(t);
    await board.collapseTools(t);
    final original = board.painter(t).model.copy();
    final offset = t.getTopLeft(board.canvas),
        at = offset + const Offset(160, 140);
    await t.tapAt(at);
    await t.pumpAndSettle();
    expect(board.painter(t).highlightedWalls, original.walls.keys.toSet());
    final drag = await t.startGesture(at);
    await drag.moveBy(const Offset(20, 25));
    await t.pump();
    for (final entry in original.corners.entries) {
      expect(board.painter(t).model.corners[entry.key]!.x,
          closeTo(entry.value.x + 200, .001));
      expect(board.painter(t).model.corners[entry.key]!.y,
          closeTo(entry.value.y + 250, .001));
    }
    await drag.up();
    await t.pumpAndSettle();
    final moved = board.painter(t).model.toJson();
    await board.expandTools(t);
    await t.ensureVisible(find.byTooltip('Undo'));
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), original.toJson());
    await t.tap(find.byTooltip('Redo'));
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), moved);
    await board.collapseTools(t);
    await t.tapAt(offset + const Offset(180, 165));
    await t.pumpAndSettle();
    final view = board.painter(t), wall = view.model.walls.values.first;
    final wallAt = offset +
        view.screen(
            (view.model.corners[wall.start]! + view.model.corners[wall.end]!) *
                .5);
    final edit = await t.startGesture(wallAt);
    await edit.moveBy(const Offset(0, -15));
    await t.pump();
    expect(board.painter(t).selectedWall, wall.id);
    expect(board.painter(t).highlightedWalls, {wall.id});
    await edit.cancel();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), moved);
    expect(t.takeException(), isNull);
  });

  for (final pinch in [false, true]) {
    testWidgets(
        'Whole-shape ${pinch ? 'pinch interruption' : 'cancellation'} restores geometry',
        (t) async {
      await board.open(t);
      await board.outline(t);
      await board.collapseTools(t);
      final original = board.painter(t).model.toJson(),
          offset = t.getTopLeft(board.canvas);
      final drag = await t.startGesture(offset + const Offset(160, 140));
      await drag.moveBy(const Offset(15, 25));
      await t.pump();
      expect(board.painter(t).model.toJson(), isNot(original));
      if (pinch) {
        final second =
            await t.startGesture(offset + const Offset(200, 280), pointer: 2);
        await second.moveBy(const Offset(20, 0));
        await t.pump();
        expect(board.painter(t).model.toJson(), original);
        await second.up();
        await drag.up();
      } else {
        await drag.cancel();
      }
      await t.pumpAndSettle();
      expect(board.painter(t).model.toJson(), original);
      expect(t.takeException(), isNull);
    });
  }
}
