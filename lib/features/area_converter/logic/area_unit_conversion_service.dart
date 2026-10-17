class AreaUnitConversionService {
  static const String sqmm = 'sqmm';
  static const String sqcm = 'sqcm';
  static const String sqinch = 'sqinch';
  static const String sqft = 'sqft';
  static const String sqm = 'sqm';

  // Exact definitions to square metre.
  static const Map<String, double> _toSquareMetre = {
    sqmm: 1e-6,
    sqcm: 1e-4,
    sqinch: 0.00064516,
    sqft: 0.09290304,
    sqm: 1.0,
  };

  static bool isSupported(String unit) => _toSquareMetre.containsKey(unit);

  static double convert({
    required double value,
    required String fromUnit,
    required String toUnit,
  }) {
    final fromFactor = _toSquareMetre[fromUnit];
    final toFactor = _toSquareMetre[toUnit];

    if (fromFactor == null || toFactor == null) {
      throw ArgumentError(
          'Unsupported area unit conversion: $fromUnit -> $toUnit');
    }

    if (fromUnit == toUnit) {
      return value;
    }

    final areaInSquareMetre = value * fromFactor;
    return areaInSquareMetre / toFactor;
  }
}
