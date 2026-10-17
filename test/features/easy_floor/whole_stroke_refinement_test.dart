import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/sketch_refinement.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'drawing_screen_test.dart' as board;
import 'natural_drawing_test.dart' show stroke;
import 'accessible_lock_test.dart' show press;
import 'annotation_interaction_test.dart' show undo;

const p = DrawingPoint.new;
void main() {
  test('Cleanup refuses shortcuts that introduce a new nearby junction', () {
    final model = WallNetwork()
      ..addPolyline([p(0, 0), p(1000, 20), p(2000, 0)])
      ..addPolyline([p(1000, 0), p(1000, -1000)]);
    final before = model.toJson();
    expect(
        () => SketchRefinement.straightenChain(model, model.walls.keys.first,
            tolerance: 30),
        throwsA(isA<DrawingConflict>()));
    expect(model.toJson(), before);
  });
  for (final zoom in [.05, .1, .5]) {
    test(
        'Straightening at zoom $zoom preserves endpoints and duplicate handling',
        () {
      final input = [p(0, 0), p(1000, 1 / zoom), p(2000, 0)];
      final result = SketchRefinement.fromStroke(input, tolerance: 3 / zoom);
      expect(result.refined.length, 2);
      final model = WallNetwork()..addPolyline(result.refined);
      final before = model.toJson();
      model.addPolyline(result.refined.reversed.toList());
      expect(model.toJson(), before);
      expect(model.length(model.walls.keys.single), 2000);
    });
  }
  test('Chain cleanup preserves branches, separate walls and fixed neighbours',
      () {
    final model = WallNetwork()
      ..addPolyline([p(0, 0), p(1000, 8), p(2000, 0), p(3000, 0)])
      ..addPolyline([p(2000, 0), p(2000, 1000)])
      ..addPolyline([p(4000, 0), p(5000, 0)]);
    final before = model.toJson();
    final (next, points) = SketchRefinement.straightenChain(
        model, model.walls.keys.first,
        tolerance: 30);
    expect(points.map((v) => [v.x, v.y]), [
      [0, 0],
      [2000, 0]
    ]);
    expect(next.walls.length, model.walls.length - 1);
    expect(next.nearestCorner(p(2000, 0), .001), isNotNull);
    for (final point in [p(4000, 0), p(5000, 0), p(2000, 1000)]) {
      expect(next.nearestCorner(point, .001), isNotNull);
    }
    expect(model.toJson(), before);
    expect(() => WallNetwork.fromJson(next.toJson()), returnsNormally);
    model.lockLength(model.walls.keys.first);
    expect(
        () => SketchRefinement.straightenChain(model, model.walls.keys.first,
            tolerance: 30),
        throwsA(isA<DrawingConflict>()));
  });
  test(
      'Multi-corner C and independent collinear strokes retain meaningful geometry',
      () {
    final model = WallNetwork()
      ..addPolyline(
          [p(0, 2000), p(0, 0), p(1000, 0), p(2000, 0), p(2000, 2000)])
      ..addPolyline([p(3000, 0), p(4000, 0)]);
    final (next, points) = SketchRefinement.straightenChain(
        model, model.walls.keys.elementAt(1),
        tolerance: 30);
    expect(points.map((v) => [v.x, v.y]), [
      [0, 0],
      [2000, 0]
    ]);
    expect(next.walls.length, 4);
    final id = next.walls.values
        .firstWhere((w) =>
            next.length(w.id) == 2000 &&
            next.corners[w.start]!.y == 0 &&
            next.corners[w.end]!.y == 0)
        .id;
    expect(() => SketchRefinement.straightenChain(next, id, tolerance: 30),
        throwsA(isA<DrawingConflict>()));
  });
  test(
      'Near-parallel refinement uses context without connecting independent walls',
      () {
    final base = WallNetwork()..addPolyline([p(0, 0), p(4000, 0)]);
    final before = base.toJson();
    final result = SketchRefinement.fromStroke(
        [p(0, 200), p(1000, 211), p(2000, 220)],
        tolerance: 30, existing: base, align: true);
    expect((result.refined.last - result.refined.first).y, closeTo(0, .001));
    final next = base.copy()..addPolyline(result.refined);
    expect(next.walls.length, 2);
    expect(next.corners.length, 4);
    expect(base.toJson(), before);
    final again = SketchRefinement.fromStroke(result.refined,
        tolerance: 30, existing: base, align: true);
    expect(again.refined, result.refined);
  });
  test('Attached endpoints and deliberate diagonals stay authoritative', () {
    final base = WallNetwork()..addPolyline([p(0, 0), p(0, 2000)]);
    final result = SketchRefinement.fromStroke(
        [p(0, 0), p(1000, 10), p(2000, 20)],
        tolerance: 30, existing: base, align: true);
    expect(result.refined.first.length, 0);
    final next = base.copy()..addPolyline(result.refined);
    expect(next.corners.length, 3);
    final diagonal = SketchRefinement.fromStroke(
        [p(0, 300), p(1000, 650), p(2000, 1000)],
        tolerance: 30, existing: base, align: true);
    expect(diagonal.refined.map((v) => [v.x, v.y]), [
      [0, 300],
      [2000, 1000]
    ]);
  });
  testWidgets('Whole-chain preview cancels safely then commits once with Undo',
      (t) async {
    await board.open(t, showLabels: false);
    await board.collapseTools(t);
    await stroke(t, [
      const Offset(60, 100),
      const Offset(100, 101),
      const Offset(160, 100),
      const Offset(240, 100)
    ]);
    final before = board.painter(t).model.toJson();
    expect(board.painter(t).model.walls.length, greaterThan(1));
    await t.tapAt(t.getTopLeft(board.canvas) + const Offset(80, 100));
    await t.pumpAndSettle();
    await board.moreWallOptions(t);
    await press(t, 'Straighten wall chain');
    expect(find.text('Preview only. Connected endpoints stay fixed.'),
        findsOneWidget);
    expect(board.painter(t).model.toJson(), before);
    t.view.physicalSize = const Size(740, 360);
    t.view.viewInsets = const FakeViewPadding(bottom: 140);
    addTearDown(t.view.resetViewInsets);
    await t.pumpAndSettle();
    expect(find.text('Cancel').hitTestable(), findsOneWidget);
    expect(find.text('Apply').hitTestable(), findsOneWidget);
    expect(t.takeException(), isNull);
    t.view.viewInsets = FakeViewPadding.zero;
    t.view.physicalSize = const Size(320, 740);
    await t.pumpAndSettle();
    await press(t, 'Cancel');
    expect(board.painter(t).model.toJson(), before);
    await press(t, 'Straighten wall chain');
    await press(t, 'Apply');
    expect(board.painter(t).model.walls.length, 1);
    expect(
        board.painter(t).model.length(board.painter(t).model.walls.keys.single),
        closeTo(1800, .001));
    await undo(t, 'Undo');
    expect(board.painter(t).model.toJson(), before);
    expect(t.takeException(), isNull);
  });
}
