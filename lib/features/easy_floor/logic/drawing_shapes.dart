import 'dart:math' as math;
import 'drawing_point.dart';
import 'wall_network.dart';

enum ShapePreset {
  square,
  rectangle,
  triangle,
  lShape,
  uShape,
  tShape,
  polygon
}

extension ShapeName on ShapePreset {
  String get label => switch (this) {
        ShapePreset.square => 'Square',
        ShapePreset.rectangle => 'Rectangle',
        ShapePreset.triangle => 'Triangle',
        ShapePreset.lShape => 'L-shape',
        ShapePreset.uShape => 'U-shape',
        ShapePreset.tShape => 'T-shape',
        ShapePreset.polygon => 'Freeform polygon',
      };
}

enum ShapeDimension {
  width,
  height,
  verticalArm,
  horizontalArm,
  leftArm,
  rightArm,
  base,
  topBar,
  stem
}

class ShapeMeasurement {
  const ShapeMeasurement(this.id, this.name, this.start, this.end, this.value);
  final ShapeDimension id;
  final String name;
  final DrawingPoint start, end;
  final double value;
  String get letter => switch (id) {
        ShapeDimension.width => 'A',
        ShapeDimension.height => 'B',
        ShapeDimension.verticalArm ||
        ShapeDimension.leftArm ||
        ShapeDimension.topBar =>
          'C',
        ShapeDimension.horizontalArm ||
        ShapeDimension.rightArm ||
        ShapeDimension.stem =>
          'D',
        ShapeDimension.base => 'E',
      };
}

enum LShapeOrientation {
  topLeft('Top left', false, false),
  topRight('Top right', true, false),
  bottomRight('Bottom right', true, true),
  bottomLeft('Bottom left', false, true);

  const LShapeOrientation(this.label, this.flipX, this.flipY);
  final String label;
  final bool flipX, flipY;
}

class ShapeSpec {
  const ShapeSpec(this.kind, this.width, this.height, this.rotation,
      {this.details = const {}, this.orientation = LShapeOrientation.topLeft});
  final ShapePreset kind;
  final double width, height, rotation;
  final Map<ShapeDimension, double> details;
  final LShapeOrientation orientation;
  double get verticalArm => details[ShapeDimension.verticalArm] ?? width * .4;
  double get horizontalArm =>
      details[ShapeDimension.horizontalArm] ?? height * .4;
  double get leftArm => details[ShapeDimension.leftArm] ?? width * .3;
  double get rightArm => details[ShapeDimension.rightArm] ?? width * .3;
  double get base => details[ShapeDimension.base] ?? height * .3;
  double get topBar => details[ShapeDimension.topBar] ?? height * .3;
  double get stem => details[ShapeDimension.stem] ?? width * .3;

  Map<ShapeDimension, String> get dimensionErrors => {
        if (kind == ShapePreset.lShape) ...{
          if (!verticalArm.isFinite ||
              verticalArm < 10 ||
              width - verticalArm < 10)
            ShapeDimension.verticalArm:
                'Use 10 mm to overall length (A) minus 10 mm.',
          if (!horizontalArm.isFinite ||
              horizontalArm < 10 ||
              height - horizontalArm < 10)
            ShapeDimension.horizontalArm:
                'Use 10 mm to overall width (B) minus 10 mm.',
        }
      };

  DrawingPoint _transform(DrawingPoint point) {
    final x = kind == ShapePreset.lShape && orientation.flipX
        ? width - point.x
        : point.x;
    final y = kind == ShapePreset.lShape && orientation.flipY
        ? height - point.y
        : point.y;
    final angle = rotation * math.pi / 180;
    return DrawingPoint(x * math.cos(angle) - y * math.sin(angle),
        x * math.sin(angle) + y * math.cos(angle));
  }

  List<(String, double)> get derivedMeasurements => switch (kind) {
        ShapePreset.lShape => [
            ('Inner Length', width - verticalArm),
            ('Inner Width', height - horizontalArm)
          ],
        ShapePreset.uShape => [
            ('Opening Width', width - leftArm - rightArm),
            ('Opening Depth', height - base)
          ],
        ShapePreset.tShape => [('Stem Height', height - topBar)],
        ShapePreset.triangle => [
            ('Sloping Side', math.sqrt(width * width + height * height))
          ],
        _ => [],
      };

  List<ShapeMeasurement> get measurements {
    ShapeMeasurement m(ShapeDimension id, String name, double x, double y,
            double a, double b) =>
        // Rigid transforms retain the exact input span, avoiding rotation drift.
        ShapeMeasurement(id, name, _transform(DrawingPoint(x, y)),
            _transform(DrawingPoint(a, b)), DrawingPoint(a - x, b - y).length);
    final h = kind == ShapePreset.square ? width : height;
    return [
      m(
          ShapeDimension.width,
          kind == ShapePreset.square
              ? 'Side'
              : kind == ShapePreset.triangle
                  ? 'Base'
                  : 'Overall Length',
          0,
          0,
          width,
          0),
      if (kind != ShapePreset.square)
        m(
            ShapeDimension.height,
            kind == ShapePreset.triangle
                ? 'Perpendicular Height'
                : 'Overall Width',
            0,
            0,
            0,
            h),
      if (kind == ShapePreset.lShape) ...[
        m(ShapeDimension.verticalArm, 'Vertical Arm Width (within A)', 0, h,
            verticalArm, h),
        m(ShapeDimension.horizontalArm, 'Horizontal Arm Depth (within B)',
            width, 0, width, horizontalArm),
      ],
      if (kind == ShapePreset.uShape) ...[
        m(ShapeDimension.leftArm, 'Left Arm Width', 0, 0, leftArm, 0),
        m(ShapeDimension.rightArm, 'Right Arm Width', width - rightArm, 0,
            width, 0),
        m(ShapeDimension.base, 'Base Depth', width, h - base, width, h),
      ],
      if (kind == ShapePreset.tShape) ...[
        m(ShapeDimension.topBar, 'Top Bar Depth', width, 0, width, topBar),
        m(ShapeDimension.stem, 'Stem Width (centred)', (width - stem) / 2, h,
            (width + stem) / 2, h),
      ],
    ];
  }

  ShapeSpec resized(double newWidth, double newHeight) => ShapeSpec(kind,
      newWidth, kind == ShapePreset.square ? newWidth : newHeight, rotation,
      orientation: orientation,
      details: Map.unmodifiable({
        for (final m in measurements.skip(2))
          m.id: m.value *
              ({
                ShapeDimension.horizontalArm,
                ShapeDimension.base,
                ShapeDimension.topBar
              }.contains(m.id)
                  ? newHeight / height
                  : newWidth / width),
      }));

  List<DrawingPoint> points(DrawingPoint origin) {
    if (![width, height, rotation].every((v) => v.isFinite) ||
        width < 10 ||
        height < 10 ||
        width > 10000000 ||
        height > 10000000) {
      throw const DrawingConflict(
          'Shape dimensions must be 10 mm to 10,000 m.');
    }
    final extras = measurements.skip(2);
    if (extras.any(
            (m) => !m.value.isFinite || m.value < 10 || m.value > 10000000) ||
        details.values.any((v) => !v.isFinite || v < 10)) {
      throw const DrawingConflict('Arm dimensions must be at least 10 mm.');
    }
    if (dimensionErrors.isNotEmpty) {
      throw DrawingConflict(dimensionErrors.values.first);
    }
    if (kind == ShapePreset.uShape &&
        (leftArm + rightArm >= width || base >= height)) {
      throw const DrawingConflict(
          'Leave an opening: arm widths together must be less than overall length, and base depth less than overall width.');
    }
    if (kind == ShapePreset.tShape && (stem >= width || topBar >= height)) {
      throw const DrawingConflict(
          'Stem width must be less than overall length, and top bar depth less than overall width.');
    }
    final normalized = switch (kind) {
      ShapePreset.square || ShapePreset.rectangle => [
          (0.0, 0.0),
          (1.0, 0.0),
          (1.0, 1.0),
          (0.0, 1.0)
        ],
      ShapePreset.triangle => [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0)],
      ShapePreset.lShape => [
          (0.0, 0.0),
          (1.0, 0.0),
          (1.0, horizontalArm / height),
          (verticalArm / width, horizontalArm / height),
          (verticalArm / width, 1.0),
          (0.0, 1.0)
        ],
      ShapePreset.uShape => [
          (0.0, 0.0),
          (leftArm / width, 0.0),
          (leftArm / width, 1 - base / height),
          (1 - rightArm / width, 1 - base / height),
          (1 - rightArm / width, 0.0),
          (1.0, 0.0),
          (1.0, 1.0),
          (0.0, 1.0)
        ],
      ShapePreset.tShape => [
          (0.0, 0.0),
          (1.0, 0.0),
          (1.0, topBar / height),
          ((1 + stem / width) / 2, topBar / height),
          ((1 + stem / width) / 2, 1.0),
          ((1 - stem / width) / 2, 1.0),
          ((1 - stem / width) / 2, topBar / height),
          (0.0, topBar / height)
        ],
      ShapePreset.polygon => <(double, double)>[],
    };
    final h = kind == ShapePreset.square ? width : height;
    final points = [
      for (final p in normalized)
        origin + _transform(DrawingPoint(p.$1 * width, p.$2 * h))
    ];
    if (points.isNotEmpty &&
        List.generate(
            points.length,
            (i) =>
                (points[(i + 1) % points.length] - points[i]).length <
                10 - 1e-6).any((v) => v)) {
      throw const DrawingConflict(
          'This shape has a segment below 10 mm. Increase its dimensions.');
    }
    return points.isEmpty ? points : [...points, points.first];
  }
}

class ShapeSuggestion {
  const ShapeSuggestion(this.kind, this.points);
  final ShapePreset kind;
  final List<DrawingPoint> points;
}

/// Conservative closed-outline recognition; never coerces an irregular polygon.
ShapeSuggestion? recognizeShape(List<DrawingPoint> stroke) {
  if (stroke.length < 4 || (stroke.first - stroke.last).length > .001) {
    return null;
  }
  final pts = stroke.take(stroke.length - 1).toList();
  if (pts.length == 3) {
    final a = pts[1] - pts[0], b = pts[2] - pts[0];
    if (a.length < 10 ||
        b.length < 10 ||
        (pts[2] - pts[1]).length < 10 ||
        a.cross(b).abs() / (a.length * b.length) < .05) {
      return null;
    }
    return ShapeSuggestion(ShapePreset.triangle, List.of(stroke));
  }
  if (pts.length != 4 && pts.length != 6 && pts.length != 8) return null;
  var u = pts[1] - pts[0];
  if (u.length < 10) return null;
  final angle = math.atan2(u.y, u.x),
      axis = (angle / (math.pi / 2)).round() * math.pi / 2;
  if ((axis - angle).abs() < math.pi / 45) {
    u = DrawingPoint(math.cos(axis), math.sin(axis));
  } else {
    u = u * (1 / u.length);
  }
  final v = DrawingPoint(-u.y, u.x), origin = pts.first;
  final local = [
    for (final p in pts) DrawingPoint((p - origin).dot(u), (p - origin).dot(v))
  ];
  final edges = [
    for (var i = 0; i < pts.length; i++) local[(i + 1) % pts.length] - local[i]
  ];
  if (edges.any((d) =>
      d.length < 10 || math.min(d.x.abs(), d.y.abs()) / d.length > .10)) {
    return null;
  }
  final tolerance = edges.map((d) => d.length).reduce(math.min) * .08;
  List<double> levels(Iterable<double> input) {
    final sorted = input.toList()..sort();
    final groups = <List<double>>[];
    for (final value in sorted) {
      if (groups.isEmpty || value - groups.last.first > tolerance) {
        groups.add([value]);
      } else {
        groups.last.add(value);
      }
    }
    return [
      for (final group in groups) group.reduce((a, b) => a + b) / group.length
    ];
  }

  final xs = levels(local.map((p) => p.x)), ys = levels(local.map((p) => p.y));
  var kind = ShapePreset.rectangle;
  if (pts.length == 4) {
    if (xs.length != 2 || ys.length != 2) return null;
    final w = xs.last - xs.first, h = ys.last - ys.first;
    if ((w - h).abs() / math.max(w, h) < .08) {
      kind = ShapePreset.square;
      final side = (w + h) / 2;
      xs[1] = xs[0] + side;
      ys[1] = ys[0] + side;
    }
  } else if (pts.length == 6) {
    if (xs.length != 3 || ys.length != 3) return null;
    kind = ShapePreset.lShape;
  } else {
    if (!((xs.length == 4 && ys.length == 3) ||
        (xs.length == 3 && ys.length == 4))) {
      return null;
    }
    final winding = List.generate(
            pts.length, (i) => local[i].cross(local[(i + 1) % pts.length]))
        .fold(0.0, (a, b) => a + b);
    if (winding.abs() < .001) return null;
    final reflex = [
      for (var i = 0; i < edges.length; i++)
        if (edges[i].cross(edges[(i + 1) % edges.length]) * winding < 0) i
    ];
    if (reflex.length != 2) return null;
    final distance = (reflex[1] - reflex[0]).abs();
    final separation = math.min(distance, edges.length - distance);
    if (separation != 1 && separation != 3) return null;
    kind = separation == 1 ? ShapePreset.uShape : ShapePreset.tShape;
  }
  double closest(double x, List<double> levels) =>
      levels.reduce((a, b) => (a - x).abs() < (b - x).abs() ? a : b);
  final cleaned = [
    for (final p in local) origin + u * closest(p.x, xs) + v * closest(p.y, ys)
  ];
  // Reject collapsed edges or excessive corrections rather than guessing intent.
  if (List.generate(
      pts.length,
      (i) =>
          (cleaned[(i + 1) % pts.length] - cleaned[i]).length < 10 ||
          (cleaned[i] - pts[i]).length > tolerance * 2).any((v) => v)) {
    return null;
  }
  if (List.generate(pts.length, (i) => (cleaned[i] - pts[i]).length)
          .reduce(math.max) <
      .01) {
    return null;
  }
  final result = [...cleaned, cleaned.first];
  try {
    final check = WallNetwork()..addPolyline(result);
    if (check.walls.length != pts.length ||
        check.corners.length != pts.length) {
      return null;
    }
  } on DrawingConflict {
    return null;
  }
  return ShapeSuggestion(kind, result);
}
