import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/unit_converter/logic/unit_conversion_service.dart';

void main() {
  group('UnitConversionService', () {
    test('uses exact inch-foot-metre conversions', () {
      expect(
        UnitConversionService.convert(
          value: 1,
          fromUnit: UnitConversionService.foot,
          toUnit: UnitConversionService.inch,
        ),
        closeTo(12.0, 1e-12),
      );

      expect(
        UnitConversionService.convert(
          value: 1,
          fromUnit: UnitConversionService.metre,
          toUnit: UnitConversionService.inch,
        ),
        closeTo(39.37007874015748, 1e-10),
      );
    });

    test('uses exact mile and nautical mile definitions', () {
      expect(
        UnitConversionService.convert(
          value: 1,
          fromUnit: UnitConversionService.mile,
          toUnit: UnitConversionService.metre,
        ),
        closeTo(1609.344, 1e-9),
      );

      expect(
        UnitConversionService.convert(
          value: 1,
          fromUnit: UnitConversionService.nauticalMile,
          toUnit: UnitConversionService.metre,
        ),
        closeTo(1852.0, 1e-9),
      );
    });

    test('handles metric scale conversions correctly', () {
      expect(
        UnitConversionService.convert(
          value: 1,
          fromUnit: UnitConversionService.kilometre,
          toUnit: UnitConversionService.millimetre,
        ),
        closeTo(1000000.0, 1e-6),
      );

      expect(
        UnitConversionService.convert(
          value: 2500,
          fromUnit: UnitConversionService.centimetre,
          toUnit: UnitConversionService.metre,
        ),
        closeTo(25.0, 1e-12),
      );
    });

    test('throws for unsupported units', () {
      expect(
        () => UnitConversionService.convert(
          value: 1,
          fromUnit: 'Unsupported',
          toUnit: UnitConversionService.metre,
        ),
        throwsArgumentError,
      );
    });
  });
}
