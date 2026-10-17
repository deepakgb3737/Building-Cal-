import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_camera.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/floor_document.dart';

void main() {
  test(
      'Fit preserves proportions, margins and center for large negative bounds',
      () {
    final points = [
      const DrawingPoint(-1000000, -500000),
      const DrawingPoint(1000000, 500000)
    ];
    final fit = fitDrawingCamera(points, 320, 480)!;
    expect(fit.$1, lessThan(.005));
    final a = points.first * fit.$1 + fit.$2;
    final b = points.last * fit.$1 + fit.$2;
    expect(a.x, closeTo(32, 1e-8));
    expect(b.x, closeTo(288, 1e-8));
    expect((a.y + b.y) / 2, closeTo(240, 1e-8));
    final restored =
        DocumentSettings.fromJson(DocumentSettings(scale: fit.$1).toJson());
    expect(restored.scale, fit.$1);
  });
  test('Empty and zero-size viewports are no-ops; tiny plans stay finite', () {
    expect(fitDrawingCamera([], 320, 480), isNull);
    expect(fitDrawingCamera([const DrawingPoint(0, 0)], 0, 480), isNull);
    final fit = fitDrawingCamera([const DrawingPoint(0, 0)], 320, 480)!;
    expect(fit.$1, maxDrawingScale);
    expect(fit.$2.x, 160);
    expect(fit.$2.y, 240);
  });
  test('Invalid bounds never produce a non-finite camera', () {
    expect(
        () => fitDrawingCamera([const DrawingPoint(double.nan, 0)], 320, 480),
        throwsArgumentError);
    expect(
        () =>
            fitDrawingCamera([const DrawingPoint(0, 0)], 320, 480, margin: -1),
        throwsArgumentError);
  });
}
