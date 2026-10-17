import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/drawing_painter.dart';
import 'measurement_layout_test.dart' show paint;
import 'drawing_screen_test.dart' as board;

const p = DrawingPoint.new;

Future<List<int>> pixels(DrawingPainter view) async {
  final recorder = ui.PictureRecorder();
  view.paint(Canvas(recorder), const Size(320, 400));
  final picture = recorder.endRecording();
  final image = await picture.toImage(320, 400);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = data!.buffer.asUint8List();
  image.dispose();
  picture.dispose();
  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'Dense overview preserves active priority and suppresses unplaceable labels',
      () {
    final model = WallNetwork();
    for (var i = 0; i <= 10; i++) {
      model.addPolyline([p(i * 200, 0), p(i * 200, 2000)]);
      model.addPolyline([p(0, i * 200), p(2000, i * 200)]);
    }
    final id = model.walls.keys.last;
    final bounds = <int, Rect>{};
    final view = DrawingPainter(
        model: model,
        origin: const Offset(50, 60),
        scale: .1,
        unit: DrawingUnit.mm,
        preview: [],
        selectedWall: id,
        showAllMeasurements: true,
        labelBounds: bounds);
    final samples = <int>[];
    Map<int, Rect>? expected;
    for (var frame = 0; frame < 8; frame++) {
      final watch = Stopwatch()..start();
      paint(view);
      if (frame > 0) samples.add(watch.elapsedMicroseconds);
      expected ??= Map.of(bounds);
      expect(bounds, expected);
    }
    samples.sort();
    debugPrint(
        'LABEL_OVERVIEW walls=${model.walls.length} visible=${bounds.length} median_paint_us=${samples[samples.length ~/ 2]}');
    expect(bounds.keys.first, id);
    expect(bounds.length, lessThan(model.walls.length));
    final rects = bounds.values.toList();
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(rects[i].overlaps(rects[j]), isFalse);
      }
    }
  });
  test('Rejected label positions are reconsidered on the next frame', () {
    final model = WallNetwork()
      ..addPolyline([p(0, 0), p(2000, 0), p(2000, 2000)]);
    final bounds = <int, Rect>{};
    final obstacles = [const Rect.fromLTWH(0, 0, 320, 400)];
    final view = DrawingPainter(
        model: model,
        origin: const Offset(40, 80),
        scale: .1,
        unit: DrawingUnit.mm,
        preview: [],
        showAllMeasurements: true,
        labelObstacles: obstacles,
        labelBounds: bounds);
    paint(view);
    expect(bounds, isEmpty);
    obstacles.clear();
    paint(view);
    expect(bounds.keys.toSet(), model.walls.keys.toSet());
  });
  for (final scale in [.01, .1]) {
    test(
        'Secondary corner information adapts at zoom $scale without hiding lengths',
        () async {
      final model = WallNetwork()
        ..addPolyline([p(0, 0), p(2000, 0), p(2000, 2000)]);
      final corner = model.walls.values.last.start;
      final bounds = <int, Rect>{};
      DrawingPainter view(bool angles) => DrawingPainter(
          model: model,
          origin: const Offset(40, 80),
          scale: scale,
          unit: DrawingUnit.mm,
          preview: [],
          selectedCorner: corner,
          editingCorner: true,
          anglesEnabled: angles,
          labelBounds: bounds);
      final withAngles = await pixels(view(true));
      expect(bounds.keys.toSet(), model.walls.keys.toSet());
      final withoutAngles = await pixels(view(false));
      expect(withAngles,
          scale == .01 ? equals(withoutAngles) : isNot(equals(withoutAngles)));
    });
  }
  test('Affected walls get space before earlier essential wall records', () {
    final model = WallNetwork()
      ..addPolyline([p(0, 0), p(2000, 0)])
      ..addPolyline([p(0, 150), p(2000, 150)]);
    final active = model.walls.keys.last;
    final before = model.toJson(), bounds = <int, Rect>{};
    final view = DrawingPainter(
        model: model,
        origin: const Offset(60, 150),
        scale: .1,
        unit: DrawingUnit.mm,
        preview: [],
        showAllMeasurements: true,
        contextWalls: {active},
        labelBounds: bounds);
    paint(view);
    expect(bounds.keys.first, active);
    expect(bounds.keys.toSet(), model.walls.keys.toSet());
    expect(bounds.values.first.overlaps(bounds.values.last), isFalse);
    expect(model.toJson(), before);
  });

  test('Both walls of an active corner precede unrelated essential walls', () {
    final model = WallNetwork()
      ..addPolyline([p(0, 0), p(2000, 0)])
      ..addPolyline([p(0, 600), p(2000, 600), p(2000, 2000)]);
    final corner = model.walls.values.last.start;
    final attached = model.walls.values
        .where((w) => w.start == corner || w.end == corner)
        .map((w) => w.id)
        .toSet();
    final bounds = <int, Rect>{};
    paint(DrawingPainter(
        model: model,
        origin: const Offset(40, 100),
        scale: .1,
        unit: DrawingUnit.feet,
        preview: [],
        showAllMeasurements: true,
        selectedCorner: corner,
        labelBounds: bounds));
    expect(bounds.keys.take(2).toSet(), attached);
  });

  test('A crowded live drawing label finds clear canvas space with a leader',
      () {
    final model = WallNetwork(), before = WallNetwork().toJson();
    final view = DrawingPainter(
        model: model,
        origin: Offset.zero,
        scale: .1,
        unit: DrawingUnit.mm,
        preview: [p(1500, 1500), p(1600, 1500)],
        labelObstacles: [const Rect.fromLTWH(0, 0, 320, 300)]);
    paint(view);
    expect(view.previewLabelBounds, isNotNull);
    expect(view.previewLabelBounds!.top, greaterThanOrEqualTo(300));
    expect(view.previewLabelBounds!.bottom, lessThanOrEqualTo(400));
    expect(model.toJson(), before);
    view.preview.clear();
    paint(view);
    expect(view.previewLabelBounds, isNull);
  });

  for (final unit in DrawingUnit.values) {
    test('Live lengths follow actual diagonal geometry in ${unit.symbol}', () {
      final model = WallNetwork()..addPolyline([p(0, 0), p(3000, 4000)]);
      final id = model.walls.keys.single;
      final view = DrawingPainter(
          model: model,
          origin: const Offset(40, 40),
          scale: .05,
          unit: unit,
          preview: [],
          selectedWall: id);
      expect(view.wallMeasurementText(id).split('\n').first, unit.format(5000));
      model.moveCorners({model.walls[id]!.end: p(6000, 8000)});
      expect(
          view.wallMeasurementText(id).split('\n').first, unit.format(10000));
      final bounds = <int, Rect>{};
      paint(DrawingPainter(
          model: model,
          origin: const Offset(40, 40),
          scale: .03,
          unit: unit,
          preview: [],
          selectedWall: id,
          labelBounds: bounds));
      expect(bounds, contains(id));
    });
  }

  testWidgets('Labels avoid contextual inspectors and restore after hiding UI',
      (t) async {
    await board.open(t);
    await board.outline(t);
    await board.collapseTools(t);
    var view = board.painter(t);
    final wall = view.model.walls.values.first;
    final offset = t.getTopLeft(board.canvas);
    await t.tapAt(offset +
        view.screen(
            (view.model.corners[wall.start]! + view.model.corners[wall.end]!) *
                .5));
    await t.pumpAndSettle();
    view = board.painter(t);
    final panel = find
        .ancestor(
            of: find.textContaining('Selected wall ·'),
            matching: find.byType(Material))
        .first;
    final rect = t.getRect(panel).shift(-offset);
    expect(view.interfaceObstacles!(), contains(rect));
    for (final bounds in view.labelBounds!.values) {
      expect(bounds.overlaps(rect), isFalse);
    }
    final before = view.model.toJson();
    await t.tap(find.byTooltip('Hide UI'));
    await t.pumpAndSettle();
    expect(board.painter(t).interfaceObstacles!(), isEmpty);
    expect(board.painter(t).model.toJson(), before);
    await t.tap(find.byTooltip('Show Tools'));
    await t.pumpAndSettle();
    expect(board.painter(t).interfaceObstacles!(), isNotEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('Dragging a measurement cannot translate the associated wall',
      (t) async {
    await board.open(t);
    await board.outline(t);
    await board.collapseTools(t);
    final view = board.painter(t), before = view.model.toJson();
    final entry = view.labelBounds!.entries.first;
    final at = t.getTopLeft(board.canvas) + entry.value.center;
    final drag = await t.startGesture(at);
    await drag.moveBy(const Offset(35, 30));
    await t.pump();
    expect(board.painter(t).model.toJson(), before);
    await drag.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), before);
    expect(board.painter(t).selectedWall, entry.key);
    expect(t.takeException(), isNull);
  });
}
