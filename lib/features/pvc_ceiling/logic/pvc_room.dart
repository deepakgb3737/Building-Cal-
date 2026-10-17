import 'dart:math' as math;

typedef PvcPoint = ({double x, double y});
PvcPoint pvcPoint(num x, num y) => (x: x.toDouble(), y: y.toDouble());

enum PvcShape {
  rectangle('Rectangle'),
  l('L-shape'),
  t('T-shape'),
  u('U-shape'),
  angled('Angled wall'),
  cutCorner('Cut corner');

  const PvcShape(this.label);
  final String label;
}

class PvcDimension {
  const PvcDimension(this.key, this.label, this.initial,
      {this.optional = false});
  final String key, label;
  final double? initial;
  final bool optional;
}

List<PvcDimension> pvcDimensions(PvcShape shape) => switch (shape) {
      PvcShape.rectangle => const [
          PvcDimension('A', 'Room length', 14.5),
          PvcDimension('B', 'Room width', 11)
        ],
      PvcShape.l => const [
          PvcDimension('A', 'Long outer wall', 16),
          PvcDimension('B', 'Outer side', 12),
          PvcDimension('C', 'Step across', 6),
          PvcDimension('D', 'Step down', 5)
        ],
      PvcShape.t => const [
          PvcDimension('A', 'Full top width', 16),
          PvcDimension('B', 'Top part depth', 6),
          PvcDimension('C', 'Stem width', 6),
          PvcDimension('D', 'Stem length', 8),
          PvcDimension('E', 'Left shoulder (optional)', null, optional: true)
        ],
      PvcShape.u => const [
          PvcDimension('A', 'Full outer width', 16),
          PvcDimension('B', 'Outer side', 12),
          PvcDimension('C', 'Opening width', 6),
          PvcDimension('D', 'Opening depth', 7),
          PvcDimension('E', 'Left arm (optional)', null, optional: true)
        ],
      PvcShape.angled => const [
          PvcDimension('A', 'Straight base', 14),
          PvcDimension('B', 'Left side', 8),
          PvcDimension('C', 'Right side', 12)
        ],
      PvcShape.cutCorner => const [
          PvcDimension('A', 'Bottom wall', 14),
          PvcDimension('B', 'Left side', 11),
          PvcDimension('C', 'Top wall', 9),
          PvcDimension('D', 'Right side', 7)
        ],
    };

class PvcInputError implements Exception {
  const PvcInputError(this.field, this.message);
  final String field, message;
  @override
  String toString() => message;
}

class PvcRoom {
  PvcRoom(this.shape, List<PvcPoint> points, this.edges)
      : points = List.unmodifiable(points);
  final PvcShape shape;
  final List<PvcPoint> points;
  final Map<String, (int, int)> edges;
  double get area => polygonArea(points);
}

String? pvcFieldError(PvcShape shape, PvcDimension field, String text) {
  if (field.optional && text.trim().isEmpty) return null;
  final n = double.tryParse(text.trim().replaceAll(',', '.'));
  final min = shape == PvcShape.angled && field.key != 'A' ? 0.0 : .5;
  if (n == null || !n.isFinite || n < min || n > 100) {
    return 'Wall ${field.key}: enter ${min == 0 ? '0' : '0.5'} to 100 ft.';
  }
  return null;
}

PvcRoom buildPvcRoom(PvcShape shape, Map<String, String> text,
    {String corner = 'tr'}) {
  final v = <String, double?>{};
  for (final f in pvcDimensions(shape)) {
    final raw = text[f.key] ?? '';
    final error = pvcFieldError(shape, f, raw);
    if (error != null) throw PvcInputError(f.key, error);
    v[f.key] = raw.trim().isEmpty
        ? null
        : double.parse(raw.trim().replaceAll(',', '.'));
  }
  final a = v['A']!, b = v['B']!, c = v['C'] ?? 0, d = v['D'] ?? 0;
  final left = v['E'] ?? (a - c) / 2;
  void require(bool valid, String field, String message) {
    if (!valid) throw PvcInputError(field, message);
  }

  List<PvcPoint> p;
  Map<String, (int, int)> edges;
  switch (shape) {
    case PvcShape.rectangle:
      p = [pvcPoint(0, 0), pvcPoint(a, 0), pvcPoint(a, b), pvcPoint(0, b)];
      edges = {'A': (0, 1), 'B': (1, 2)};
    case PvcShape.l:
      require(c < a, 'C', 'Wall C must be shorter than wall A.');
      require(d < b, 'D', 'Wall D must be shorter than wall B.');
      require(const ['tr', 'tl', 'br', 'bl'].contains(corner), 'corner',
          'Choose a valid step-in corner.');
      p = [
        pvcPoint(0, 0),
        pvcPoint(a - c, 0),
        pvcPoint(a - c, d),
        pvcPoint(a, d),
        pvcPoint(a, b),
        pvcPoint(0, b)
      ];
      p = p
          .map((p) => pvcPoint(corner == 'tl' || corner == 'bl' ? a - p.x : p.x,
              corner == 'br' || corner == 'bl' ? b - p.y : p.y))
          .toList();
      edges = {'A': (4, 5), 'B': (5, 0), 'C': (2, 3), 'D': (1, 2)};
    case PvcShape.t:
      require(c < a, 'C', 'Wall C must be shorter than wall A.');
      require(left >= 0 && left + c <= a + 1e-9, 'E',
          'Walls E and C do not fit inside wall A.');
      p = [
        pvcPoint(0, 0),
        pvcPoint(a, 0),
        pvcPoint(a, b),
        pvcPoint(left + c, b),
        pvcPoint(left + c, b + d),
        pvcPoint(left, b + d),
        pvcPoint(left, b),
        pvcPoint(0, b)
      ];
      edges = {'A': (0, 1), 'B': (7, 0), 'C': (4, 5), 'D': (3, 4), 'E': (6, 7)};
    case PvcShape.u:
      require(d < b, 'D', 'Wall D must be shorter than wall B.');
      require(left > 0 && left + c < a - 1e-9, 'E',
          'The opening must fit inside wall A. Check C and E.');
      p = [
        pvcPoint(0, 0),
        pvcPoint(left, 0),
        pvcPoint(left, d),
        pvcPoint(left + c, d),
        pvcPoint(left + c, 0),
        pvcPoint(a, 0),
        pvcPoint(a, b),
        pvcPoint(0, b)
      ];
      edges = {'A': (6, 7), 'B': (7, 0), 'C': (2, 3), 'D': (1, 2), 'E': (0, 1)};
    case PvcShape.angled:
      require(
          math.max(b, c) >= .5, 'B', 'Wall B or C must be at least 0.5 ft.');
      final h = math.max(b, c);
      p = [
        pvcPoint(0, h - b),
        pvcPoint(a, h - c),
        pvcPoint(a, h),
        pvcPoint(0, h)
      ];
      edges = {'A': (2, 3), 'B': (3, 0), 'C': (1, 2)};
    case PvcShape.cutCorner:
      require(c < a, 'C', 'Wall C must be shorter than wall A.');
      require(d < b, 'D', 'Wall D must be shorter than wall B.');
      p = [
        pvcPoint(0, 0),
        pvcPoint(c, 0),
        pvcPoint(a, b - d),
        pvcPoint(a, b),
        pvcPoint(0, b)
      ];
      edges = {'A': (3, 4), 'B': (4, 0), 'C': (0, 1), 'D': (2, 3)};
  }
  require(polygonArea(p) > 1e-8, 'A', 'The room must have a positive area.');
  return PvcRoom(shape, p, edges);
}

Map<String, String> pvcDefaults(PvcShape shape) =>
    {for (final f in pvcDimensions(shape)) f.key: f.initial?.toString() ?? ''};

double polygonArea(List<PvcPoint> p) {
  var sum = 0.0;
  for (var i = 0; i < p.length; i++) {
    final a = p[i], b = p[(i + 1) % p.length];
    sum += a.x * b.y - b.x * a.y;
  }
  return sum.abs() / 2;
}

({double x0, double y0, double width, double height}) pvcBounds(
    List<PvcPoint> p) {
  final x0 = p.map((p) => p.x).reduce(math.min),
      y0 = p.map((p) => p.y).reduce(math.min);
  return (
    x0: x0,
    y0: y0,
    width: p.map((p) => p.x).reduce(math.max) - x0,
    height: p.map((p) => p.y).reduce(math.max) - y0
  );
}

List<(double, double)> scanPvcPolygon(List<PvcPoint> p, double y) {
  return _scanAt(p, y, false);
}

List<(double, double)> _scanAt(List<PvcPoint> p, double y, bool fromBelow) {
  final xs = <double>[];
  for (var i = 0; i < p.length; i++) {
    final a = p[i], b = p[(i + 1) % p.length];
    final crosses = fromBelow
        ? (a.y < y && b.y >= y) || (b.y < y && a.y >= y)
        : (a.y <= y && b.y > y) || (b.y <= y && a.y > y);
    if (crosses) {
      xs.add(a.x + (y - a.y) * (b.x - a.x) / (b.y - a.y));
    }
  }
  xs.sort();
  return [for (var i = 0; i + 1 < xs.length; i += 2) (xs[i], xs[i + 1])];
}

List<(double, double)> pvcRowIntervals(List<PvcPoint> p, double y0, double y1) {
  // Exact one-sided limits avoid undersized pieces on sloping walls.
  final all = [..._scanAt(p, y0, false), ..._scanAt(p, y1, true)];
  for (final point in p) {
    if (point.y > y0 && point.y < y1) {
      all.addAll([..._scanAt(p, point.y, false), ..._scanAt(p, point.y, true)]);
    }
  }
  all.sort((a, b) => a.$1.compareTo(b.$1));
  final merged = <(double, double)>[];
  for (final iv in all) {
    if (merged.isNotEmpty && iv.$1 <= merged.last.$2 + 1e-6) {
      merged[merged.length - 1] =
          (merged.last.$1, math.max(merged.last.$2, iv.$2));
    } else {
      merged.add(iv);
    }
  }
  return merged.where((iv) => iv.$2 - iv.$1 >= .05).toList();
}
