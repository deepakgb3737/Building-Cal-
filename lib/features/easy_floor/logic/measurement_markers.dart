import 'dart:math' as math;
import 'drawing_point.dart';

class WallIntervalMarker {
  const WallIntervalMarker(this.point, this.distanceMm, this.level);
  final DrawingPoint point;
  final double distanceMm;
  final int level;
}

/// Offsets are measured from A; markers never become corners or snap targets.
Iterable<WallIntervalMarker> wallIntervalMarkers(DrawingPoint a, DrawingPoint b,
    {double fromMm = 0, double? toMm}) sync* {
  final step = DrawingUnit.feet.toMm(2), delta = b - a, length = delta.length;
  if (!a.isFinite ||
      !b.isFinite ||
      !fromMm.isFinite ||
      (toMm != null && !toMm.isFinite)) {
    throw ArgumentError('Invalid wall bounds.');
  }
  if (length < 10) return;
  final first = math.max(1, (fromMm / step).ceil());
  final last = (math.min(toMm ?? length, length - .001) / step).floor();
  for (var i = first; i <= last; i++) {
    final offset = i * step;
    yield WallIntervalMarker(
        a + delta * (offset / length), offset, i.isEven ? 1 : 0);
  }
}
