import 'package:grid_ceiling_calculator/core/material_quantity.dart';

abstract final class ConcreteCalculator {
  static ({
    double area,
    double baseVolume,
    double volume,
    double allowanceVolume
  }) calculate({
    required double lengthM,
    required double widthM,
    required double depthMm,
    required double allowancePercent,
  }) {
    final area = MaterialQuantity.netArea(lengthM, widthM, 0);
    MaterialQuantity.positive(depthMm, 'Depth (mm)', max: 10000);
    final base = area * depthMm / 1000;
    final volume = MaterialQuantity.withWaste(base, allowancePercent);
    return (
      area: area,
      baseVolume: base,
      volume: volume,
      allowanceVolume: volume - base
    );
  }
}
