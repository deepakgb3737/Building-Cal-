import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/core/theme/build_calc_colors.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_history.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/drawing_painter.dart';
import 'junction_measurements_test.dart' show tee;

const p = DrawingPoint.new;
DrawingPainter view(WallNetwork model, double scale, {bool selected = false}) =>
    DrawingPainter(
        model: model,
        origin: const Offset(20, 80),
        scale: scale,
        unit: DrawingUnit.mm,
        preview: [],
        showAllMeasurements: true,
        selectedWall: selected ? model.walls.keys.first : null);

Future<Color> pixel(DrawingPainter painter, Color background) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(background, BlendMode.src);
  painter.paint(canvas, const Size(320, 240));
  final picture = recorder.endRecording();
  final image = await picture.toImage(320, 240);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  // Avoid endpoint circles, ruler dots and the centred dimension label.
  final wall = painter.model.walls.values.first;
  final at = painter.screen(painter.model.corners[wall.start]! * .77 +
      painter.model.corners[wall.end]! * .23);
  final offset = (at.dy.round() * 320 + at.dx.round()) * 4;
  final color = Color.fromARGB(
      bytes.getUint8(offset + 3),
      bytes.getUint8(offset),
      bytes.getUint8(offset + 1),
      bytes.getUint8(offset + 2));
  image.dispose();
  picture.dispose();
  return color;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final layouts = <String, List<DrawingPoint>>{
    'standalone': [p(0, 0), p(2000, 0)],
    'connected': [p(0, 0), p(2000, 0), p(2000, 1500)],
    'shared rooms': [p(0, 0), p(2000, 0), p(2000, 1500), p(0, 1500), p(0, 0)],
    'open C': [p(0, 0), p(2000, 0), p(2000, 2000), p(0, 2000), p(0, 1400)],
  };
  for (final entry in layouts.entries) {
    test('${entry.key}: red lock, normal unlock, dimensions and history',
        () async {
      final model = WallNetwork()..addPolyline(entry.value);
      if (entry.key == 'shared rooms') {
        model.addPolyline([p(0, 0), p(0, -1500), p(2000, -1500), p(2000, 0)]);
      }
      final id = model.walls.keys.first;
      final geometry = Map.of(model.corners);
      final before = model.toJson();
      final history = DrawingHistory()..commit(model);
      final measurement = view(model, .1).wallMeasurementText(id);
      model.lockLength(id);
      history.commit(model);
      final locked = model.toJson();
      expect(model.corners, geometry);
      expect(view(model, .1).wallMeasurementText(id), measurement);
      for (final scale in [.03, .1, .2]) {
        for (final background in [
          AppColors.white,
          BuildCalcColors.darkBackground
        ]) {
          for (final selected in [false, true]) {
            expect(
                await pixel(view(model, scale, selected: selected), background),
                AppColors.drawingLockedWall);
          }
        }
      }
      model.unlock(id);
      history.commit(model);
      expect(model.toJson(), before);
      for (final selected in [false, true]) {
        expect(
            await pixel(view(model, .1, selected: selected), AppColors.white),
            selected ? AppColors.primary : AppColors.ink);
      }
      expect(history.undo().toJson(), locked);
      expect(history.undo().toJson(), before);
      expect(history.redo().toJson(), locked);
      expect(history.redo().toJson(), before);
    });
  }

  test('Every split segment of a locked span is red with only its own length',
      () async {
    final model = tee(locked: true);
    for (final wall in model.walls.values) {
      final painter = DrawingPainter(
          model: model,
          origin: const Offset(20, 120),
          scale: .06,
          unit: DrawingUnit.feet,
          preview: [],
          selectedWall: wall.id);
      expect(painter.wallMeasurementText(wall.id), startsWith('6 ft\nDir '));
      expect(painter.wallMeasurementText(wall.id).toLowerCase(),
          isNot(contains('lock')));
      if (model.isFixed(wall.id)) {
        // Render this segment first to sample its own stroke, including the split half.
        final ordered = model.copy();
        final walls = Map.of(ordered.walls);
        ordered.walls
          ..clear()
          ..[wall.id] = walls.remove(wall.id)!
          ..addAll(walls);
        expect(await pixel(view(ordered, .06), AppColors.white),
            AppColors.drawingLockedWall);
      }
    }
  });
}
