import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_history.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/drawing_painter.dart';
import 'measurement_layout_test.dart' as layout;
import 'drawing_screen_test.dart' as board;
import 'natural_drawing_test.dart' as drawing;

const p = DrawingPoint.new;
const foot = 304.8;
WallNetwork tee({bool locked = false}) {
  final model = WallNetwork()..addPolyline([p(0, 0), p(12 * foot, 0)]);
  if (locked) model.lockLength(model.walls.keys.single);
  model.addPolyline([p(6 * foot, 0), p(6 * foot, -6 * foot)]);
  return model;
}

void valid(WallNetwork model) {
  expect(WallNetwork.fromJson(model.toJson()).toJson(), model.toJson());
  final edges = <(int, int)>{};
  for (final w in model.walls.values) {
    expect(model.length(w.id), greaterThanOrEqualTo(10));
    expect(edges.add(w.start < w.end ? (w.start, w.end) : (w.end, w.start)),
        isTrue);
  }
}

DrawingPainter render(WallNetwork model,
    {DrawingUnit unit = DrawingUnit.feet,
    double scale = .06,
    int? selected,
    Map<int, Rect>? bounds}) {
  final view = DrawingPainter(
      model: model,
      origin: const Offset(40, 190),
      scale: scale,
      unit: unit,
      preview: [],
      showAllMeasurements: true,
      selectedWall: selected,
      labelBounds: bounds);
  layout.paint(view, const Size(400, 420));
  return view;
}

void main() {
  test(
      '12 ft wall with a 6 ft midpoint partition has three distinct 6 ft segments',
      () {
    final model = tee();
    expect(model.walls.length, 3);
    expect(model.corners.length, 4);
    final junction = model.nearestCorner(p(6 * foot, 0), .001)!;
    expect(
        model.walls.values
            .where((w) => w.start == junction || w.end == junction)
            .length,
        3);
    final bounds = <int, Rect>{};
    final view = render(model, bounds: bounds);
    expect(bounds.keys.toSet(), model.walls.keys.toSet());
    for (final id in model.walls.keys) {
      expect(model.length(id), closeTo(6 * foot, 1e-8));
      expect(view.wallMeasurementText(id), '6 ft');
    }
    for (final a in bounds.entries) {
      for (final b in bounds.entries.where((b) => b.key != a.key)) {
        expect(a.value.overlaps(b.value), isFalse);
      }
      for (final corner in model.corners.values) {
        expect(
            a.value.overlaps(
                Rect.fromCircle(center: view.screen(corner), radius: 8)),
            isFalse);
      }
    }
    valid(model);
  });

  test(
      'Cross-junction and angled crossings share vertices without merging lengths',
      () {
    for (final diagonal in [false, true]) {
      final model = WallNetwork()
        ..addPolyline([p(0, 0), diagonal ? p(3000, 3000) : p(3000, 0)])
        ..addPolyline(diagonal
            ? [p(0, 3000), p(3000, 0)]
            : [p(1500, -1500), p(1500, 1500)]);
      expect(model.walls.length, 4);
      expect(model.corners.length, 5);
      final junction =
          model.nearestCorner(diagonal ? p(1500, 1500) : p(1500, 0), .001)!;
      expect(
          model.walls.values
              .every((w) => w.start == junction || w.end == junction),
          isTrue);
      for (final id in model.walls.keys) {
        expect(model.length(id),
            closeTo(diagonal ? (p(1500, 1500)).length : 1500, 1e-7));
      }
      valid(model);
    }
  });

  test(
      'Shared room boundary and reversed duplicate strokes create only one edge',
      () {
    final model = WallNetwork()
      ..addPolyline([p(0, 0), p(2000, 0), p(2000, 1500), p(0, 1500), p(0, 0)])
      ..addPolyline(
          [p(2000, 0), p(4000, 0), p(4000, 1500), p(2000, 1500), p(2000, 0)]);
    expect(model.walls.length, 7);
    expect(model.corners.length, 6);
    final before = model.toJson();
    model.addPolyline([p(2000, 1500), p(2000, 0)]);
    expect(model.toJson(), before);
    final split = tee();
    final beforeSplit = split.toJson();
    split.addPolyline([p(12 * foot, 0), p(0, 0)]);
    expect(split.toJson(), beforeSplit);
    valid(model);
    valid(split);
  });

  test('Fixed continuous span is not labelled as an individual segment length',
      () {
    final model = tee(locked: true), view = render(tee(locked: true));
    final horizontal = model.walls.values.where(
        (w) => model.corners[w.start]!.y == 0 && model.corners[w.end]!.y == 0);
    for (final w in horizontal) {
      expect(model.fixedSpans(w.id), [12 * foot]);
      expect(view.wallMeasurementText(w.id), '6 ft');
      expect(view.wallMeasurementText(w.id), isNot(contains('12 ft')));
    }
    valid(model);
  });

  test(
      'Junction edit, split, exact resize and undo/redo restore segment measurements',
      () {
    final model = tee(), history = DrawingHistory()..commit(tee());
    final original = model.toJson();
    final junction = model.nearestCorner(p(6 * foot, 0), .001)!;
    model.moveCorners({junction: p(7 * foot, 0)});
    final horizontal = model.walls.values
        .where((w) =>
            model.corners[w.start]!.y == 0 && model.corners[w.end]!.y == 0)
        .map((w) => model.length(w.id))
        .toList()
      ..sort();
    expect(horizontal[0], closeTo(5 * foot, 1e-7));
    expect(horizontal[1], closeTo(7 * foot, 1e-7));
    valid(model);
    history.commit(model);
    final changed = model.toJson();
    expect(history.undo().toJson(), original);
    expect(history.redo().toJson(), changed);
    final standalone = WallNetwork()..addPolyline([p(0, 0), p(4000, 0)]);
    standalone.splitWall(standalone.walls.keys.single, 1500);
    final last = standalone.nearestWall(p(3000, 0), 1)!;
    standalone.setLength(last, 2000, lock: false);
    expect(standalone.length(last), closeTo(2000, 1e-7));
    valid(standalone);
  });

  test('Crowded short segment keeps its own readable, prioritised label', () {
    final model = WallNetwork()
      ..addPolyline([p(0, 0), p(3000, 0)])
      ..addPolyline([p(1500, 0), p(1500, -1200)])
      ..addPolyline([p(1550, 0), p(1550, 1200)]);
    final short = model.nearestWall(p(1525, 0), .1)!;
    final bounds = <int, Rect>{};
    final view =
        render(model, unit: DrawingUnit.mm, selected: short, bounds: bounds);
    expect(model.length(short), closeTo(50, 1e-7));
    expect(view.wallMeasurementText(short).split('\n').first, '50 mm');
    expect(bounds, contains(short));
    for (final a in bounds.entries) {
      for (final b in bounds.entries.where((b) => b.key != a.key)) {
        expect(a.value.overlaps(b.value), isFalse);
      }
    }
    valid(model);
  });

  for (final unit in DrawingUnit.values) {
    for (final scale in [.03, .06, .08]) {
      test('T labels remain segment-specific in ${unit.symbol} at zoom $scale',
          () {
        final model = tee(), bounds = <int, Rect>{};
        final view = render(model, unit: unit, scale: scale, bounds: bounds);
        expect(bounds.keys.toSet(), model.walls.keys.toSet());
        for (final id in model.walls.keys) {
          expect(view.wallMeasurementText(id), unit.format(6 * foot));
        }
      });
    }
  }

  testWidgets(
      'Selection highlights one segment; dragging displays each moved part',
      (t) async {
    await board.open(t);
    await board.outline(t);
    await board.collapseTools(t);
    await drawing.stroke(t, const [Offset(160, 60), Offset(160, 220)],
        hold: true);
    await board.collapseTools(t);
    final at = t.getTopLeft(board.canvas) + const Offset(110, 60);
    await t.tapAt(at);
    await t.pumpAndSettle();
    final selected = board.painter(t).selectedWall!;
    expect(board.painter(t).highlightedWalls, {selected});
    final run = board.painter(t).model.straightRun(selected);
    expect(run.length, 2);
    final drag = await t.startGesture(at);
    await drag.moveBy(const Offset(0, -20));
    await t.pump();
    final view = board.painter(t);
    expect(view.highlightedWalls, run);
    expect(view.measuredWalls, containsAll(run));
    expect(view.labelBounds!.keys, containsAll(run));
    for (final id in run) {
      expect(view.wallMeasurementText(id).split('\n').first,
          view.unit.format(view.model.length(id)));
    }
    await drag.cancel();
    await t.pumpAndSettle();
    expect(board.painter(t).highlightedWalls, {selected});
    expect(t.takeException(), isNull);
  });
}
