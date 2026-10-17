import 'dart:math' as math;
import 'package:grid_ceiling_calculator/features/unit_converter/logic/unit_conversion_service.dart';

class DrawingPoint {
  const DrawingPoint(this.x, this.y);
  final double x;
  final double y;
  DrawingPoint operator +(DrawingPoint p) => DrawingPoint(x + p.x, y + p.y);
  DrawingPoint operator -(DrawingPoint p) => DrawingPoint(x - p.x, y - p.y);
  DrawingPoint operator *(double factor) =>
      DrawingPoint(x * factor, y * factor);
  double get length => math.sqrt(x * x + y * y);
  double dot(DrawingPoint p) => x * p.x + y * p.y;
  double cross(DrawingPoint p) => x * p.y - y * p.x;
  bool get isFinite => x.isFinite && y.isFinite;
}

enum DrawingUnit {
  mm('mm', UnitConversionService.millimetre),
  centimetres('cm', UnitConversionService.centimetre),
  metres('m', UnitConversionService.metre),
  feet('ft', UnitConversionService.foot),
  inches('in', UnitConversionService.inch),
  feetInches('ft/in', 'Feet and inches');

  const DrawingUnit(this.symbol, this.name);
  final String symbol;
  final String name;
  double toMm(double value) => UnitConversionService.convert(
      value: value,
      fromUnit: this == feetInches ? UnitConversionService.foot : name,
      toUnit: UnitConversionService.millimetre);
  double fromMm(double value) => UnitConversionService.convert(
      value: value,
      fromUnit: UnitConversionService.millimetre,
      toUnit: this == feetInches ? UnitConversionService.foot : name);
  double? readMm(String text) {
    if (this != feetInches) {
      final value = double.tryParse(text.trim());
      return value == null ? null : toMm(value);
    }
    final match =
        RegExp(r'''^\s*(\d+)\s*(?:ft|')?\s+(\d+(?:\.\d+)?)\s*(?:in|")?\s*$''')
            .firstMatch(text);
    if (match == null) return null;
    final feet = double.parse(match[1]!), inches = double.parse(match[2]!);
    if (inches >= 12) return null;
    return feet * 304.8 + inches * 25.4;
  }

  String input(double mmValue, {int? decimalPlaces}) {
    if (this != feetInches) {
      return decimalPlaces == null
          ? fromMm(mmValue).toString()
          : _display(fromMm(mmValue), decimalPlaces);
    }
    if (decimalPlaces != null) {
      final factor = math.pow(10, decimalPlaces).toInt();
      final inches = (mmValue / 25.4 * factor).round();
      return '${inches ~/ (12 * factor)} ${_display(inches % (12 * factor) / factor, decimalPlaces)}';
    }
    final total = double.parse((mmValue / 25.4).toStringAsFixed(9));
    final feet = (total / 12).floor();
    return '$feet ${(total - feet * 12).toStringAsFixed(9)}';
  }

  String format(double mmValue) {
    if (this != feetInches) {
      return '${_display(fromMm(mmValue), this == mm ? 1 : 2)} $symbol';
    }
    final tenths = (mmValue / 25.4 * 10).round();
    return '${tenths ~/ 120} ft ${_display(tenths % 120 / 10, 1)} in';
  }

  String _display(double value, int precision) =>
      value.toStringAsFixed(precision).replaceFirst(RegExp(r'\.?0+$'), '');
}

DrawingPoint projectToSegment(DrawingPoint p, DrawingPoint a, DrawingPoint b) {
  final d = b - a;
  final square = d.dot(d);
  final t = square == 0 ? 0.0 : ((p - a).dot(d) / square).clamp(0.0, 1.0);
  return a + d * t;
}

List<DrawingPoint> straightenStroke(
    List<DrawingPoint> input, double tolerance) {
  if (input.length < 2) return List.of(input);
  // Iterative simplification avoids recursion limits on long stylus strokes.
  final keep = <int>{0, input.length - 1};
  final pending = <(int, int)>[(0, input.length - 1)];
  while (pending.isNotEmpty) {
    final (start, end) = pending.removeLast();
    var distance = tolerance;
    var chosen = -1;
    for (var i = start + 1; i < end; i++) {
      final offset =
          (input[i] - projectToSegment(input[i], input[start], input[end]))
              .length;
      if (offset > distance) {
        distance = offset;
        chosen = i;
      }
    }
    if (chosen >= 0) {
      keep.add(chosen);
      pending.add((start, chosen));
      pending.add((chosen, end));
    }
  }
  final indices = keep.toList()..sort();
  return indices.map((i) => input[i]).toList();
}

/// Optional assistance only; free-angle strokes remain the default.
DrawingPoint alignEndpoint(DrawingPoint start, DrawingPoint end) {
  final delta = end - start;
  final angle = math.atan2(delta.y, delta.x);
  final nearest = (angle / (math.pi / 4)).round() * math.pi / 4;
  if ((angle - nearest).abs() > math.pi / 60) return end;
  return start +
      DrawingPoint(math.cos(nearest), math.sin(nearest)) * delta.length;
}
