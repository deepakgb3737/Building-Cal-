import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/ui/material_estimate_screen.dart';
import '../logic/flooring_tile_calculator.dart';

class FlooringTileScreen extends StatelessWidget {
  const FlooringTileScreen({super.key});
  @override
  Widget build(BuildContext context) => MaterialEstimateScreen(
        title: 'Flooring Tiles',
        description:
            'Estimate boxes for a rectangular floor. Enter the actual tile dimensions and the quantity in each box.',
        inputs: const [
          EstimateInput('length', 'Floor length (m)', max: 1000),
          EstimateInput('width', 'Floor width (m)', max: 1000),
          EstimateInput('excluded', 'Area not tiled (m²)',
              initial: '0', zeroAllowed: true),
          EstimateInput('tileLength', 'Tile length (mm)',
              initial: '600', max: 10000),
          EstimateInput('tileWidth', 'Tile width (mm)',
              initial: '600', max: 10000),
          EstimateInput('waste', 'Cutting / waste allowance (%)',
              initial: '10', zeroAllowed: true, max: 100),
          EstimateInput('pack', 'Tiles per box',
              initial: '4', whole: true, max: 10000),
        ],
        calculate: (v) {
          final r = FlooringTileCalculator.calculate(
              lengthM: v['length']!,
              widthM: v['width']!,
              excludedM2: v['excluded']!,
              tileLengthMm: v['tileLength']!,
              tileWidthMm: v['tileWidth']!,
              wastePercent: v['waste']!,
              tilesPerBox: v['pack']!.toInt());
          return [
            EstimateValue('Boxes to buy', '${r.boxes}'),
            EstimateValue('Tiles needed including allowance', '${r.tiles} pcs'),
            EstimateValue(
                'Tiles supplied by whole boxes', '${r.suppliedTiles} pcs'),
            EstimateValue('Net floor area', '${r.area.toStringAsFixed(2)} m²'),
            EstimateValue(
                'Area per tile', '${r.tileArea.toStringAsFixed(4)} m²'),
          ];
        },
        notes:
            'Net area × (1 + allowance ÷ 100) ÷ tile area. Tiles and boxes round up. This is an area-based estimate, not a cutting layout. Grout joints and reuse of offcuts are not modelled; diagonal patterns may need more allowance.',
      );
}
