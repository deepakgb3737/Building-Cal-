import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/grid_ceiling_calculator.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/ceiling_material_service.dart';

void main() {
  test('Main runner stock preserves the supplied 3048 mm formula', () {
    expect(CeilingMaterialService.runnerLengthMm, 3048);
    expect(CeilingMaterialService.runnerLabel, '10ft');
    for (final mode in PlacementMode.values) {
      final result = GridCeilingCalculator.calculate(5000, 8000, mode: mode);
      expect(result.mainRunnerPieces,
          (8000 * result.numMainRunners / 3048).ceil());
    }
    expect(CeilingMaterialService.fullRunnerPieces(6096), 2);
    expect(CeilingMaterialService.runnerCutMm(6096), 0);
  });
  test('center based mode remains default behavior', () {
    final result = GridCeilingCalculator.calculate(5000, 8000);

    expect(result.mainRunnersWidth.first, closeTo(400, 0.001));
    expect(result.twoFootCrossT.first, closeTo(1000, 0.001));
  });

  test('one side mode uses wall-based main and 2ft positions', () {
    final result = GridCeilingCalculator.calculate(
      5000,
      8000,
      mode: PlacementMode.oneSide,
    );

    expect(result.mainRunnersWidth, equals(<double>[1200, 2400, 3600, 4800]));
    expect(result.twoFootCrossT, equals(<double>[600, 1800, 3000, 4200]));
    expect(result.crossTLength.first, 600);
    expect(result.crossTLength[1], 1200);
  });
}
