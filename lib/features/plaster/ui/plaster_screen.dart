import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/ui/material_estimate_screen.dart';
import '../logic/plaster_calculator.dart';

class PlasterScreen extends StatelessWidget {
  const PlasterScreen({super.key});
  @override
  Widget build(BuildContext context) => MaterialEstimateScreen(
        title: 'Plaster',
        description:
            'Estimate dry plaster bags for a rectangular surface. Use your product’s consumption at 10 mm thickness.',
        inputs: const [
          EstimateInput('length', 'Surface length (m)', max: 1000),
          EstimateInput('height', 'Surface height / width (m)', max: 1000),
          EstimateInput('openings', 'Area not plastered (m²)',
              initial: '0', zeroAllowed: true),
          EstimateInput('thickness', 'Average thickness (mm)',
              initial: '10', max: 100),
          EstimateInput('rate', 'Consumption at 10 mm (kg/m²)', max: 1000),
          EstimateInput('waste', 'Extra allowance (%)',
              initial: '10', zeroAllowed: true, max: 100),
          EstimateInput('bag', 'Bag weight (kg)', initial: '25'),
        ],
        calculate: (v) {
          final r = PlasterCalculator.calculate(
              lengthM: v['length']!,
              heightM: v['height']!,
              openingsM2: v['openings']!,
              thicknessMm: v['thickness']!,
              kgPerM2At10Mm: v['rate']!,
              wastePercent: v['waste']!,
              bagKg: v['bag']!);
          return [
            EstimateValue('Bags to buy', '${r.bags}'),
            EstimateValue('Dry material including allowance',
                '${r.kg.toStringAsFixed(2)} kg'),
            EstimateValue(
                'Net surface area', '${r.area.toStringAsFixed(2)} m²'),
            EstimateValue('Dry material before allowance',
                '${r.baseKg.toStringAsFixed(2)} kg'),
          ];
        },
        notes:
            'Net area × consumption at 10 mm × (thickness ÷ 10), then add your allowance. Bags round up. Confirm permitted thickness and consumption with the manufacturer. Uneven surfaces change the average thickness. Water and primer are not included.',
      );
}
