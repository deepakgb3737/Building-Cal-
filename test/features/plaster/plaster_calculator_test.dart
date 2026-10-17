import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/plaster/logic/plaster_calculator.dart';

void main() {
  test('Plaster scales consumption from 10 mm and rounds bags up', () {
    final r = PlasterCalculator.calculate(
        lengthM: 10,
        heightM: 3,
        openingsM2: 5,
        thicknessMm: 20,
        kgPerM2At10Mm: 8,
        wastePercent: 10,
        bagKg: 25);
    expect(r.area, 25);
    expect(r.baseKg, 400);
    expect(r.kg, closeTo(440, 1e-10));
    expect(r.bags, 18);
  });
  test('Invalid consumption and bag size are rejected', () {
    for (final rate in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
          () => PlasterCalculator.calculate(
              lengthM: 10,
              heightM: 3,
              openingsM2: 0,
              thicknessMm: 10,
              kgPerM2At10Mm: rate,
              wastePercent: 0,
              bagKg: 25),
          throwsArgumentError);
    }
    expect(
        () => PlasterCalculator.calculate(
            lengthM: 10,
            heightM: 3,
            openingsM2: 0,
            thicknessMm: 10,
            kgPerM2At10Mm: 8,
            wastePercent: 0,
            bagKg: 0),
        throwsArgumentError);
  });
}
