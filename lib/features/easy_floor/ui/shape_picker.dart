import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/ui/app_typography.dart';
import '../logic/drawing_shapes.dart';
import 'drawing_toolbar_row.dart';

Future<String?> showDrawingShapes(BuildContext context) => showModalBottomSheet<
        String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => FractionallySizedBox(
        heightFactor: .8,
        child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Shapes', style: AppTypography.text17W700Text),
                  const SizedBox(height: 8),
                  Expanded(
                      child: SingleChildScrollView(
                          child: DrawingToolbarRow(minimumWidth: 90, children: [
                    for (final kind in ShapePreset.values)
                      drawingTool(
                          label: kind == ShapePreset.polygon
                              ? 'Irregular Shape'
                              : kind.label,
                          icon: switch (kind) {
                            ShapePreset.square => Icons.crop_square,
                            ShapePreset.rectangle => Icons.crop_landscape,
                            ShapePreset.triangle => Icons.change_history,
                            ShapePreset.lShape => Icons.turn_right,
                            ShapePreset.uShape => Icons.u_turn_right,
                            ShapePreset.tShape => Icons.call_split,
                            ShapePreset.polygon => Icons.polyline_outlined,
                          },
                          onPressed: () => Navigator.pop(context, kind.name)),
                  ]))),
                ]))));
