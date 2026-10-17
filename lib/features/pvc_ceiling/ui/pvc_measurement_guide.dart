import 'package:flutter/material.dart';
import '../../../ui/app_typography.dart';
import '../../../ui/app_colors.dart';
import '../logic/pvc_ceiling_calculator.dart';
import 'pvc_ceiling_painter.dart';

class PvcMeasurementGuide extends StatelessWidget {
  const PvcMeasurementGuide({super.key, required this.room, this.active});
  final PvcRoom? room;
  final String? active;

  @override
  Widget build(BuildContext context) => Tooltip(
      message: room == null
          ? 'Enter valid dimensions to view the guide'
          : 'Enlarge measurement guide',
      child: Semantics(
          button: true,
          label: room == null
              ? 'Measurement guide unavailable. Check sizes.'
              : 'Enlarge measurement guide',
          child: InkWell(
              onTap: room == null
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                              scrollable: true,
                              title: Text('${room!.shape.label} measurements'),
                              content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                        width: 480,
                                        height:
                                            (MediaQuery.sizeOf(context).height *
                                                    .4)
                                                .clamp(120.0, 340.0),
                                        child: CustomPaint(
                                            painter: PvcShapePreviewPainter(
                                                room!, active,
                                                textScale:
                                                    MediaQuery.textScalerOf(
                                                                context)
                                                            .scale(13) /
                                                        13))),
                                    const Text(
                                        'Match A-E to the measurement fields.',
                                        style:
                                            AppTypography.text14Secondarytext),
                                  ]),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'))
                              ])),
              child: SizedBox(
                  width: 112,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (room != null)
                      PvcShapePreview(
                          room: room!, active: active, thumbnail: true)
                    else
                      const SizedBox(
                          height: 88,
                          child: Center(
                              child: Icon(Icons.straighten,
                                  color: AppColors.muted))),
                    Text(room == null ? 'Check sizes' : 'View guide',
                        style: AppTypography.text12W600Label),
                  ])))));
}
