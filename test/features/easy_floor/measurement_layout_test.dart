import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/drawing_painter.dart';

void paint(DrawingPainter painter, [Size size = const Size(320, 400)]) {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  recorder.endRecording().dispose();
}

void main() {
  for (final scale in [.02, .1, .5]) {
    for (final unit in [DrawingUnit.mm, DrawingUnit.feetInches]) {
      test(
          'Narrow rooms, partitions, diagonals and short walls at $scale in ${unit.symbol}',
          () {
        final model = WallNetwork()
          ..addPolyline([
            const DrawingPoint(0, 0),
            const DrawingPoint(2000, 0),
            const DrawingPoint(2000, 200),
            const DrawingPoint(0, 200),
            const DrawingPoint(0, 0)
          ])
          ..addPolyline(
              [const DrawingPoint(1000, 0), const DrawingPoint(1000, 200)])
          ..addPolyline(
              [const DrawingPoint(2300, 400), const DrawingPoint(2900, 900)])
          ..addPolyline(
              [const DrawingPoint(0, 1500), const DrawingPoint(100, 1500)]);
        final before = model.toJson();
        final bounds = <int, Rect>{}, offsets = <int, double>{};
        final selected = model.nearestWall(const DrawingPoint(200, 0), .001)!;
        final view = DrawingPainter(
            model: model,
            origin: const Offset(10, 50),
            scale: scale,
            unit: unit,
            preview: [],
            selectedWall: selected,
            showAllMeasurements: true,
            anglesEnabled: false,
            labelBounds: bounds,
            labelOffsets: offsets);
        paint(view);
        expect(bounds, contains(selected));
        final labels = bounds.values.toList();
        for (var i = 0; i < labels.length; i++) {
          expect(
              (const Rect.fromLTWH(0, 0, 320, 400)).contains(labels[i].topLeft),
              isTrue);
          expect(
              (const Rect.fromLTWH(0, 0, 320, 400))
                  .contains(labels[i].bottomRight),
              isTrue);
          for (var j = i + 1; j < labels.length; j++) {
            expect(labels[i].overlaps(labels[j]), isFalse);
          }
          for (final wall in model.walls.values) {
            final a = view.screen(model.corners[wall.start]!),
                b = view.screen(model.corners[wall.end]!);
            for (var step = 0; step <= 100; step++) {
              expect(labels[i].contains(a + (b - a) * (step / 100)), isFalse);
            }
          }
        }
        final placed = Map.of(bounds);
        paint(view);
        expect(bounds, placed);
        expect(model.toJson(), before);
      });
    }
  }

  test('Entirely off-screen walls never gain a misleading edge label', () {
    final model = WallNetwork()
      ..addPolyline(
          [const DrawingPoint(-5000, 0), const DrawingPoint(-4000, 0)]);
    final bounds = <int, Rect>{};
    paint(DrawingPainter(
        model: model,
        origin: const Offset(40, 100),
        scale: .1,
        unit: DrawingUnit.mm,
        preview: [],
        showAllMeasurements: true,
        labelBounds: bounds));
    expect(bounds, isEmpty);
  });
  test('A partly visible wall keeps its measurement inside the canvas', () {
    final model = WallNetwork()
      ..addPolyline(
          [const DrawingPoint(-5000, 0), const DrawingPoint(1000, 0)]);
    final bounds = <int, Rect>{};
    final view = DrawingPainter(
        model: model,
        origin: const Offset(40, 100),
        scale: .1,
        unit: DrawingUnit.mm,
        preview: [],
        selectedWall: model.walls.keys.single,
        labelBounds: bounds);
    paint(view);
    expect(bounds.length, 1);
    expect(
        (const Rect.fromLTWH(0, 0, 320, 400))
            .contains(bounds.values.single.topLeft),
        isTrue);
    expect(model.length(model.walls.keys.single), 6000);
  });

  test('Show all yields to affected dimensions while editing', () {
    final model = WallNetwork()
      ..addPolyline([const DrawingPoint(0, 0), const DrawingPoint(2000, 0)])
      ..addPolyline(
          [const DrawingPoint(0, 2000), const DrawingPoint(2000, 2000)]);
    final selected = model.walls.keys.first;
    final view = DrawingPainter(
        model: model,
        origin: const Offset(40, 100),
        scale: .1,
        unit: DrawingUnit.mm,
        preview: [],
        selectedWall: selected,
        showAllMeasurements: true,
        editingActive: true);
    expect(view.measuredWalls, {selected});
  });

  test('Labels search along the wall to avoid an annotation and remain stable',
      () {
    final model = WallNetwork()
      ..addPolyline([const DrawingPoint(0, 0), const DrawingPoint(2000, 0)]);
    final bounds = <int, Rect>{}, offsets = <int, double>{};
    const note = Rect.fromLTWH(130, 0, 20, 400);
    final view = DrawingPainter(
        model: model,
        origin: const Offset(40, 200),
        scale: .1,
        unit: DrawingUnit.mm,
        preview: [],
        showAllMeasurements: true,
        labelObstacles: [note],
        labelBounds: bounds,
        labelOffsets: offsets);
    paint(view);
    expect(bounds.length, 1);
    expect(bounds.values.single.overlaps(note), isFalse);
    final before = Map.of(bounds);
    paint(view);
    expect(bounds, before);
  });

  test(
      'Dimension formatting removes padding zeros without changing input precision',
      () {
    expect(DrawingUnit.metres.format(2000), '2 m');
    expect(DrawingUnit.metres.format(2340), '2.34 m');
    expect(DrawingUnit.mm.format(1234.5), '1234.5 mm');
    expect(DrawingUnit.feetInches.format(304.8), '1 ft 0 in');
    for (final unit in DrawingUnit.values) {
      expect(unit.readMm(unit.input(1234.567)), closeTo(1234.567, 1e-6));
    }
  });
}
