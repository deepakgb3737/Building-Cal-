import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/ui/material_estimate_screen.dart';
import '../logic/concrete_calculator.dart';

class ConcreteScreen extends StatelessWidget {
  const ConcreteScreen({super.key});
  @override
  Widget build(BuildContext context) => MaterialEstimateScreen(
        title: 'Concrete Volume',
        description:
            'Calculate volume for one rectangular slab or block with a uniform depth.',
        inputs: const [
          EstimateInput('length', 'Length (m)', max: 1000),
          EstimateInput('width', 'Width (m)', max: 1000),
          EstimateInput('depth', 'Depth / thickness (mm)', max: 10000),
          EstimateInput('allowance', 'Extra allowance (%)',
              initial: '5', zeroAllowed: true, max: 100),
        ],
        calculate: (v) {
          final r = ConcreteCalculator.calculate(
              lengthM: v['length']!,
              widthM: v['width']!,
              depthMm: v['depth']!,
              allowancePercent: v['allowance']!);
          return [
            EstimateValue('Volume including allowance',
                '${r.volume.toStringAsFixed(3)} m³'),
            EstimateValue('Volume before allowance',
                '${r.baseVolume.toStringAsFixed(3)} m³'),
            EstimateValue('Allowance volume',
                '${r.allowanceVolume.toStringAsFixed(3)} m³'),
            EstimateValue('Footprint area', '${r.area.toStringAsFixed(2)} m²'),
          ];
        },
        notes:
            'Length × width × depth in metres, then add your allowance. Volume is shown to 3 decimal places; calculations retain full precision. Confirm supplier order increments. This does not specify concrete grade, mix ratios, reinforcement or structural adequacy.',
      );
}
