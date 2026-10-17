import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/ui/material_estimate_screen.dart';
import '../logic/paint_calculator.dart';

class PaintScreen extends StatelessWidget {
  const PaintScreen({super.key});
  @override
  Widget build(BuildContext context) => MaterialEstimateScreen(
        title: 'Paint',
        description:
            'Estimate paint for one rectangular surface. Use the coverage per coat printed on your paint container.',
        inputs: const [
          EstimateInput('length', 'Surface length (m)', max: 1000),
          EstimateInput('height', 'Surface height / width (m)', max: 1000),
          EstimateInput('openings', 'Area not painted (m²)',
              initial: '0', zeroAllowed: true),
          EstimateInput('coverage', 'Coverage per coat (m²/L)', max: 1000),
          EstimateInput('coats', 'Number of coats',
              initial: '2', whole: true, max: 20),
          EstimateInput('waste', 'Extra allowance (%)',
              initial: '10', zeroAllowed: true, max: 100),
          EstimateInput('can', 'Container size (L)', initial: '4'),
        ],
        calculate: (v) {
          final r = PaintCalculator.calculate(
              lengthM: v['length']!,
              heightM: v['height']!,
              openingsM2: v['openings']!,
              coverageM2PerLitre: v['coverage']!,
              coats: v['coats']!.toInt(),
              wastePercent: v['waste']!,
              canLitres: v['can']!);
          return [
            EstimateValue('Containers to buy', '${r.cans}'),
            EstimateValue('Paint including allowance',
                '${r.litres.toStringAsFixed(2)} L'),
            EstimateValue(
                'Net surface area', '${r.area.toStringAsFixed(2)} m²'),
            EstimateValue('Paint before allowance',
                '${r.baseLitres.toStringAsFixed(2)} L'),
          ];
        },
        notes:
            'Area × coats ÷ coverage, then add your allowance. Containers round up. Surface condition and application affect coverage; confirm the product instructions. Primer is not included.',
      );
}
