import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_shapes.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/drawing_painter.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';

Future<ui.Image> render(List<DrawingPoint> preview) async {
  final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
  canvas.drawPaint(Paint()..color = AppColors.white);
  DrawingPainter(
          model: WallNetwork(),
          origin: const Offset(40, 140),
          scale: .1,
          unit: DrawingUnit.metres,
          preview: preview,
          anglesEnabled: false)
      .paint(canvas, const Size(500, 500));
  final picture = recorder.endRecording();
  final image = await picture.toImage(500, 500);
  picture.dispose();
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const p = DrawingPoint.new;
  test('Live wall dots remain visible above the preview stroke', () async {
    final image = await render([p(0, 0), p(4000, 0)]);
    final pixels = (await image.toByteData())!;
    int rgba(int x, int y) => pixels.getUint32((y * 500 + x) * 4);
    expect(rgba(101, 140), isNot(rgba(130, 140)),
        reason: 'The 2 ft dot must not be covered by the preview stroke.');
    final output = Platform.environment['EASYFLOOR_AUDIT_IMAGE'];
    if (output != null) {
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File(output).writeAsBytes(png.buffer.asUint8List());
    }
    image.dispose();
  });
  for (final kind
      in ShapePreset.values.where((s) => s != ShapePreset.polygon)) {
    test('${kind.label} preview has ruler dots on its first wall too',
        () async {
      final image =
          await render(ShapeSpec(kind, 4000, 2400, 0).points(p(0, 0)));
      final pixels = (await image.toByteData())!;
      int rgba(int x, int y) => pixels.getUint32((y * 500 + x) * 4);
      expect(rgba(101, 140), isNot(rgba(130, 140)),
          reason: 'Every preset wall needs dots, not just the last wall.');
      image.dispose();
    });
  }
}
