import 'dart:math' as math;
import 'dart:typed_data';
import 'pvc_ceiling_models.dart';
export 'pvc_ceiling_models.dart';
import 'pvc_room.dart';
export 'pvc_room.dart';
part 'pvc_packing.dart';
part 'pvc_polygon_optimizer.dart';

double r3(double x) => (x * 1000).round() / 1000;

double parsePvcDimension(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  if (value == null || !value.isFinite || value <= 0 || value > 100) {
    throw ArgumentError('Enter room dimensions above 0 and up to 100 ft.');
  }
  return value;
}

/// How many rows of planks fit across [w] feet, and the width of the two
/// cut edge rows (0 when the rows fit exactly).
RowInfo rowsFor(double w) {
  final k0 = (w / kPW).round();
  if ((w - k0 * kPW).abs() < 1e-6) return RowInfo(k0, 0, true);
  RowInfo? best;
  final top = (w / kPW).floor();
  for (var k = math.max(0, top - 2); k <= top; k++) {
    final e = (w - k * kPW) / 2;
    if (e >= .5 - kEps && e <= kPW + kEps) {
      final sc = (e - .75 * kPW).abs();
      if (best == null || sc < best.score) {
        best = RowInfo(k + 2, e, true, sc);
      }
    }
  }
  return best ?? const RowInfo(0, 0, false);
}

class _Pattern {
  final double stock;
  final List<int> counts;
  _Pattern(this.stock, this.counts);
}

/// Exact 1-D cutting stock (dynamic programming over the remaining demand):
/// fewest total stock length, offcuts reused. Returns null if impossible.
List<PlanItem>? solveStock(
    List<double> sizes, List<int> demand, List<double> stocks) {
  final k = sizes.length;
  final minS = sizes.reduce(math.min) + kKerf;
  final pats = <_Pattern>[];

  for (final s in stocks) {
    final c = List<int>.filled(k, 0);
    void rec(int i, double rem) {
      if (i == k) {
        if (c.any((x) => x > 0) && rem < minS - kEps) {
          pats.add(_Pattern(s, List<int>.from(c)));
        }
        return;
      }
      for (var n = 0; n * (sizes[i] + kKerf) <= rem + kEps; n++) {
        c[i] = n;
        rec(i + 1, rem - n * (sizes[i] + kKerf));
      }
      c[i] = 0;
    }

    rec(0, s + kKerf);
  }

  final stride = List<int>.filled(k, 0);
  final dims = demand.map((d) => d + 1).toList();
  var tot = 1;
  for (var i = 0; i < k; i++) {
    stride[i] = tot;
    tot *= dims[i];
  }

  final f = Float64List(tot);
  final ch = Int32List(tot)..fillRange(0, tot, -1);
  final d = List<int>.filled(k, 0);

  for (var idx = 1; idx < tot; idx++) {
    for (var i = 0; i < k; i++) {
      d[i]++;
      if (d[i] < dims[i]) break;
      d[i] = 0;
    }
    var bestV = double.infinity;
    var bp = -1;
    for (var p = 0; p < pats.length; p++) {
      final pat = pats[p];
      var progress = false;
      var ni = 0;
      for (var i = 0; i < k; i++) {
        final ci = math.min(pat.counts[i], d[i]);
        if (pat.counts[i] > 0 && d[i] > 0) progress = true;
        ni += (d[i] - ci) * stride[i];
      }
      if (!progress) continue;
      final v = pat.stock + 1e-4 + f[ni];
      if (v < bestV - 1e-9) {
        bestV = v;
        bp = p;
      }
    }
    f[idx] = bestV;
    ch[idx] = bp;
  }

  final rem = List<int>.from(demand);
  final plan = <PlanItem>[];
  var idx = tot - 1;
  while (idx > 0) {
    if (ch[idx] < 0) return null;
    final pat = pats[ch[idx]];
    final a = List<int>.generate(k, (i) => math.min(pat.counts[i], rem[i]));
    plan.add(PlanItem(pat.stock, a));
    idx = 0;
    for (var i = 0; i < k; i++) {
      rem[i] -= a[i];
      idx += rem[i] * stride[i];
    }
  }
  return plan;
}

/// Compatibility entry for rectangular rooms; all shapes share polygon packing.
Layout? bestLayout(double length, double width, List<double> stocks,
    [double mn = kMinPiece]) {
  parsePvcDimension('$length');
  parsePvcDimension('$width');
  return bestPolygon([
    pvcPoint(0, 0),
    pvcPoint(length, 0),
    pvcPoint(length, width),
    pvcPoint(0, width)
  ], stocks, mn);
}

List<double> pvcStocks(String mode) => switch (mode) {
      'mix' => [10, 12],
      '10' => [10],
      '12' => [12],
      _ => throw ArgumentError('Choose a valid plank option.')
    };

Layout? runBest(List<Object> args) => bestLayout(
    args[0] as double, args[1] as double, pvcStocks(args[2] as String));

class PvcCalculation {
  const PvcCalculation(this.room, this.mode);
  final PvcRoom room;
  final String mode;
}

Layout? runPvcCalculation(PvcCalculation request) =>
    bestPolygon(request.room.points, pvcStocks(request.mode), kMinPiece);

List<CutGroup> buildGroups(Layout c) {
  final map = <String, CutGroup>{};
  for (final p in c.plan) {
    final cuts = <double>[];
    for (var i = 0; i < p.counts.length; i++) {
      for (var j = 0; j < p.counts[i]; j++) {
        cuts.add(c.sizes[i]);
      }
    }
    cuts.sort((a, b) => b.compareTo(a));
    final key = '${p.stock}|${cuts.join(',')}';
    final g = map[key];
    if (g == null) {
      map[key] = CutGroup(p.stock, cuts, 1);
    } else {
      g.q++;
    }
  }
  final list = map.values.toList()
    ..sort((a, b) {
      final s = b.stock.compareTo(a.stock);
      return s != 0 ? s : b.q.compareTo(a.q);
    });
  return list;
}
