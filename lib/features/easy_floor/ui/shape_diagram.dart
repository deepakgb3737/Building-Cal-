import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';
import 'package:grid_ceiling_calculator/ui/app_typography.dart';
import '../logic/drawing_point.dart';
import '../logic/drawing_shapes.dart';

/// Uses the same real-world vertices as placement; only the view is scaled.
class ShapeDiagram extends CustomPainter {
  ShapeDiagram(this.spec, this.unit, this.active,
      {this.textScaler = TextScaler.noScaling, this.labelBounds});
  final ShapeSpec spec;
  final DrawingUnit unit;
  final ShapeDimension? active;
  final TextScaler textScaler;
  final Map<ShapeDimension, Rect>? labelBounds;

  @override
  void paint(Canvas canvas, Size size) {
    labelBounds?.clear();
    if (size.width <= 80 || size.height < 48) return;
    final points = spec.points(const DrawingPoint(0, 0));
    if (points.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final minX = points.map((p) => p.x).reduce(math.min);
    final minY = points.map((p) => p.y).reduce(math.min);
    final width = points.map((p) => p.x).reduce(math.max) - minX;
    final height = points.map((p) => p.y).reduce(math.max) - minY;
    final guideScale = math.min(1.0, size.height / 180);
    final scale = math.min(
        (size.width - 80) / width, (size.height - 110 * guideScale) / height);
    final origin = Offset((size.width - width * scale) / 2 - minX * scale,
        (size.height - height * scale) / 2 - minY * scale + 10 * guideScale);
    Offset view(DrawingPoint p) => origin + Offset(p.x, p.y) * scale;
    final path = Path()..moveTo(view(points.first).dx, view(points.first).dy);
    for (final p in points.skip(1)) {
      path.lineTo(view(p).dx, view(p).dy);
    }
    canvas.drawPath(path, Paint()..color = AppColors.blueSurface);
    canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.drawingInk
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
    final measurements = spec.measurements;
    final occupied = <Rect>[];
    final candidates = <Offset>[
      for (var y = -48.0; y <= 48; y += 8)
        for (var x = -48.0; x <= 48; x += 8) Offset(x, y),
    ]..sort((a, b) {
        final distance = a.distanceSquared.compareTo(b.distanceSquared);
        return distance != 0
            ? distance
            : a.dy != b.dy
                ? a.dy.compareTo(b.dy)
                : a.dx.compareTo(b.dx);
      });
    for (var i = 0; i < measurements.length; i++) {
      final m = measurements[i];
      final selected = active == m.id;
      final color = selected ? AppColors.primary : AppColors.secondaryText;
      final paint = Paint()
        ..color = color
        ..strokeWidth = selected ? 2 : 1;
      final a = view(m.start), b = view(m.end);
      final along = (b - a) / (b - a).distance;
      var outward = Offset(-along.dy, along.dx);
      final shapeCenter =
          view(DrawingPoint(minX + width / 2, minY + height / 2));
      if (outward.dx * ((a + b) / 2 - shapeCenter).dx +
              outward.dy * ((a + b) / 2 - shapeCenter).dy <
          0) {
        outward = -outward;
      }
      final offset = outward *
          (switch (m.id) {
            ShapeDimension.width => 42.0,
            ShapeDimension.leftArm || ShapeDimension.rightArm => 12.0,
            ShapeDimension.verticalArm || ShapeDimension.stem => 24.0,
            _ => 26.0,
          }) *
          guideScale;
      final from = a + offset, to = b + offset;
      canvas.drawLine(a, from, Paint()..color = color.withValues(alpha: .4));
      canvas.drawLine(b, to, Paint()..color = color.withValues(alpha: .4));
      canvas.drawLine(from, to, paint);
      final direction = (to - from) / (to - from).distance;
      final normal = Offset(-direction.dy, direction.dx);
      for (final endpoint in [(from, 1.0), (to, -1.0)]) {
        final tip = endpoint.$1, inside = direction * (4 * endpoint.$2);
        canvas.drawLine(tip, tip + inside + normal * 3, paint);
        canvas.drawLine(tip, tip + inside - normal * 3, paint);
      }
      if (selected) canvas.drawLine(a, b, paint);
      final fullText = '${m.letter} · ${unit.format(m.value)}';
      final text = TextPainter(
          textScaler: textScaler,
          text: TextSpan(
              text: fullText,
              style: AppTypography.label.copyWith(color: color)),
          textDirection: TextDirection.ltr)
        ..layout();
      // Short edges use the letter key; the full value remains in the legend.
      if (text.width + 12 > (to - from).distance || m.start.x == m.end.x) {
        text.text = TextSpan(
            text: m.letter, style: AppTypography.label.copyWith(color: color));
        text.layout();
      }
      final center = (from + to) / 2;
      Rect? rect;
      for (final offset in candidates) {
        final proposed = Rect.fromCenter(
            center: Offset(
                (center.dx + offset.dx)
                    .clamp(text.width / 2 + 6, size.width - text.width / 2 - 6),
                (center.dy + offset.dy).clamp(
                    text.height / 2 + 4, size.height - text.height / 2 - 4)),
            width: text.width + 8,
            height: text.height + 4);
        if (occupied.any((r) => r.inflate(2).overlaps(proposed))) continue;
        rect = proposed;
        break;
      }
      if (rect == null) {
        text.dispose();
        continue;
      }
      occupied.add(rect);
      labelBounds?[m.id] = rect;
      if ((rect.center - center).distance > 4) {
        canvas.drawLine(center, rect.center, paint);
      }
      canvas.drawRect(rect, Paint()..color = AppColors.white);
      text.paint(canvas, rect.topLeft + const Offset(4, 2));
      text.dispose();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ShapeDiagram oldDelegate) => true;
}
