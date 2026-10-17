import 'package:grid_ceiling_calculator/core/material_quantity.dart';

abstract final class PaintCalculator {
  static ({double area, double baseLitres, double litres, int cans}) calculate({
    required double lengthM,
    required double heightM,
    required double openingsM2,
    required double coverageM2PerLitre,
    required int coats,
    required double wastePercent,
    required double canLitres,
  }) {
    final area = MaterialQuantity.netArea(lengthM, heightM, openingsM2);
    MaterialQuantity.positive(coverageM2PerLitre, 'Coverage (m2/L per coat)',
        max: 1000);
    if (coats < 1 || coats > 20) {
      throw ArgumentError('Coats must be a whole number from 1 to 20.');
    }
    final base = area * coats / coverageM2PerLitre;
    final litres = MaterialQuantity.withWaste(base, wastePercent);
    return (
      area: area,
      baseLitres: base,
      litres: litres,
      cans: MaterialQuantity.packs(litres, canLitres)
    );
  }
}
