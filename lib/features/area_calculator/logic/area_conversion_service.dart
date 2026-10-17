class AreaConversionService {
  static const String meter = 'Meter';
  static const String feet = 'Feet';

  // Exact definition: 1 m = 3.280839895013123 ft.
  // Therefore, 1 m² = 10.763910416709722 ft².
  static const double _sqFtPerSqM = 10.763910416709722;
  static const double _sqCmPerSqM = 10000.0;
  static const double _sqInPerSqFt = 144.0;

  static List<String> get supportedUnits => const [meter, feet];

  static bool isSupported(String unit) => supportedUnits.contains(unit);

  static double calculateSquareFeet({
    required double width,
    required double length,
    required String inputUnit,
  }) {
    final areaInInputUnit = width * length;
    switch (inputUnit) {
      case meter:
        return areaInInputUnit * _sqFtPerSqM;
      case feet:
        return areaInInputUnit;
      default:
        throw ArgumentError('Unsupported area unit: $inputUnit');
    }
  }

  static double calculateSquareMetres({
    required double width,
    required double length,
    required String inputUnit,
  }) {
    final areaInInputUnit = width * length;
    switch (inputUnit) {
      case meter:
        return areaInInputUnit;
      case feet:
        return areaInInputUnit / _sqFtPerSqM;
      default:
        throw ArgumentError('Unsupported area unit: $inputUnit');
    }
  }

  static double calculateSquareCentimetres({
    required double width,
    required double length,
    required String inputUnit,
  }) {
    final sqM = calculateSquareMetres(
      width: width,
      length: length,
      inputUnit: inputUnit,
    );
    return sqM * _sqCmPerSqM;
  }

  static double calculateSquareInches({
    required double width,
    required double length,
    required String inputUnit,
  }) {
    final sqFt = calculateSquareFeet(
      width: width,
      length: length,
      inputUnit: inputUnit,
    );
    return sqFt * _sqInPerSqFt;
  }
}
