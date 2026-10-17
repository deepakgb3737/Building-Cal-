import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/flooring_tiles/logic/flooring_tile_calculator.dart';

void main() {
  test('Flooring converts mm to square metres and rounds tiles and boxes up',
      () {
    final r = FlooringTileCalculator.calculate(
        lengthM: 5,
        widthM: 4,
        excludedM2: 2,
        tileLengthMm: 600,
        tileWidthMm: 600,
        wastePercent: 10,
        tilesPerBox: 4);
    expect(r.area, 18);
    expect(r.tileArea, closeTo(.36, 1e-12));
    expect(r.tiles, 55);
    expect(r.boxes, 14);
    expect(r.suppliedTiles, 56);
  });
  test('Exact area with no waste does not add an extra box', () {
    final r = FlooringTileCalculator.calculate(
        lengthM: 3,
        widthM: 3,
        excludedM2: 0,
        tileLengthMm: 500,
        tileWidthMm: 500,
        wastePercent: 0,
        tilesPerBox: 4);
    expect(r.tiles, 36);
    expect(r.boxes, 9);
  });
  test('Tile dimensions, waste and box quantity are validated', () {
    for (final size in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
          () => FlooringTileCalculator.calculate(
              lengthM: 5,
              widthM: 4,
              excludedM2: 0,
              tileLengthMm: size,
              tileWidthMm: 600,
              wastePercent: 10,
              tilesPerBox: 4),
          throwsArgumentError);
    }
    expect(
        () => FlooringTileCalculator.calculate(
            lengthM: 5,
            widthM: 4,
            excludedM2: 0,
            tileLengthMm: 600,
            tileWidthMm: 600,
            wastePercent: 101,
            tilesPerBox: 4),
        throwsArgumentError);
    expect(
        () => FlooringTileCalculator.calculate(
            lengthM: 5,
            widthM: 4,
            excludedM2: 0,
            tileLengthMm: 600,
            tileWidthMm: 600,
            wastePercent: 0,
            tilesPerBox: 0),
        throwsArgumentError);
  });
}
