part of 'pvc_ceiling_painter.dart';

class PvcShapePreview extends StatelessWidget {
  const PvcShapePreview({super.key, required this.room, this.active});
  final PvcRoom room;
  final String? active;
  @override
  Widget build(BuildContext context) => Semantics(
        label:
            '${room.shape.label} dimension diagram. Letters match the input fields.',
        child: SizedBox(
            height: 230,
            width: double.infinity,
            child: CustomPaint(painter: _ShapePreviewPainter(room, active))),
      );
}

class _ShapePreviewPainter extends CustomPainter {
  _ShapePreviewPainter(this.room, this.active);
  final PvcRoom room;
  final String? active;
  @override
  void paint(Canvas canvas, Size size) {
    final b = pvcBounds(room.points);
    final scale =
        math.min((size.width - 92) / b.width, (size.height - 84) / b.height);
    final origin = Offset((size.width - b.width * scale) / 2,
        (size.height - b.height * scale) / 2);
    final points = room.points
        .map((p) => origin + Offset((p.x - b.x0) * scale, (p.y - b.y0) * scale))
        .toList();
    final path = Path()..addPolygon(points, true);
    canvas.drawPath(path, _fill(AppColors.softSurface));
    canvas.drawPath(path, _stroke(AppColors.ink, 2));
    final occupied = <Rect>[];
    for (final entry in room.edges.entries) {
      final a = points[entry.value.$1],
          b = points[entry.value.$2],
          delta = b - a;
      if (delta.distance < .01) continue;
      final mid = (a + b) / 2;
      var normal = Offset(-delta.dy, delta.dx) / delta.distance;
      if (path.contains(mid + normal * 3)) normal = -normal;
      final selected = entry.key == active;
      canvas.drawLine(
          a,
          b,
          _stroke(
              selected ? AppColors.primary : AppColors.ink, selected ? 6 : 3));
      var center = mid + normal * 20;
      for (final distance in [20.0, 34.0, 48.0]) {
        center = mid + normal * distance;
        center = Offset(center.dx.clamp(14, size.width - 14),
            center.dy.clamp(14, size.height - 14));
        if (!occupied.any(
            (r) => r.overlaps(Rect.fromCircle(center: center, radius: 14)))) {
          break;
        }
      }
      occupied.add(Rect.fromCircle(center: center, radius: 14));
      canvas.drawCircle(
          center, 12, _fill(selected ? AppColors.primary : AppColors.ink));
      _text(canvas, entry.key, center.dx, center.dy + 4.5, 13,
          weight: FontWeight.w700, color: AppColors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _ShapePreviewPainter old) =>
      old.room != room || old.active != active;
}
