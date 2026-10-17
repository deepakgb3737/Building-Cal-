import 'package:grid_ceiling_calculator/core/material_quantity.dart';

abstract final class FlooringTileCalculator {
  static ({
    double area,
    double tileArea,
    int tiles,
    int boxes,
    int suppliedTiles
  }) calculate({
    required double lengthM,
    required double widthM,
    required double excludedM2,
    required double tileLengthMm,
    required double tileWidthMm,
    required double wastePercent,
    required int tilesPerBox,
  }) {
    final area = MaterialQuantity.netArea(lengthM, widthM, excludedM2);
    MaterialQuantity.positive(tileLengthMm, 'Tile length (mm)', max: 10000);
    MaterialQuantity.positive(tileWidthMm, 'Tile width (mm)', max: 10000);
    if (tilesPerBox < 1 || tilesPerBox > 10000) {
      throw ArgumentError(
          'Tiles per box must be a whole number from 1 to 10000.');
    }
    final tileArea = tileLengthMm * tileWidthMm / 1e6;
    final adjustedArea = MaterialQuantity.withWaste(area, wastePercent);
    final tiles = MaterialQuantity.packs(adjustedArea, tileArea);
    final boxes =
        MaterialQuantity.packs(tiles.toDouble(), tilesPerBox.toDouble());
    return (
      area: area,
      tileArea: tileArea,
      tiles: tiles,
      boxes: boxes,
      suppliedTiles: boxes * tilesPerBox
    );
  }
}
