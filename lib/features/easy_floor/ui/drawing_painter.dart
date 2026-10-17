import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';
import 'package:grid_ceiling_calculator/ui/app_typography.dart';
import '../logic/drawing_point.dart';
import '../logic/drawing_guides.dart';
import '../logic/drawing_angles.dart';
import '../logic/wall_network.dart';
import '../logic/measurement_groups.dart';
import 'wall_marker_painter.dart';

enum MeasurementLabelPriority { active, essential, secondary }

int? nearestWallLabel(Map<int, Rect> bounds, Offset position,
    {double padding = 0, int? preferredWall}) {
  int? chosen;
  var nearest = double.infinity;
  for (final entry in bounds.entries) {
    final rect = entry.value;
    if (!rect.inflate(padding).contains(position)) continue;
    final closest = Offset(position.dx.clamp(rect.left, rect.right),
        position.dy.clamp(rect.top, rect.bottom));
    final distance = (position - closest).distanceSquared;
    if (distance < nearest ||
        (distance == nearest &&
            (entry.key == preferredWall ||
                (chosen != preferredWall &&
                    (chosen == null || entry.key < chosen))))) {
      chosen = entry.key;
      nearest = distance;
    }
  }
  return chosen;
}

class DrawingPainter extends CustomPainter {
  DrawingPainter(
      {required this.model,
      required this.origin,
      required this.scale,
      required this.unit,
      required this.preview,
      this.allSelected = false,
      this.highlightedWalls = const {},
      this.highlightedCorners = const {},
      this.contextWalls = const {},
      this.rawStroke = const [],
      this.presetDimensions,
      this.presetHandle,
      this.showResizeAnchors = false,
      this.anglesEnabled = true,
      this.selectedWall,
      this.selectedCorner,
      this.connection,
      this.guides = const [],
      this.guideOpacity = .5,
      this.showAllMeasurements = false,
      this.labelOffsets,
      this.finger,
      this.moveOffset,
      this.navigationActive = false,
      this.editingCorner = false,
      this.editingActive = false,
      this.labelObstacles = const [],
      this.interfaceObstacles,
      this.tape,
      this.previewDashed = false,
      this.labelBounds});
  final (DrawingPoint, DrawingPoint)? tape;
  final bool previewDashed;
  Rect? tapeLabelBounds;
  final bool allSelected, anglesEnabled;
  final Set<int> highlightedWalls, highlightedCorners, contextWalls;
  final List<DrawingPoint> rawStroke;
  final String? presetDimensions;
  final DrawingPoint? presetHandle;
  final bool showResizeAnchors;
  List<CornerAngle> get angles => !anglesEnabled || navigationActive
      ? []
      : contextualAngles(model,
          wall: selectedWall ??
              (contextWalls.isEmpty ? null : contextWalls.first),
          corner: editingCorner ? selectedCorner : null,
          preview: preview);
  final List<DrawingGuide> guides;
  final double guideOpacity;
  final bool showAllMeasurements;
  final bool navigationActive;
  final bool editingCorner;
  final bool editingActive;
  final List<Rect> labelObstacles;
  final List<Rect> Function()? interfaceObstacles;
  Rect? previewLabelBounds;
  final _blockedLabelPositions = <(Rect, bool)>{};
  final Map<int, double>? labelOffsets;
  final Offset? finger;
  final double? moveOffset;
  Set<int> get measuredWalls => tape != null || preview.isNotEmpty
      ? {}
      : {
          for (final w in model.walls.values)
            if ((showAllMeasurements && (!editingActive || navigationActive)) ||
                (!navigationActive &&
                    (w.id == selectedWall ||
                        contextWalls.contains(w.id) ||
                        (selectedCorner != null &&
                            (w.start == selectedCorner ||
                                w.end == selectedCorner)))))
              w.id
        };
  final Map<int, Rect>? labelBounds;
  final DrawingPoint? connection;
  final WallNetwork model;
  final Offset origin;
  final double scale;
  final DrawingUnit unit;
  final List<DrawingPoint> preview;
  final int? selectedWall;
  final int? selectedCorner;
  Offset screen(DrawingPoint p) => origin + Offset(p.x * scale, p.y * scale);

  String wallMeasurementText(int id) {
    final length = model.length(id);
    final wall = model.walls[id]!;
    return '${unit.format(length)}'
        '${id == selectedWall ? '\nDir ${directionDegrees(model.corners[wall.start]!, model.corners[wall.end]!).toStringAsFixed(1)}°' : ''}';
  }

  @override
  void paint(Canvas canvas, Size size) {
    _blockedLabelPositions.clear();
    labelBounds?.clear();
    previewLabelBounds = null;
    tapeLabelBounds = null;
    canvas.clipRect(Offset.zero & size);
    var step = 1000.0;
    while (step * scale < 35) {
      step *= 2;
    }
    while (step * scale > 140) {
      step /= 2;
    }
    final gap = step * scale;
    void gridLines(double spacing, Paint paint) {
      for (var x = origin.dx % spacing; x < size.width; x += spacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      for (var y = origin.dy % spacing; y < size.height; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }

    if (gap / 5 >= 14) {
      gridLines(
          gap / 5,
          Paint()
            ..color = AppColors.drawingGridMinor
            ..strokeWidth = .5);
    }
    gridLines(
        gap,
        Paint()
          ..color = AppColors.drawingGridMajor
          ..strokeWidth = .75);
    final occupied = <Rect>[
      ...labelObstacles.map((r) => r.inflate(4)),
      ...?interfaceObstacles?.call().map((r) => r.inflate(4)),
      if (finger != null) Rect.fromCircle(center: finger!, radius: 28),
      if (connection != null)
        Rect.fromCircle(center: screen(connection!), radius: 16),
      for (final p in model.corners.values)
        Rect.fromCircle(center: screen(p), radius: 8),
    ];
    final guidePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: guideOpacity.clamp(0, 1))
      ..strokeWidth = 1;
    for (final guide in guides) {
      final a = screen(guide.start), b = screen(guide.end);
      final d = b - a;
      if (d.distance < 1) continue;
      final count = (d.distance / 8).ceil().clamp(1, 2000);
      for (var i = 0; i < count; i++) {
        final t = i / count;
        canvas.drawLine(
            a + d * t, a + d * math.min(1.0, t + .5 / count), guidePaint);
      }
      canvas.drawCircle(
          screen(guide.target), 5, guidePaint..style = PaintingStyle.stroke);
      guidePaint.style = PaintingStyle.fill;
    }
    final segmentPoints = [
      for (final wall in model.walls.values)
        (screen(model.corners[wall.start]!), screen(model.corners[wall.end]!)),
      for (var i = 1; i < preview.length; i++)
        (screen(preview[i - 1]), screen(preview[i]))
    ];
    final segments = [
      for (final segment in segmentPoints)
        (
          segment.$1,
          segment.$2,
          Rect.fromPoints(segment.$1, segment.$2).inflate(.001)
        ),
    ];
    for (final wall in model.walls.values) {
      final a = screen(model.corners[wall.start]!),
          b = screen(model.corners[wall.end]!);
      _wallLine(
          canvas,
          size,
          a,
          b,
          Paint()
            ..color = model.isFixed(wall.id)
                ? AppColors.drawingLockedWall
                : wall.id == selectedWall ||
                        allSelected ||
                        highlightedWalls.contains(wall.id)
                    ? AppColors.primary
                    : AppColors.ink
            ..strokeWidth = wall.id == selectedWall ||
                    allSelected ||
                    highlightedWalls.contains(wall.id)
                ? 4
                : 2.5
            ..strokeCap = StrokeCap.round,
          dashed: wall.dashed);
    }
    if (tape case final measurement?) {
      final a = screen(measurement.$1), b = screen(measurement.$2);
      final ink = Paint()
        ..color = AppColors.primary
        ..strokeWidth = 1.5;
      canvas.drawLine(a, b, ink);
      for (final point in [a, b]) {
        canvas.drawCircle(point, 5, Paint()..color = AppColors.white);
        canvas.drawCircle(point, 5, ink..style = PaintingStyle.stroke);
        occupied.add(Rect.fromCircle(center: point, radius: 8));
      }
      tapeLabelBounds = _label(
          canvas,
          size,
          'Tape ${unit.format((measurement.$2 - measurement.$1).length)}',
          a,
          b,
          occupied,
          segments,
          priority: MeasurementLabelPriority.active);
    }
    final measured = measuredWalls;
    final allSides = <int>{};
    final active = {
      if (selectedWall != null) selectedWall!,
      ...contextWalls,
      for (final wall in model.walls.values)
        if (selectedCorner != null &&
            (wall.start == selectedCorner || wall.end == selectedCorner))
          wall.id,
    };
    final priorities = {
      for (final id in measured)
        id: active.contains(id)
            ? MeasurementLabelPriority.active
            : MeasurementLabelPriority.essential,
    };
    bool visible(int id) {
      final w = model.walls[id]!;
      return _clipSegment(Offset.zero & size, screen(model.corners[w.start]!),
              screen(model.corners[w.end]!)) !=
          null;
    }

    if (measured.length > 1) {
      for (final group in redundantMeasurementGroups(model)) {
        final available = group.intersection(measured).toList()..sort();
        if (available.length < 2) continue;
        final keep = group.intersection(active).intersection(measured);
        final onScreen = available.where(visible).toList();
        if (!keep.any(visible) && onScreen.isNotEmpty) keep.add(onScreen.first);
        if (keep.isEmpty) keep.add(available.first);
        for (final id in group.difference(keep).intersection(measured)) {
          priorities[id] = MeasurementLabelPriority.secondary;
        }
        if (group.length == 4 && keep.length == 1 && !editingActive) {
          allSides.add(keep.single);
        }
      }
    }
    final ordered =
        model.walls.values.where((w) => measured.contains(w.id)).toList()
          ..sort((a, b) {
            if (a.id == b.id) return 0;
            final priority =
                priorities[a.id]!.index.compareTo(priorities[b.id]!.index);
            if (priority != 0) return priority;
            if (a.id == selectedWall) return -1;
            if (b.id == selectedWall) return 1;
            return a.id.compareTo(b.id);
          });
    for (final wall in model.walls.values) {
      paintWallMarkers(
          canvas, size, model.corners[wall.start]!, model.corners[wall.end]!,
          origin: origin, scale: scale);
    }
    if (showResizeAnchors &&
        selectedWall != null &&
        model.walls.containsKey(selectedWall)) {
      final wall = model.walls[selectedWall]!;
      for (final endpoint in [('A', wall.start), ('B', wall.end)]) {
        final at = screen(model.corners[endpoint.$2]!);
        _label(canvas, size, endpoint.$1, at, at, occupied, segments,
            priority: MeasurementLabelPriority.active);
      }
    }
    for (final wall in ordered) {
      // Exact duplicates remain inspectable by selection, never by extra clutter.
      if (priorities[wall.id] == MeasurementLabelPriority.secondary) continue;
      final a = screen(model.corners[wall.start]!),
          b = screen(model.corners[wall.end]!);
      _label(
          canvas,
          size,
          '${wallMeasurementText(wall.id)}${allSides.contains(wall.id) ? '\nAll sides' : ''}',
          a,
          b,
          occupied,
          segments,
          priority: priorities[wall.id]!,
          wallId: wall.id);
    }
    if (selectedWall != null &&
        moveOffset != null &&
        moveOffset! > .01 &&
        preview.isEmpty) {
      final w = model.walls[selectedWall];
      if (w != null) {
        _label(
            canvas,
            size,
            'Offset ${unit.format(moveOffset!)}',
            screen(model.corners[w.start]!),
            screen(model.corners[w.end]!),
            occupied,
            segments,
            priority: MeasurementLabelPriority.secondary);
      }
    }
    for (final entry in model.corners.entries) {
      canvas.drawCircle(
          screen(entry.value),
          entry.key == selectedCorner || highlightedCorners.contains(entry.key)
              ? 7
              : 4,
          Paint()
            ..color = entry.key == selectedCorner ||
                    highlightedCorners.contains(entry.key)
                ? AppColors.primary
                : AppColors.ink);
      canvas.drawCircle(
          screen(entry.value), 2, Paint()..color = AppColors.white);
    }
    if (connection != null) {
      final target = screen(connection!);
      canvas.drawCircle(
          target,
          10,
          Paint()
            ..color = AppColors.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      canvas.drawLine(target - const Offset(14, 0),
          target + const Offset(14, 0), Paint()..color = AppColors.primary);
      canvas.drawLine(target - const Offset(0, 14),
          target + const Offset(0, 14), Paint()..color = AppColors.primary);
    }
    if (rawStroke.length > 1) {
      final raw = Path()
        ..moveTo(screen(rawStroke.first).dx, screen(rawStroke.first).dy);
      for (final p in rawStroke.skip(1)) {
        raw.lineTo(screen(p).dx, screen(p).dy);
      }
      canvas.drawPath(
          raw,
          Paint()
            ..color = AppColors.primary.withValues(alpha: .3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
    }
    if (preview.length > 1) {
      final path = Path()
        ..moveTo(screen(preview.first).dx, screen(preview.first).dy);
      for (final p in preview.skip(1)) {
        final s = screen(p);
        path.lineTo(s.dx, s.dy);
      }
      final previewPaint = Paint()
        ..color = AppColors.primary
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      if (previewDashed) {
        for (var i = 1; i < preview.length; i++) {
          _wallLine(canvas, size, screen(preview[i - 1]), screen(preview[i]),
              previewPaint,
              dashed: true);
        }
      } else {
        canvas.drawPath(path, previewPaint);
      }
      for (var i = 1; i < preview.length; i++) {
        paintWallMarkers(canvas, size, preview[i - 1], preview[i],
            origin: origin, scale: scale);
      }
      final a = preview[preview.length - 2], b = preview.last;
      final d = b - a;
      if (!navigationActive) {
        if (presetDimensions != null) {
          for (var i = 1; i < preview.length; i++) {
            _label(
                canvas,
                size,
                unit.format((preview[i] - preview[i - 1]).length),
                screen(preview[i - 1]),
                screen(preview[i]),
                occupied,
                segments,
                priority: MeasurementLabelPriority.active);
          }
        } else {
          previewLabelBounds = _label(
              canvas,
              size,
              presetDimensions ??
                  '${unit.format(d.length)}\nDir ${directionDegrees(a, b).toStringAsFixed(1)}°',
              screen(a),
              screen(b),
              occupied,
              segments,
              priority: MeasurementLabelPriority.active);
        }
      }
      canvas.drawCircle(screen(b), 6, Paint()..color = AppColors.primary);
      if (presetHandle != null) {
        canvas.drawCircle(
            screen(presetHandle!), 7, Paint()..color = AppColors.primary);
        canvas.drawCircle(
            screen(presetHandle!), 3, Paint()..color = AppColors.white);
      }
    }
    for (final angle in angles) {
      final centre = screen(angle.corner);
      final a = angle.first - angle.corner, b = angle.second - angle.corner;
      if (a.length < .001 || b.length < .001) continue;
      if (math.min(a.length, b.length) * scale < 48) continue;
      final start = math.atan2(a.y, a.x);
      var sweep = math.atan2(b.y, b.x) - start;
      while (sweep > math.pi) {
        sweep -= 2 * math.pi;
      }
      while (sweep < -math.pi) {
        sweep += 2 * math.pi;
      }
      canvas.drawArc(
          Rect.fromCircle(center: centre, radius: 18),
          start,
          sweep,
          false,
          Paint()
            ..color = AppColors.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      final bisector = start + sweep / 2;
      final label =
          centre + Offset(math.cos(bisector), math.sin(bisector)) * 52;
      _label(canvas, size, 'Corner ${angle.degrees.toStringAsFixed(1)}°', label,
          label, occupied, segments,
          priority: MeasurementLabelPriority.secondary);
    }
    if (!navigationActive && anglesEnabled && angles.isEmpty) {
      for (final guide in guides) {
        final perpendicular = guide.kind == GuideKind.perpendicular;
        if (!perpendicular && guide.kind != GuideKind.parallel) continue;
        _label(canvas, size, perpendicular ? 'Align 90°' : 'Align 0°',
            screen(guide.start), screen(guide.end), occupied, segments,
            priority: MeasurementLabelPriority.secondary);
        break;
      }
    }
  }

  void _wallLine(Canvas canvas, Size viewport, Offset a, Offset b, Paint ink,
      {required bool dashed}) {
    if (!dashed) {
      canvas.drawLine(a, b, ink);
      return;
    }
    final visible = _clipSegment((Offset.zero & viewport).inflate(4), a, b);
    final delta = b - a;
    if (visible == null || delta.distance < .001) return;
    final direction = delta / delta.distance;
    final start = (visible.$1 - a).distance;
    final end = (visible.$2 - a).distance;
    // Screen-space dashes stay readable; clipping bounds work at extreme zoom.
    for (var offset = (start / 14).floor() * 14.0; offset < end; offset += 14) {
      final from = math.max(start, offset), to = math.min(end, offset + 8);
      if (to > from) {
        canvas.drawLine(a + direction * from, a + direction * to, ink);
      }
    }
  }

  Rect? _label(Canvas canvas, Size viewport, String text, Offset a, Offset b,
      List<Rect> occupied, List<(Offset, Offset, Rect)> walls,
      {required MeasurementLabelPriority priority, int? wallId}) {
    final important = priority == MeasurementLabelPriority.active;
    if (priority == MeasurementLabelPriority.secondary &&
        (b - a).distance > .001 &&
        (b - a).distance < 72) {
      return null;
    }
    final painter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
            text: text,
            style: AppTypography.text12W600Label.copyWith(
                color: important ? AppColors.primary : AppColors.text)))
      ..layout();
    final visible = _clipSegment(Offset.zero & viewport, a, b);
    if (visible == null ||
        painter.width + 18 > viewport.width ||
        painter.height + 14 > viewport.height) {
      painter.dispose();
      return null;
    }
    final delta = b - a;
    final normal = delta.distance < 1
        ? const Offset(0, -1)
        : Offset(delta.dy, -delta.dx) / delta.distance;
    Rect? chosen;
    final midpoint = (visible.$1 + visible.$2) / 2;
    final tangent =
        delta.distance < 1 ? const Offset(1, 0) : delta / delta.distance;
    bool fits(Rect rect) {
      final key = (rect, wallId != null);
      if (_blockedLabelPositions.contains(key)) return false;
      final labelSpace = rect.inflate(2);
      final wallSpace = rect.inflate(key.$2 ? 16 : 2);
      final blocked = occupied.any((r) => r.overlaps(labelSpace)) ||
          walls.any((wall) =>
              wall.$3.overlaps(wallSpace) &&
              _clipSegment(wallSpace, wall.$1, wall.$2) != null);
      // Obstacles only grow during this paint; rejected positions stay blocked.
      if (blocked) _blockedLabelPositions.add(key);
      return !blocked;
    }

    final width = painter.width + 10, height = painter.height + 6;
    final clearance = normal.dx.abs() * width / 2 +
        normal.dy.abs() * height / 2 +
        (wallId == null ? 6 : 16 * (normal.dx.abs() + normal.dy.abs()) + 2);
    final previous = wallId == null ? null : labelOffsets?[wallId];
    final candidates = <(Rect, double)>[];
    for (final extra in [0.0, 8.0, 16.0, 28.0, 44.0, 64.0, 96.0]) {
      for (final side in [1.0, -1.0]) {
        final distance = (clearance + extra) * side;
        for (final along in [
          0.0,
          -12.0,
          12.0,
          -24.0,
          24.0,
          -48.0,
          48.0,
          -72.0,
          72.0
        ]) {
          final centre = midpoint + normal * distance + tangent * along;
          final rect = Rect.fromCenter(
              center: Offset(
                  centre.dx
                      .clamp(width / 2 + 4, viewport.width - width / 2 - 4),
                  centre.dy
                      .clamp(height / 2 + 4, viewport.height - height / 2 - 4)),
              width: width,
              height: height);
          candidates.add((rect, distance));
        }
      }
    }
    // Retain the previous side only as a tie-break, never a distant placement.
    double score((Rect, double) candidate) =>
        (candidate.$1.center - midpoint).distanceSquared -
        (previous != null && previous.sign == candidate.$2.sign ? 1 : 0);
    candidates.sort((a, b) {
      final order = score(a).compareTo(score(b));
      return order != 0 ? order : b.$2.compareTo(a.$2);
    });
    for (final candidate in candidates) {
      if (!fits(candidate.$1)) continue;
      chosen = candidate.$1;
      if (wallId != null) labelOffsets?[wallId] = candidate.$2;
      break;
    }
    if (chosen == null && priority != MeasurementLabelPriority.secondary) {
      // Exhaust local placement before using clear space elsewhere in the canvas.
      var nearest = double.infinity;
      for (var y = 4.0; y + height <= viewport.height - 4; y += height + 8) {
        for (var x = 4.0; x + width <= viewport.width - 4; x += width + 8) {
          final rect = Rect.fromLTWH(x, y, width, height);
          final distance = (rect.center - midpoint).distanceSquared;
          if (distance < nearest && fits(rect)) {
            chosen = rect;
            nearest = distance;
          }
        }
      }
    }
    if (chosen == null) {
      painter.dispose();
      return null;
    }
    if (wallId != null) labelBounds?[wallId] = chosen;
    occupied.add(chosen);
    if (wallId != null ||
        (important && (chosen.center - midpoint).distance > 40)) {
      final entry = _clipSegment(chosen, midpoint, chosen.center);
      if (entry != null) {
        canvas.drawLine(
            midpoint,
            entry.$1,
            Paint()
              ..color = important ? AppColors.primary : AppColors.neutralMuted
              ..strokeWidth = .75);
      }
    }
    canvas.drawRect(chosen, Paint()..color = AppColors.white);
    painter.paint(canvas, chosen.topLeft + const Offset(5, 3));
    painter.dispose();
    return chosen;
  }

  (Offset, Offset)? _clipSegment(Rect rect, Offset a, Offset b) {
    final d = b - a;
    var low = 0.0, high = 1.0;
    for (final pair in [
      (-d.dx, a.dx - rect.left),
      (d.dx, rect.right - a.dx),
      (-d.dy, a.dy - rect.top),
      (d.dy, rect.bottom - a.dy)
    ]) {
      if (pair.$1.abs() < 1e-9) {
        if (pair.$2 < 0) return null;
      } else {
        final t = pair.$2 / pair.$1;
        if (pair.$1 < 0)
          low = math.max(low, t);
        else
          high = math.min(high, t);
      }
    }
    return low <= high ? (a + d * low, a + d * high) : null;
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}
