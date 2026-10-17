import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/area_converter/logic/area_unit_conversion_service.dart';

void main() {
  group('AreaUnitConversionService', () {
    test('1 sqm equals exact sqft and sqin', () {
      final sqft = AreaUnitConversionService.convert(
        value: 1,
        fromUnit: AreaUnitConversionService.sqm,
        toUnit: AreaUnitConversionService.sqft,
      );
      expect(sqft, closeTo(10.763910416709722, 1e-12));

      final sqin = AreaUnitConversionService.convert(
        value: 1,
        fromUnit: AreaUnitConversionService.sqm,
        toUnit: AreaUnitConversionService.sqinch,
      );
      expect(sqin, closeTo(1550.0031000062, 1e-7));
    });

    test('1 sqft equals exact sqin and sqm', () {
      final sqin = AreaUnitConversionService.convert(
        value: 1,
        fromUnit: AreaUnitConversionService.sqft,
        toUnit: AreaUnitConversionService.sqinch,
      );
      expect(sqin, closeTo(144.0, 1e-12));

      final sqm = AreaUnitConversionService.convert(
        value: 1,
        fromUnit: AreaUnitConversionService.sqft,
        toUnit: AreaUnitConversionService.sqm,
      );
      expect(sqm, closeTo(0.09290304, 1e-12));
    });

    test('1 sqin equals 645.16 sqmm', () {
      final sqmm = AreaUnitConversionService.convert(
        value: 1,
        fromUnit: AreaUnitConversionService.sqinch,
        toUnit: AreaUnitConversionService.sqmm,
      );
      expect(sqmm, closeTo(645.16, 1e-9));
    });

    test('throws for unsupported units', () {
      expect(
        () => AreaUnitConversionService.convert(
          value: 1,
          fromUnit: 'bad',
          toUnit: AreaUnitConversionService.sqm,
        ),
        throwsArgumentError,
      );
    });
  });
}
