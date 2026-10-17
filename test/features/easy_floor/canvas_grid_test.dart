import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/drawing_painter.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scale in [.05, .1]) {
    test('Grid stays subtle and independent of geometry at scale $scale',
        () async {
      final model = WallNetwork()
        ..addPolyline(
            [const DrawingPoint(300, 700), const DrawingPoint(1300, 700)]);
      final before = model.toJson();
      final recorder = ui.PictureRecorder();
      // Keep the raster sample isolated from walls when comparing grid tones.
      final gridCanvas = Canvas(recorder);
      gridCanvas.drawColor(AppColors.white, BlendMode.src);
      DrawingPainter(
              model: model,
              origin: const Offset(40, 40),
              scale: scale,
              unit: DrawingUnit.mm,
              preview: [],
              anglesEnabled: false)
          .paint(gridCanvas, const Size(240, 240));
      final picture = recorder.endRecording(),
          image = await picture.toImage(240, 240);
      final pixels =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      int red(int x, int y) => pixels.getUint8((y * 240 + x) * 4);
      if (scale == .1) {
        expect(red(140, 90), lessThan(red(80, 90)));
        expect(red(80, 90), lessThan(red(90, 90)));
        expect(red(90, 110), lessThan(red(140, 90)));
      } else {
        expect(red(50, 65), 255);
        expect(red(40, 65), lessThan(255));
      }
      expect(model.toJson(), before);
      image.dispose();
      picture.dispose();
    });
  }
}
