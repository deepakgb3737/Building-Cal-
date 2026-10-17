class UnitConversionService {
  static const String kilometre = 'Kilometre';
  static const String metre = 'Metre';
  static const String centimetre = 'Centimetre';
  static const String millimetre = 'Millimetre';
  static const String mile = 'Mile';
  static const String foot = 'Foot';
  static const String inch = 'Inch';
  static const String nauticalMile = 'Nautical mile';

  // Exact SI/Imperial definitions converted to metres.
  static const Map<String, double> _toMetres = {
    kilometre: 1000.0,
    metre: 1.0,
    centimetre: 0.01,
    millimetre: 0.001,
    mile: 1609.344,
    foot: 0.3048,
    inch: 0.0254,
    nauticalMile: 1852.0,
  };

  static const List<String> _displayOrder = [
    millimetre,
    centimetre,
    inch,
    foot,
    metre,
    kilometre,
    mile,
    nauticalMile,
  ];

  static List<String> get units => _displayOrder;

  static bool isSupported(String unit) => _toMetres.containsKey(unit);

  static double convert({
    required double value,
    required String fromUnit,
    required String toUnit,
  }) {
    final fromFactor = _toMetres[fromUnit];
    final toFactor = _toMetres[toUnit];

    if (fromFactor == null || toFactor == null) {
      throw ArgumentError('Unsupported unit conversion: $fromUnit -> $toUnit');
    }

    if (fromUnit == toUnit) {
      return value;
    }

    final metres = value * fromFactor;
    return metres / toFactor;
  }
}
