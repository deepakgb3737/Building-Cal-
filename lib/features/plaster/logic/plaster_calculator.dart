import 'package:grid_ceiling_calculator/core/material_quantity.dart';

abstract final class PlasterCalculator {
  static ({double area, double baseKg, double kg, int bags}) calculate({
    required double lengthM,
    required double heightM,
    required double openingsM2,
    required double thicknessMm,
    required double kgPerM2At10Mm,
    required double wastePercent,
    required double bagKg,
  }) {
    final area = MaterialQuantity.netArea(lengthM, heightM, openingsM2);
    MaterialQuantity.positive(thicknessMm, 'Thickness (mm)', max: 100);
    MaterialQuantity.positive(kgPerM2At10Mm, 'Consumption (kg/m2 at 10 mm)',
        max: 1000);
    final base = area * thicknessMm / 10 * kgPerM2At10Mm;
    final kg = MaterialQuantity.withWaste(base, wastePercent);
    return (
      area: area,
      baseKg: base,
      kg: kg,
      bags: MaterialQuantity.packs(kg, bagKg)
    );
  }
}
