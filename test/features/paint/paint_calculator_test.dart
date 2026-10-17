import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/paint/logic/paint_calculator.dart';

void main() {
  test('Paint deducts openings, multiplies coats and rounds containers up', () {
    final r = PaintCalculator.calculate(
        lengthM: 10,
        heightM: 3,
        openingsM2: 5,
        coverageM2PerLitre: 10,
        coats: 2,
        wastePercent: 10,
        canLitres: 4);
    expect(r.area, 25);
    expect(r.baseLitres, 5);
    expect(r.litres, closeTo(5.5, 1e-10));
    expect(r.cans, 2);
  });
  test('Paint rejects invalid rates, coats and exclusions', () {
    for (final coverage in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
          () => PaintCalculator.calculate(
              lengthM: 10,
              heightM: 3,
              openingsM2: 0,
              coverageM2PerLitre: coverage,
              coats: 2,
              wastePercent: 0,
              canLitres: 4),
          throwsArgumentError);
    }
    expect(
        () => PaintCalculator.calculate(
            lengthM: 10,
            heightM: 3,
            openingsM2: 30,
            coverageM2PerLitre: 10,
            coats: 2,
            wastePercent: 0,
            canLitres: 4),
        throwsArgumentError);
    expect(
        () => PaintCalculator.calculate(
            lengthM: 10,
            heightM: 3,
            openingsM2: 0,
            coverageM2PerLitre: 10,
            coats: 0,
            wastePercent: 0,
            canLitres: 4),
        throwsArgumentError);
  });
}
