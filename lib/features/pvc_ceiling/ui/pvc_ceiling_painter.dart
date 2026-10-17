import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../ui/app_colors.dart';
import '../../../ui/app_typography.dart';
import '../logic/pvc_ceiling_calculator.dart';
import 'pvc_format.dart';
part 'pvc_cut_painter.dart';
part 'pvc_shape_preview.dart';

enum _Anchor { start, middle, end }

void _text(
  Canvas canvas,
  String s,
  double x,
  double baseline,
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
  _Anchor anchor = _Anchor.middle,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: AppTypography.input
          .copyWith(fontSize: size, fontWeight: weight, color: color),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  final dx = switch (anchor) {
    _Anchor.start => x,
    _Anchor.middle => x - tp.width / 2,
    _Anchor.end => x - tp.width,
  };
  tp.paint(canvas, Offset(dx, baseline - base));
}

void _dashLine(Canvas canvas, Offset a, Offset b, Paint paint,
    {double on = 9, double off = 6}) {
  final total = (b - a).distance;
  if (total == 0) return;
  final dir = (b - a) / total;
  var d = 0.0;
  while (d < total) {
    final e = math.min(d + on, total);
    canvas.drawLine(a + dir * d, a + dir * e, paint);
    d += on + off;
  }
}

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w;

Paint _fill(Color c) => Paint()
  ..color = c
  ..style = PaintingStyle.fill;

// ---------------------------------------------------------------------------
// Ceiling layout painter
// ---------------------------------------------------------------------------

class LayoutGeometry {
  static const double padL = 110, padR = 165, padT = 104, padB = 178;
  final double sc;
  final double rw;
  final double rh;
  final double vw;
  final double vh;

  LayoutGeometry._(this.sc, this.rw, this.rh, this.vw, this.vh);

  factory LayoutGeometry.of(Layout c) {
    final sc = math.min((1000 - padL - padR) / c.run, 640 / c.across);
    final rw = c.run * sc;
    final rh = c.across * sc;
    return LayoutGeometry._(
      sc,
      rw,
      rh,
      (padL + rw + padR).roundToDouble(),
      (rh + padT + padB).roundToDouble(),
    );
  }
}

class CeilingPainter extends CustomPainter {
  final Layout c;
  final double k;
  CeilingPainter(this.c, this.k);

  @override
  void paint(Canvas canvas, Size size) {
    final g = LayoutGeometry.of(c);
    canvas.scale(size.width / g.vw);

    const x = LayoutGeometry.padL;
    const y = LayoutGeometry.padT;
    const t = 14.0;
    final sc = g.sc, rw = g.rw, rh = g.rh;

    final bounds = pvcBounds(c.polygon);
    Offset project(PvcPoint p) =>
        Offset(x + (p.x - bounds.x0) * sc, y + (p.y - bounds.y0) * sc);
    final polygon = Path()..addPolygon(c.polygon.map(project).toList(), true);
    canvas.drawPath(polygon, _stroke(AppColors.pvcWall, t * 2));
    canvas.drawPath(polygon, _fill(AppColors.pvcWall));
    canvas.save();
    canvas.clipPath(polygon);
    final labels = <({String text, Offset at})>[];
    for (final row in c.layoutRows) {
      final yy = y + (row.y0 - bounds.y0) * sc;
      final ph = row.width * sc;
      final visible = scanPvcPolygon(c.polygon, (row.y0 + row.y1) / 2);
      for (final segment in row.segments) {
        var from = segment.x0;
        for (var i = 0; i < segment.pieces.length; i++) {
          final p = segment.pieces[i], xx = x + (from - bounds.x0) * sc;
          final pw = p * sc;
          final rect = Rect.fromLTWH(xx, yy, pw, ph);
          canvas.drawRect(
              rect, _fill(AppColors.pvcPieces[c.sizes.indexOf(p) % 4]));
          canvas.drawRect(rect, _stroke(AppColors.white, 2));
          if (ph > 14) {
            for (var j = 1; j <= 3; j++) {
              canvas.drawLine(
                  Offset(xx, yy + ph * j / 4),
                  Offset(xx + pw, yy + ph * j / 4),
                  _stroke(AppColors.black.withValues(alpha: .16), 1));
            }
          }
          if (i > 0) {
            _dashLine(canvas, Offset(xx, yy), Offset(xx, yy + ph),
                _stroke(AppColors.pvcJoint, 3));
          }
          // Place text in the visible polygon, never in a cut-away corner.
          var width = 0.0, center = 0.0;
          for (final iv in visible) {
            final a = math.max(iv.$1, from), b = math.min(iv.$2, from + p);
            if (b - a > width) {
              width = b - a;
              center = (a + b) / 2;
            }
          }
          if (ph >= 22 && width * sc >= ftin(p).length * 9.5 * k + 14) {
            labels.add((
              text: ftin(p),
              at: Offset(x + (center - bounds.x0) * sc, yy + ph / 2 + 6 * k)
            ));
          }
          from += p;
        }
      }
    }
    canvas.restore();
    for (final label in labels) {
      _text(canvas, label.text, label.at.dx, label.at.dy, 17 * k,
          weight: FontWeight.w700, color: AppColors.white);
    }
    canvas.drawPath(polygon, _stroke(AppColors.ink, 2.5));
    for (var i = 0; i < c.layoutRows.length; i++) {
      final row = c.layoutRows[i], ph = row.width * sc;
      final cy = y + ((row.y0 + row.y1) / 2 - bounds.y0) * sc;
      if (ph >= 22) {
        const cx = x - t - 22;
        canvas.drawCircle(Offset(cx, cy), 12 * k,
            _fill(i == 0 ? AppColors.ink : AppColors.white));
        canvas.drawCircle(Offset(cx, cy), 12 * k, _stroke(AppColors.ink, 1.5));
        _text(canvas, '${i + 1}', cx, cy + 5 * k, 14 * k,
            weight: FontWeight.w700,
            color: i == 0 ? AppColors.white : AppColors.ink);
      }
      if (c.rows.edge > 0 && (i == 0 || i == c.rowsCount - 1)) {
        _text(canvas, 'cut ${ftin(row.width)}', x + rw + t + 12, cy + 5 * k,
            16 * k,
            weight: FontWeight.w600, anchor: _Anchor.start);
      }
    }
    const dy = y - 62;
    _arrowH(canvas, x, x + rw, dy);
    _text(canvas, '${ftin(c.run)}  (plank direction)', x + rw / 2, dy - 12,
        19 * k,
        weight: FontWeight.w700);
    const dx = x - t - 56;
    _arrowV(canvas, y, y + rh, dx);
    canvas.save();
    canvas.translate(dx - 12, y + rh / 2);
    canvas.rotate(-math.pi / 2);
    _text(canvas, '${ftin(c.across)}  (${c.rowsCount} rows)', 0, 0, 19 * k,
        weight: FontWeight.w700);
    canvas.restore();
    final legendY = y + rh + t + 42;
    if (c.joints > 0) {
      _dashLine(canvas, Offset(x, legendY), Offset(x + 34, legendY),
          _stroke(AppColors.pvcJoint, 3));
      _text(canvas, 'Joint between pieces', x + 44, legendY + 5, 15 * k,
          color: AppColors.muted, anchor: _Anchor.start);
    }
    _text(canvas, 'Start at row 1. Shaded band is the wall.', x, legendY + 33,
        15 * k,
        color: AppColors.muted, anchor: _Anchor.start);
  }

  void _arrowH(Canvas canvas, double a, double b, double v) {
    final p = _stroke(AppColors.muted, 1.5);
    canvas.drawLine(Offset(a, v), Offset(b, v), p);
    final f = _fill(AppColors.muted);
    canvas.drawPath(
        Path()
          ..moveTo(a, v)
          ..lineTo(a + 9, v - 4.5)
          ..lineTo(a + 9, v + 4.5)
          ..close(),
        f);
    canvas.drawPath(
        Path()
          ..moveTo(b, v)
          ..lineTo(b - 9, v - 4.5)
          ..lineTo(b - 9, v + 4.5)
          ..close(),
        f);
  }

  void _arrowV(Canvas canvas, double a, double b, double v) {
    final p = _stroke(AppColors.muted, 1.5);
    canvas.drawLine(Offset(v, a), Offset(v, b), p);
    final f = _fill(AppColors.muted);
    canvas.drawPath(
        Path()
          ..moveTo(v, a)
          ..lineTo(v - 4.5, a + 9)
          ..lineTo(v + 4.5, a + 9)
          ..close(),
        f);
    canvas.drawPath(
        Path()
          ..moveTo(v, b)
          ..lineTo(v - 4.5, b - 9)
          ..lineTo(v + 4.5, b - 9)
          ..close(),
        f);
  }

  @override
  bool shouldRepaint(covariant CeilingPainter old) => old.c != c || old.k != k;
}

// ---------------------------------------------------------------------------
// Cutting guide painter (one plank, drawn to scale)
// ---------------------------------------------------------------------------
