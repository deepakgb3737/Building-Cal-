part of 'pvc_ceiling_painter.dart';

class PvcShapePreview extends StatelessWidget {
  const PvcShapePreview(
      {super.key, required this.room, this.active, this.thumbnail = false});
  final PvcRoom room;
  final String? active;
  final bool thumbnail;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final available = MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).bottom;
        final maxHeight = (available * .22).clamp(125.0, 160.0);
        final height =
            thumbnail ? 88.0 : (box.maxWidth * .4).clamp(110.0, maxHeight);
        final textScale = MediaQuery.textScalerOf(context).scale(13) / 13;
        return Semantics(
            label:
                '${room.shape.label} dimension diagram. Letters match the input fields.',
            child: SizedBox(
                height: height,
                width: double.infinity,
                child: CustomPaint(
                    painter: PvcShapePreviewPainter(room, active,
                        textScale: textScale, thumbnail: thumbnail))));
      });
}

class PvcShapePreviewPainter extends CustomPainter {
  PvcShapePreviewPainter(this.room, this.active,
      {double textScale = 1, this.thumbnail = false})
      : textScale = textScale.clamp(1, 1.5);
  final PvcRoom room;
  final String? active;
  final double textScale;
  final bool thumbnail;
  double get radius => (thumbnail ? 7 : 12) * textScale;

  List<Offset> _points(Size size) {
    final b = pvcBounds(room.points), padding = radius + (thumbnail ? 12 : 20);
    final scale = math.max(
        0.0,
        math.min((size.width - padding * 2) / b.width,
            (size.height - padding * 2) / b.height));
    final origin = Offset((size.width - b.width * scale) / 2,
        (size.height - b.height * scale) / 2);
    return room.points
        .map((p) => origin + Offset((p.x - b.x0) * scale, (p.y - b.y0) * scale))
        .toList();
  }

  Map<String, Offset> labelCenters(Size size) {
    final points = _points(size), path = Path()..addPolygon(points, true);
    final placed = <String, Offset>{};
    final occupied = <Rect>[];
    final safe = (Offset.zero & size).deflate(radius + 3);
    for (final entry in room.edges.entries) {
      final a = points[entry.value.$1],
          b = points[entry.value.$2],
          delta = b - a;
      final mid = (a + b) / 2;
      final tangent =
          delta.distance > .01 ? delta / delta.distance : const Offset(0, 1);
      var normal = Offset(-tangent.dy, tangent.dx);
      if (path.contains(mid + normal * 3)) normal = -normal;
      final candidates = <Offset>[
        for (final distance in [radius + 8, radius + 24, radius + 40])
          for (final shift in [0.0, -28.0, 28.0, -56.0, 56.0])
            mid + normal * distance + tangent * shift,
        for (var y = safe.top; y <= safe.bottom; y += radius * 2 + 8)
          for (var x = safe.left; x <= safe.right; x += radius * 2 + 8)
            Offset(x, y),
      ];
      candidates.sort((a, b) =>
          (a - mid).distanceSquared.compareTo((b - mid).distanceSquared));
      bool clear(Offset p) =>
          safe.contains(p) &&
          !occupied.any((r) =>
              r.overlaps(Rect.fromCircle(center: p, radius: radius + 3)));
      bool outsideWalls(Offset p) {
        if (path.contains(p)) return false;
        for (var i = 0; i < points.length; i++) {
          final a = points[i], d = points[(i + 1) % points.length] - a;
          final t = d.distanceSquared < .001
              ? 0.0
              : (((p - a).dx * d.dx + (p - a).dy * d.dy) / d.distanceSquared)
                  .clamp(0.0, 1.0);
          if ((p - (a + d * t)).distance < radius + 3) return false;
        }
        return true;
      }

      final center = candidates.where(clear).where(outsideWalls).firstOrNull ??
          candidates.where(clear).firstOrNull ??
          Offset(mid.dx.clamp(safe.left, safe.right),
              mid.dy.clamp(safe.top, safe.bottom));
      occupied.add(Rect.fromCircle(center: center, radius: radius + 3));
      placed[entry.key] = center;
    }
    return placed;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final points = _points(size), path = Path()..addPolygon(points, true);
    canvas.drawPath(path, _fill(AppColors.softSurface));
    canvas.drawPath(path, _stroke(AppColors.ink, 2));
    final labels = labelCenters(size);
    for (final entry in room.edges.entries) {
      final a = points[entry.value.$1],
          b = points[entry.value.$2],
          mid = (a + b) / 2;
      final selected = entry.key == active, center = labels[entry.key]!;
      final color = selected ? AppColors.primary : AppColors.ink;
      canvas.drawLine(a, b, _stroke(color, selected ? 5 : 3));
      if ((center - mid).distance > radius + 8.5) {
        canvas.drawLine(mid, center, _stroke(AppColors.muted, 1));
      }
      canvas.drawCircle(center, radius, _fill(color));
      _text(
          canvas,
          entry.key,
          center.dx,
          center.dy + (thumbnail ? 3 : 4.5) * textScale,
          (thumbnail ? 9 : 13) * textScale,
          weight: FontWeight.w700,
          color: AppColors.white);
    }
  }

  @override
  bool shouldRepaint(covariant PvcShapePreviewPainter old) =>
      old.room != room ||
      old.active != active ||
      old.textScale != textScale ||
      old.thumbnail != thumbnail;
}
