import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/core/material_quantity.dart';

void main() {
  test(
      'Pack rounding preserves tiny positive quantities and integer boundaries',
      () {
    expect(MaterialQuantity.packs(1e-11, 1), 1);
    expect(MaterialQuantity.packs(.1 + .2, .1), 3);
    expect(MaterialQuantity.packs(3.00001, 1), 4);
    expect(MaterialQuantity.packs(3, 1), 3);
    expect(() => MaterialQuantity.packs(1e12, .001), throwsArgumentError);
    expect(() => MaterialQuantity.packs(-1, 1), throwsArgumentError);
  });
}
