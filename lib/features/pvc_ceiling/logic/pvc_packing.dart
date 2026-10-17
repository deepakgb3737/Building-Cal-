part of 'pvc_ceiling_calculator.dart';

List<List<double>> splitsFor(double run, double mn, List<double> stocks) {
  final mx = stocks.reduce(math.max), set = <String, List<double>>{};
  void add(List<double> raw) {
    if (raw.any((x) => x < mn - kEps || x > mx + kEps)) return;
    final a = raw.map(r3).toList()..sort((a, b) => b.compareTo(a));
    set[a.join(',')] = a;
  }

  if (run <= mx + kEps) add([run]);
  if (run > 2 * mx + kEps) {
    final m = (run / mx - kEps).ceil();
    add(List.filled(m, run / m));
    for (final stock in stocks) {
      final a = <double>[];
      var r = run;
      while (r > mx + kEps) {
        a.add(stock);
        r -= stock;
      }
      if (r >= mn - kEps) {
        a.add(r);
      } else if (a.isNotEmpty) {
        final t = a.removeLast();
        a.addAll([(t + r) / 2, (t + r) / 2]);
      }
      add(a);
    }
  } else {
    final cuts = <double>{run / 2, ...stocks, ...stocks.map((s) => run - s)};
    for (var a = mn; a <= run / 2 + kEps; a += .25) {
      cuts.add(a);
    }
    for (final a in cuts) {
      if (a > 0 && a < run) add([a, run - a]);
    }
  }
  return set.values.toList();
}

List<PlanItem>? _bestFit(
    List<double> pieces, List<double> sizes, List<double> stocks, bool small) {
  final pl = <({double stock, double rem, List<double> cuts})>[];
  final sorted = [...stocks]..sort();
  for (final piece in pieces) {
    var bi = -1, br = double.infinity;
    for (var i = 0; i < pl.length; i++) {
      final r = pl[i].rem - (piece + kKerf);
      if (r >= -kEps && r < br) {
        br = r;
        bi = i;
      }
    }
    if (bi >= 0) {
      final q = pl[bi];
      q.cuts.add(piece);
      pl[bi] = (stock: q.stock, rem: br, cuts: q.cuts);
    } else {
      final fit = sorted.where((s) => s - piece >= -kEps).toList();
      if (fit.isEmpty) return null;
      final s = small ? fit.first : fit.last;
      pl.add((stock: s, rem: s - piece, cuts: [piece]));
    }
  }
  return pl.map((p) {
    var stock = p.stock;
    final used = p.cuts.fold(0.0, (s, x) => s + x + kKerf);
    for (final s in sorted) {
      if (s >= stock) break;
      if (s + kKerf - used >= -kEps) {
        stock = s;
        break;
      }
    }
    return PlanItem(stock,
        [for (final size in sizes) p.cuts.where((x) => x == size).length]);
  }).toList();
}

List<PlanItem>? _packing(
    List<double> sizes, List<int> demand, List<double> stocks) {
  var space = 1;
  for (final x in demand) {
    space *= x + 1;
    if (space > 150000) break;
  }
  if (sizes.length <= 5 && space <= 150000) {
    final exact = solveStock(sizes, demand, stocks);
    if (exact != null) return exact;
  }
  final pieces = [
    for (var i = 0; i < sizes.length; i++) ...List.filled(demand[i], sizes[i])
  ]..sort((a, b) => b.compareTo(a));
  List<PlanItem>? best;
  var total = double.infinity;
  for (final small in [true, false]) {
    final plan = _bestFit(pieces, sizes, stocks, small);
    if (plan == null) continue;
    final t = plan.fold(0.0, (s, p) => s + p.stock);
    if (t < total || (t == total && plan.length < best!.length)) {
      best = plan;
      total = t;
    }
  }
  return best;
}

List<List<double>> _trim(List<List<double>> list, int cap) {
  if (list.length <= cap) return list;
  final key = [
    for (var i = 0; i < list.length; i++)
      if (i == 0 ||
          list[i].length == 1 ||
          list[i].any((x) => (x - 10).abs() < .01 || (x - 12).abs() < .01) ||
          (list[i].first - list[i].last).abs() < .01)
        list[i]
  ];
  final out = key.take(cap).toSet();
  for (var i = 0; out.length < cap && i < cap * 3; i++) {
    out.add(list[(i * list.length / (cap * 3)).floor()]);
  }
  return out.take(cap).toList();
}

List<List<List<double>>> _product(List<List<List<double>>> lists, int cap) {
  var acc = <List<List<double>>>[[]];
  for (final list in lists) {
    final next = <List<List<double>>>[];
    for (final a in acc) {
      for (final x in list) {
        next.add([...a, x]);
        if (next.length >= cap * 4) break;
      }
    }
    acc = next;
  }
  return acc.take(cap).toList();
}

List<double> _minSplit(
    double length, List<double> stocks, double mn, double? stock) {
  final mx = stocks.reduce(math.max);
  if (length <= mx + kEps) return [length];
  if (stock == null) {
    final m = (length / mx - kEps).ceil();
    return List.filled(m, length / m);
  }
  final a = <double>[];
  var r = length;
  while (r > mx + kEps) {
    a.add(stock);
    r -= stock;
  }
  if (r >= mn - kEps) {
    a.add(r);
  } else {
    final t = a.removeLast();
    a.addAll([(t + r) / 2, (t + r) / 2]);
  }
  return a.map(r3).toList();
}
