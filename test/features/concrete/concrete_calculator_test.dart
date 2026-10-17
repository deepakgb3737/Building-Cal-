import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/concrete/logic/concrete_calculator.dart';

void main() {
  test('Slab depth converts millimetres to metres before allowance', () {
    final r = ConcreteCalculator.calculate(
        lengthM: 5, widthM: 4, depthMm: 100, allowancePercent: 5);
    expect(r.area, 20);
    expect(r.baseVolume, 2);
    expect(r.volume, closeTo(2.1, 1e-12));
    expect(r.allowanceVolume, closeTo(.1, 1e-12));
  });
  test('Fractional depth retains full precision', () {
    final r = ConcreteCalculator.calculate(
        lengthM: 2.5, widthM: 1.2, depthMm: 75.5, allowancePercent: 0);
    expect(r.volume, closeTo(.2265, 1e-12));
    expect(r.allowanceVolume, 0);
  });
  test('Invalid dimensions and allowance are rejected', () {
    for (final depth in [0.0, -1.0, double.nan, double.infinity, 10001.0]) {
      expect(
          () => ConcreteCalculator.calculate(
              lengthM: 5, widthM: 4, depthMm: depth, allowancePercent: 5),
          throwsArgumentError);
    }
    expect(
        () => ConcreteCalculator.calculate(
            lengthM: 0, widthM: 4, depthMm: 100, allowancePercent: 5),
        throwsArgumentError);
    expect(
        () => ConcreteCalculator.calculate(
            lengthM: 5, widthM: 4, depthMm: 100, allowancePercent: -1),
        throwsArgumentError);
  });
}
