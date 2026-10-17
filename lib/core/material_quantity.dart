abstract final class MaterialQuantity {
  static void positive(double value, String name, {double max = 1000000}) {
    if (!value.isFinite || value <= 0 || value > max) {
      throw ArgumentError('$name must be greater than 0 and at most $max.');
    }
  }

  static void nonNegative(double value, String name, {double max = 1000000}) {
    if (!value.isFinite || value < 0 || value > max) {
      throw ArgumentError('$name must be between 0 and $max.');
    }
  }

  static double netArea(double length, double width, double excludedArea) {
    positive(length, 'Length (m)', max: 1000);
    positive(width, 'Width / height (m)', max: 1000);
    nonNegative(excludedArea, 'Excluded area (m2)');
    final area = length * width - excludedArea;
    if (area <= 0) {
      throw ArgumentError('Excluded area must be smaller than the total area.');
    }
    return area;
  }

  static double withWaste(double quantity, double percent) {
    nonNegative(percent, 'Allowance (%)', max: 100);
    final total = quantity * (1 + percent / 100);
    positive(total, 'Calculated quantity', max: 1e12);
    return total;
  }

  static int packs(double quantity, double packSize) {
    positive(quantity, 'Quantity', max: 1e12);
    positive(packSize, 'Pack size');
    final count = quantity / packSize;
    if (!count.isFinite || count > 1e9) {
      throw ArgumentError(
          'Quantity is too large. Check dimensions and pack size.');
    }
    // Ignore only floating-point noise at an integer boundary.
    final nearest = count.round();
    return nearest > 0 && (count - nearest).abs() < 1e-10
        ? nearest
        : count.ceil();
  }
}
