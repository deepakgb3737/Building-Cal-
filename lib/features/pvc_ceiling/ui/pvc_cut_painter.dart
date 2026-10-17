part of 'pvc_ceiling_painter.dart';

class CutPainter extends CustomPainter {
  static const double viewW = 1000, viewH = 172;
  final CutGroup group;
  final List<double> sizes;
  CutPainter(this.group, this.sizes);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / viewW);

    const x0 = 40.0, w = 920.0, y = 46.0, bh = 60.0;
    final sc = w / group.stock;
    final nc = group.cuts.length;
    final scrap = group.scrap;
    final spans = group.spans;
    var k = 0;
    final marks = <void Function()>[];

    for (var i = 0; i < nc; i++) {
      final p = group.cuts[i];
      final xa = x0 + spans[i].start * sc;
      final pw = p * sc;
      canvas.drawRect(Rect.fromLTWH(xa, y, pw, bh),
          _fill(AppColors.pvcPieces[sizes.indexOf(p) % 4]));
      for (var g = 1; g <= 3; g++) {
        canvas.drawLine(
          Offset(xa, y + bh * g / 4),
          Offset(xa + pw, y + bh * g / 4),
          _stroke(AppColors.black.withValues(alpha: .14), 1.5),
        );
      }
      _text(canvas, ftin(p), xa + pw / 2, y + bh / 2 + 9,
          math.min(26.0, math.max(15.0, pw / 5.5)),
          weight: FontWeight.w700, color: AppColors.white);

      if (i < nc - 1 || scrap > 0) {
        k++;
        final number = k;
        final xc = x0 + spans[i].end * sc;
        final ly = y + bh + (k.isOdd ? 34 : 56);
        final reading = ftx(spans[i].end);
        _dashLine(canvas, Offset(xc, y - 10), Offset(xc, y + bh + 10),
            _stroke(AppColors.pvcJoint, 3),
            on: 7, off: 5);
        canvas.drawCircle(Offset(xc, y - 24), 14, _fill(AppColors.pvcJoint));
        _text(canvas, '$number', xc, y - 18, 17,
            weight: FontWeight.w700, color: AppColors.white);
        marks.add(() {
          canvas.drawLine(Offset(xc, y + bh + 14), Offset(xc, ly - 17),
              _stroke(AppColors.pvcJoint, 1.5));
          _text(canvas, reading, xc, ly, 16,
              weight: FontWeight.w700, color: AppColors.pvcJoint);
        });
      }
    }

    if (scrap > 0) {
      final xa = x0 + (group.stock - scrap) * sc;
      final pw = math.min(scrap * sc, x0 + w - xa);
      final rect = Rect.fromLTWH(xa, y, pw, bh);
      canvas.save();
      canvas.clipRect(rect);
      canvas.drawRect(rect, _fill(AppColors.pvcScrap));
      final hatch = _stroke(AppColors.pvcScrapHatch, 4);
      for (var t = -bh; t < pw + bh; t += 14.14) {
        canvas.drawLine(Offset(xa + t, y + bh), Offset(xa + t + bh, y), hatch);
      }
      canvas.restore();
      _text(canvas, pw > 150 ? 'scrap ${ftin(scrap)}' : 'scrap', xa + pw / 2,
          y + bh / 2 + 7, 18,
          color: AppColors.pvcScrapText);
    }

    canvas.drawRect(
        const Rect.fromLTWH(x0, y, w, bh), _stroke(AppColors.ink, 2));
    for (final m in marks) {
      m();
    }
  }

  @override
  bool shouldRepaint(covariant CutPainter old) =>
      old.group != group || old.sizes != sizes;
}
