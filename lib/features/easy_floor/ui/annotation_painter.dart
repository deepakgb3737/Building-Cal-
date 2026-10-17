import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';
import 'package:grid_ceiling_calculator/ui/app_typography.dart';
import '../logic/drawing_annotations.dart';

Color annotationColor(AnnotationInk ink) => switch (ink) {
      AnnotationInk.ink => AppColors.ink,
      AnnotationInk.blue => AppColors.primary,
      AnnotationInk.red => AppColors.error,
      AnnotationInk.green => AppColors.success,
      AnnotationInk.brown => AppColors.brown,
    };

/// Nominal size is measured at .1 pixels/mm; zoom changes rendering, not data.
double annotationFontPixels(double mm, double scale) => mm * scale;

TextPainter annotationTextLayout(DrawingAnnotation note) => TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: switch (note.alignment) {
      AnnotationAlignment.left => TextAlign.left,
      AnnotationAlignment.center => TextAlign.center,
      AnnotationAlignment.right => TextAlign.right,
    },
    text: TextSpan(
        text: note.text,
        style: AppTypography.text14W600Text.copyWith(
            fontSize: note.sizeMm * .1, color: annotationColor(note.ink))))
  ..layout(maxWidth: 240);

Size annotationWorldSize(DrawingAnnotation note) {
  final layout = annotationTextLayout(note);
  final size = layout.size * 10;
  layout.dispose();
  return size;
}

class AnnotationPainter extends CustomPainter {
  AnnotationPainter(
      {required this.annotations,
      required this.origin,
      required this.scale,
      required this.bounds,
      this.onEdit,
      this.selected = const {}});
  final DrawingAnnotations annotations;
  final Offset origin;
  final double scale;
  final Map<int, Rect> bounds;
  final Set<int> selected;
  final ValueChanged<int>? onEdit;

  @override
  void paint(Canvas canvas, Size size) {
    bounds.clear();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final note in annotations.items.values) {
      final factor =
          annotationFontPixels(note.sizeMm, scale) / (note.sizeMm * .1);
      final text = annotationTextLayout(note);
      final at =
          origin + Offset(note.position.x * scale, note.position.y * scale);
      final rect = at & (text.size * factor);
      bounds[note.id] = rect;
      if (selected.contains(note.id)) {
        final border = Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        canvas.drawRect(rect.inflate(5), border);
        for (final corner in [
          rect.topLeft,
          rect.topRight,
          rect.bottomLeft,
          rect.bottomRight
        ]) {
          canvas.drawCircle(corner, 3, Paint()..color = AppColors.primary);
        }
        if (selected.length == 1) {
          canvas.drawCircle(rect.bottomRight + const Offset(5, 5), 6,
              Paint()..color = AppColors.primary);
        }
      }
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.scale(factor);
      text.paint(canvas, Offset.zero);
      canvas.restore();
      text.dispose();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter oldDelegate) => true;

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) => [
        for (final note in annotations.items.values)
          if (bounds.containsKey(note.id) &&
              bounds[note.id]!.overlaps(Offset.zero & size))
            CustomPainterSemantics(
                rect: bounds[note.id]!.inflate(10),
                properties: SemanticsProperties(
                    label: note.text,
                    textDirection: TextDirection.ltr,
                    selected: selected.contains(note.id),
                    button: onEdit != null,
                    onTap: onEdit == null ? null : () => onEdit!(note.id)))
      ];

  @override
  bool shouldRebuildSemantics(covariant AnnotationPainter oldDelegate) => true;
}
