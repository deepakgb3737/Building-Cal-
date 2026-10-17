import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/grid_ceiling_calculator.dart';

void main() {
  group('Grid tile calculations', () {
    test('tile counts are valid across center and one-side modes', () {
      const cases = <(double, double)>[
        (4000, 5000),
        (4250, 3750),
        (10000, 8000),
        (2000, 2000),
        (40000, 40000),
      ];

      for (final room in cases) {
        final width = room.$1;
        final length = room.$2;

        final center = GridCeilingCalculator.calculate(
          width,
          length,
          mode: PlacementMode.centerBased,
        );
        final oneSide = GridCeilingCalculator.calculate(
          width,
          length,
          mode: PlacementMode.oneSide,
        );

        expect(center.tilesRequired >= center.fullTilesRequired, isTrue);
        expect(oneSide.tilesRequired >= oneSide.fullTilesRequired, isTrue);
        expect(center.tilesRequired,
            center.fullTilesRequired + center.cutTilesRequired);
        expect(oneSide.tilesRequired,
            oneSide.fullTilesRequired + oneSide.cutTilesRequired);
        expect(
            center.optimizedTilesRequired >= center.fullTilesRequired, isTrue);
        expect(oneSide.optimizedTilesRequired >= oneSide.fullTilesRequired,
            isTrue);
      }
    });

    test('optimized purchase tiles are always at least full tile count', () {
      final result = GridCeilingCalculator.calculate(
        4250,
        3750,
        mode: PlacementMode.oneSide,
      );

      expect(result.optimizedTilesRequired >= result.fullTilesRequired, isTrue);
      expect(result.tilesRequired,
          result.fullTilesRequired + result.cutTilesRequired);
    });

    test('centered mode cut breakdown for 2438 x 3200 is stable', () {
      final result = GridCeilingCalculator.calculate(
        2438,
        3200,
        mode: PlacementMode.centerBased,
      );

      expect(result.fullTilesRequired, 12);
      expect(result.widthEdgeCutSizeMm, 319);
      expect(result.widthEdgeCutPieces, 12);
      expect(result.lengthEdgeCutSizeMm, 400);
      expect(result.lengthEdgeCutPieces, 10);
      expect(result.cornerOverlapPieces, 4);
    });
  });
}
