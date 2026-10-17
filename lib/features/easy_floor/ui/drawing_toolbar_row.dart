import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/ui/app_typography.dart';
import 'package:grid_ceiling_calculator/ui/app_styles.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';

class DrawingToolbarRow extends StatelessWidget {
  const DrawingToolbarRow(
      {super.key, required this.children, this.minimumWidth = 44});
  final List<Widget> children;
  final double minimumWidth;
  static double cellWidth(BuildContext context) =>
      math.max(44, MediaQuery.textScalerOf(context).scale(11) * 4);
  static const gap = 4.0;
  static double rowHeight(BuildContext context) =>
      34 + MediaQuery.textScalerOf(context).scale(11) * 2.4;
  static int columns(BuildContext context, double width, int count,
          {double minimumWidth = 44}) =>
      math.max(
          1,
          math.min(
              count,
              ((width + gap) /
                      (math.max(minimumWidth, cellWidth(context)) + gap))
                  .floor()));
  static double heightFor(BuildContext context, double width, int count) {
    final rows = (count / columns(context, width, count)).ceil();
    return rows * rowHeight(context) + (rows - 1) * gap;
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        final count = columns(context, bounds.maxWidth, children.length,
            minimumWidth: minimumWidth);
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final child in children)
            SizedBox(
                width: (bounds.maxWidth - (count - 1) * gap) / count,
                height: rowHeight(context),
                child: child)
        ]);
      });
}

Widget drawingTool(
        {required String label,
        required IconData icon,
        required VoidCallback? onPressed,
        String? tooltip,
        bool selected = false}) =>
    LayoutBuilder(
        builder: (context, bounds) => Tooltip(
            message: tooltip ?? label,
            child: ChoiceChip(
              selected: selected,
              showCheckmark: false,
              backgroundColor: AppColors.surfaceAlt,
              selectedColor: AppColors.blueSurface,
              disabledColor: AppColors.white,
              iconTheme: IconThemeData(
                  color: onPressed == null
                      ? AppColors.muted
                      : selected
                          ? AppColors.primary
                          : AppColors.ink),
              onSelected: onPressed == null ? null : (_) => onPressed(),
              padding: const EdgeInsets.all(4),
              labelPadding: EdgeInsets.zero,
              side: BorderSide.none,
              shape: const RoundedRectangleBorder(borderRadius: AppRadii.r8),
              label: SizedBox(
                  width: math.max(0, bounds.maxWidth - 8),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 22),
                        const SizedBox(height: 2),
                        Text(label,
                            textAlign: TextAlign.center,
                            style: AppTypography.drawingToolLabel.copyWith(
                                color: onPressed == null
                                    ? AppColors.muted
                                    : selected
                                        ? AppColors.primary
                                        : AppColors.ink)),
                      ])),
            )));
