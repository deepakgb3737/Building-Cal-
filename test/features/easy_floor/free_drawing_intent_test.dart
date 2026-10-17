import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/sketch_refinement.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'drawing_screen_test.dart' as board;
import 'natural_drawing_test.dart' as drawing;
import 'sketch_refinement_interaction_test.dart' as review;
import 'annotation_interaction_test.dart' as actions;

const nearLoop = [
  DrawingPoint(0, 0),
  DrawingPoint(2000, 5),
  DrawingPoint(2000, 2000),
  DrawingPoint(0, 2000),
  DrawingPoint(0, 50),
];

void main() {
  test('Near closure is only a proposal; original remains open and immutable',
      () {
    final raw = List.of(nearLoop);
    final result = SketchRefinement.fromStroke(raw, tolerance: 30);
    expect(raw, nearLoop);
    expect((result.original.first - result.original.last).length, 50);
    expect((result.refined.first - result.refined.last).length, lessThan(.001));
    final original = WallNetwork()..addPolyline(result.original);
    final refined = WallNetwork()..addPolyline(result.refined);
    expect(original.corners.length, 5);
    expect(refined.corners.length, 4);
  });

  test('A near-returning irregular outline closes without becoming a rectangle',
      () {
    final result = SketchRefinement.fromStroke([
      const DrawingPoint(0, 0),
      const DrawingPoint(2100, 300),
      const DrawingPoint(1600, 2000),
      const DrawingPoint(100, 1600),
      const DrawingPoint(0, 35),
    ], tolerance: 30);
    expect(result.shape, isNull);
    expect(result.refined.length, 5);
    expect(result.refined[1].y, 300);
    expect((result.refined.first - result.refined.last).length, 0);
  });

  test('Open outlines, straight returns and disabled recognition stay open',
      () {
    for (final points in [
      [
        const DrawingPoint(0, 0),
        const DrawingPoint(2000, 0),
        const DrawingPoint(2000, 1000)
      ],
      [
        const DrawingPoint(0, 0),
        const DrawingPoint(2000, 0),
        const DrawingPoint(4000, 0),
        const DrawingPoint(20, 0)
      ],
      [...nearLoop.take(4), const DrawingPoint(0, 300)],
    ]) {
      final result = SketchRefinement.fromStroke(points, tolerance: 30);
      expect((result.refined.first - result.refined.last).length,
          greaterThan(.001));
    }
    final attached =
        SketchRefinement.fromStroke(nearLoop, tolerance: 30, recognize: false);
    expect((attached.refined.first - attached.refined.last).length, 50);
  });

  test('Self-crossing near-loop does not invent a simple closed room', () {
    final input = [
      const DrawingPoint(0, 0),
      const DrawingPoint(2000, 2000),
      const DrawingPoint(0, 2000),
      const DrawingPoint(2000, 0),
      const DrawingPoint(0, 40)
    ];
    final result = SketchRefinement.fromStroke(input, tolerance: 30);
    expect(result.shape, isNull);
    expect(result.refined.last.y, 40);
  });

  testWidgets(
      'Closure preview can be rejected or accepted, then undone and redone',
      (t) async {
    await board.open(t);
    const points = [
      Offset(60, 60),
      Offset(260, 60),
      Offset(260, 260),
      Offset(60, 260),
      Offset(60, 65)
    ];
    await drawing.stroke(t, points, finish: false);
    expect(
        find.text('Preview will join the nearby endpoints.'), findsOneWidget);
    expect(board.painter(t).model.walls, isEmpty);
    await review.choose(t, 'Yes, Straighten');
    expect(
        (board.painter(t).preview.first - board.painter(t).preview.last).length,
        lessThan(.001));
    await review.choose(t, 'Accept refinement');
    final closed = board.painter(t).model.toJson();
    expect(board.painter(t).model.corners.length, 4);
    await actions.undo(t, 'Undo');
    expect(board.painter(t).model.walls, isEmpty);
    expect(
        (board.painter(t).preview.first - board.painter(t).preview.last).length,
        closeTo(50, .001));
    await actions.undo(t, 'Redo');
    expect(board.painter(t).model.toJson(), closed);
    await actions.undo(t, 'Undo');
    await board.expandTools(t);
    await review.choose(t, 'Keep Original');
    expect(board.painter(t).model.corners.length, 5);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Continuous stroke outside and across a room stays one reversible stroke',
      (t) async {
    await board.open(t);
    await board.outline(t);
    await board.collapseTools(t);
    final before = board.painter(t).model.toJson();
    final oldCorners = Map.of(board.painter(t).model.corners);
    await drawing.stroke(
        t,
        const [
          Offset(20, 140),
          Offset(150, 140),
          Offset(300, 140),
          Offset(300, 300)
        ],
        finish: false);
    expect(board.painter(t).model.toJson(), before);
    expect(find.byTooltip('Expand drawing tools'), findsOneWidget);
    await board.expandTools(t);
    expect(find.text('Straighten and refine this sketch?'), findsOneWidget);
    await review.choose(t, 'Keep Original');
    final model = board.painter(t).model;
    expect(model.walls.length, 10);
    final view = board.painter(t);
    for (final target in [const Offset(60, 140), const Offset(260, 140)]) {
      final junction = model.corners.entries
          .firstWhere((e) => (view.screen(e.value) - target).distance < .001)
          .key;
      expect(
          model.walls.values
              .where((w) => w.start == junction || w.end == junction)
              .length,
          4);
    }
    for (final corner in oldCorners.entries) {
      expect(model.corners[corner.key]!.x, corner.value.x);
      expect(model.corners[corner.key]!.y, corner.value.y);
    }
    expect(() => WallNetwork.fromJson(model.toJson()), returnsNormally);
    await actions.undo(t, 'Undo');
    expect(board.painter(t).model.toJson(), before);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Separate freehand loop does not alter or merge with the first outline',
      (t) async {
    await board.open(t);
    await board.outline(t);
    await board.collapseTools(t);
    final before = board.painter(t).model.toJson();
    await drawing.stroke(
        t,
        const [
          Offset(80, 300),
          Offset(220, 300),
          Offset(220, 430),
          Offset(80, 430),
          Offset(80, 300)
        ],
        finish: false);
    expect(board.painter(t).model.toJson(), before);
    expect(find.byTooltip('Expand drawing tools'), findsOneWidget);
    await board.expandTools(t);
    await review.choose(t, 'Keep Original');
    expect(board.painter(t).model.walls.length, 8);
    expect(board.painter(t).model.corners.length, 8);
    await actions.undo(t, 'Undo');
    expect(board.painter(t).model.toJson(), before);
    expect(t.takeException(), isNull);
  });

  test(
      'Extension, crossing, duplicated boundary and independent loop preserve a shared graph',
      () {
    final m = WallNetwork()
      ..addPolyline([
        const DrawingPoint(0, 0),
        const DrawingPoint(2000, 0),
        const DrawingPoint(2000, 2000),
        const DrawingPoint(0, 2000),
        const DrawingPoint(0, 0),
      ]);
    m.addPolyline([const DrawingPoint(2000, 0), const DrawingPoint(3000, 0)]);
    expect(m.corners.length, 5);
    m.addPolyline(
        [const DrawingPoint(-500, 1000), const DrawingPoint(2500, 1000)]);
    for (final x in [0.0, 2000.0]) {
      final junction = m.nearestCorner(DrawingPoint(x, 1000), .001)!;
      expect(
          m.walls.values
              .where((w) => w.start == junction || w.end == junction)
              .length,
          4);
    }
    final count = m.walls.length;
    m.addPolyline([const DrawingPoint(0, 0), const DrawingPoint(2000, 0)]);
    expect(m.walls.length, count);
    m.addPolyline([
      const DrawingPoint(4000, 0),
      const DrawingPoint(5000, 0),
      const DrawingPoint(5000, 1000),
      const DrawingPoint(4000, 1000),
      const DrawingPoint(4000, 0)
    ]);
    expect(m.walls.length, count + 4);
    expect(() => WallNetwork.fromJson(m.toJson()), returnsNormally);
  });
}
