import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/area_calculator/logic/area_conversion_service.dart';

void main() {
  group('AreaConversionService', () {
    test('feet input returns same square feet', () {
      final sqFt = AreaConversionService.calculateSquareFeet(
        width: 10,
        length: 12,
        inputUnit: AreaConversionService.feet,
      );
      expect(sqFt, closeTo(120.0, 1e-12));
    });

    test('meter input converts to exact square feet', () {
      final sqFt = AreaConversionService.calculateSquareFeet(
        width: 1,
        length: 1,
        inputUnit: AreaConversionService.meter,
      );
      expect(sqFt, closeTo(10.763910416709722, 1e-12));
    });

    test('feet input converts to square metres', () {
      final sqM = AreaConversionService.calculateSquareMetres(
        width: 10,
        length: 10,
        inputUnit: AreaConversionService.feet,
      );
      expect(sqM, closeTo(9.290304, 1e-9));
    });

    test('converts to square inches and square centimetres', () {
      final sqIn = AreaConversionService.calculateSquareInches(
        width: 2,
        length: 3,
        inputUnit: AreaConversionService.feet,
      );
      expect(sqIn, closeTo(864.0, 1e-12));

      final sqCm = AreaConversionService.calculateSquareCentimetres(
        width: 2,
        length: 3,
        inputUnit: AreaConversionService.meter,
      );
      expect(sqCm, closeTo(60000.0, 1e-9));
    });

    test('throws for unsupported unit', () {
      expect(
        () => AreaConversionService.calculateSquareFeet(
          width: 1,
          length: 1,
          inputUnit: 'Unsupported',
        ),
        throwsArgumentError,
      );
    });
  });
}
