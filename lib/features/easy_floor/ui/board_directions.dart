import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';
import 'package:grid_ceiling_calculator/ui/app_typography.dart';

class BoardDirections extends StatelessWidget {
  const BoardDirections({super.key});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return Semantics(
        label:
            'Fixed plan directions: North up, South down, East right, West left. Not geographic North.',
        excludeSemantics: true,
        child: IgnorePointer(
            child: ColoredBox(
                color: AppColors.white.withValues(alpha: .9),
                child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox.square(
                          dimension: 48 * scale,
                          child: DefaultTextStyle(
                              style: AppTypography.text12W600Label,
                              child: Stack(children: [
                                Align(
                                    alignment: Alignment.topCenter,
                                    child: Text('N',
                                        style: AppTypography.text12W600Label
                                            .copyWith(
                                                color: AppColors.primary))),
                                const Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Text('S')),
                                const Align(
                                    alignment: Alignment.centerRight,
                                    child: Text('E')),
                                const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text('W')),
                                Center(
                                    child: Icon(Icons.add,
                                        size: 14 * scale,
                                        color: AppColors.neutralMuted)),
                              ]))),
                      const SizedBox(height: 2),
                      const Text('Plan axes', style: AppTypography.text11),
                    ])))));
  }
}
