import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/drawer/logic/drawer_calculation_service.dart';
import 'package:grid_ceiling_calculator/features/calculator/logic/calculator_engine.dart';
import 'package:grid_ceiling_calculator/features/compass/logic/compass_controller.dart';
import 'package:grid_ceiling_calculator/core/input_validation.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/ceiling_material_service.dart';

void main() {
  DrawerCalcResult cabinet(DrawerCalcMode mode,
          {double? custom, List<double> sizes = const []}) =>
      DrawerCalculationService.calculate(
          height: 762,
          count: 5,
          top: 9,
          bottom: 9,
          gap: 3,
          mode: mode,
          customHeight: custom,
          customHeights: sizes);

  test('drawer examples include all four gaps and custom rounding', () {
    expect(cabinet(DrawerCalcMode.equal).drawerHeightMm, 146.4);
    expect(cabinet(DrawerCalcMode.oneCustom, custom: 200).drawerHeightMm, 133);
    final multiple = cabinet(DrawerCalcMode.multipleCustom, sizes: [200, 150]);
    expect(multiple.drawerHeightMm, 127);
    expect(multiple.totalGapSpaceMm, 12);
    expect(
        multiple.drawerHeightsMm.fold<double>(0, (a, b) => a + b) +
            multiple.totalNonDrawerSpaceMm,
        761);
    expect(() => multiple.drawerHeightsMm.add(100), throwsUnsupportedError);
  });
  test('invalid drawer and numeric inputs fail safely', () {
    expect(() => cabinet(DrawerCalcMode.oneCustom, custom: double.infinity),
        throwsFormatException);
    expect(() => cabinet(DrawerCalcMode.multipleCustom, sizes: [700]),
        throwsFormatException);
    expect(DrawerCalculationService.parseCustomHeights('200,bad'), isNull);
    expect(InputValidation.positiveNumber('NaN'), isNotNull);
    expect(InputValidation.roomDimension('800', 'Width'), isNull);
    expect(InputValidation.roomDimension('40001', 'Width'), isNotNull);
  });
  test('arithmetic precedence and compass wraparound', () {
    expect(CalculatorEngine.tryEvaluate('2+3*4'), 14);
    expect(CalculatorEngine.tryEvaluate('1/0'), isNull);
    final compass = CompassController()..heading = 359;
    expect(compass.smooth(1), closeTo(359.44, .001));
    expect(compass.cardinal(0), 'N');
    expect(CeilingMaterialService.fullRunnerPieces(6100), 2);
    expect(CeilingMaterialService.runnerCutMm(6100), 4);
  });
}
