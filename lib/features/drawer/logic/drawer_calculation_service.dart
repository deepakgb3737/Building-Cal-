enum DrawerCalcMode { equal, oneCustom, multipleCustom }

class DrawerCalculationService {
  static List<double>? parseCustomHeights(String input) {
    if (input.trim().isEmpty) return null;
    final values = <double>[];
    for (final part in input.split(',')) {
      final value = double.tryParse(part.trim());
      if (value == null || !value.isFinite || value <= 0) return null;
      values.add(value);
    }
    return values;
  }

  static DrawerCalcResult calculate({
    required double height,
    required int count,
    required double top,
    required double bottom,
    required double gap,
    DrawerCalcMode mode = DrawerCalcMode.equal,
    double? customHeight,
    List<double> customHeights = const [],
  }) {
    if (![height, top, bottom, gap].every((v) => v.isFinite) ||
        height <= 0 ||
        count <= 0 ||
        top < 0 ||
        bottom < 0 ||
        gap < 0) {
      throw const FormatException(
          'Enter valid height, drawer count and spaces.');
    }
    final custom = switch (mode) {
      DrawerCalcMode.equal => <double>[],
      DrawerCalcMode.oneCustom => [customHeight ?? double.nan],
      DrawerCalcMode.multipleCustom => List<double>.of(customHeights),
    };
    if (mode != DrawerCalcMode.equal && custom.isEmpty) {
      throw const FormatException('Enter custom drawer heights.');
    }
    if (custom.any((v) => !v.isFinite || v < 100)) {
      throw const FormatException(
          'All custom drawers must be at least 100 mm.');
    }
    final remaining = count - custom.length;
    if (remaining <= 0) {
      throw const FormatException(
          'Custom drawer count must be less than total drawers.');
    }
    final empty = top + bottom;
    final gaps = (count - 1) * gap;
    final available = height - empty - gaps;
    if (!available.isFinite || available <= 0) {
      throw const FormatException(
          'No space left for drawers. Reduce spaces or increase height.');
    }
    final raw =
        (available - custom.fold<double>(0, (a, b) => a + b)) / remaining;
    if (!raw.isFinite || raw < 100) {
      throw const FormatException(
          'Drawer size is too small. Reduce custom sizes or drawer count.');
    }
    final each = mode == DrawerCalcMode.equal ? raw : raw.floorToDouble();
    final heights = [...custom, ...List<double>.filled(remaining, each)];
    final labels = List<String>.generate(count, (i) {
      if (i >= custom.length) return 'Drawer ${i + 1}';
      return mode == DrawerCalcMode.oneCustom
          ? 'Custom Drawer'
          : 'Custom ${i + 1}';
    });
    return DrawerCalcResult(
      mode: mode,
      totalHeightMm: height,
      drawerCount: count,
      topEmptyMm: top,
      bottomEmptyMm: bottom,
      gapMm: gap,
      totalEmptyMm: empty,
      totalGapSpaceMm: gaps,
      totalNonDrawerSpaceMm: empty + gaps,
      drawerHeightMm: each,
      drawerHeightsMm: List.unmodifiable(heights),
      drawerLabels: List.unmodifiable(labels),
      customDrawerHeightMm: custom.isEmpty ? null : custom.first,
      customDrawerHeightsMm: List.unmodifiable(custom),
      remainingDrawerHeightMm: each,
      remainingDrawerCount: remaining,
    );
  }
}

class DrawerCalcResult {
  final DrawerCalcMode mode;
  final double totalHeightMm;
  final int drawerCount;
  final double topEmptyMm;
  final double bottomEmptyMm;
  final double gapMm;
  final double totalEmptyMm;
  final double totalGapSpaceMm;
  final double totalNonDrawerSpaceMm;
  final double drawerHeightMm;
  final List<double> drawerHeightsMm;
  final List<String> drawerLabels;
  final double? customDrawerHeightMm;
  final List<double> customDrawerHeightsMm;
  final double? remainingDrawerHeightMm;
  final int? remainingDrawerCount;

  const DrawerCalcResult({
    required this.mode,
    required this.totalHeightMm,
    required this.drawerCount,
    required this.topEmptyMm,
    required this.bottomEmptyMm,
    required this.gapMm,
    required this.totalEmptyMm,
    required this.totalGapSpaceMm,
    required this.totalNonDrawerSpaceMm,
    required this.drawerHeightMm,
    required this.drawerHeightsMm,
    required this.drawerLabels,
    required this.customDrawerHeightMm,
    required this.customDrawerHeightsMm,
    required this.remainingDrawerHeightMm,
    required this.remainingDrawerCount,
  });
}
