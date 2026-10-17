import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/logic/pvc_ceiling_calculator.dart';

void main() {
  test('Cutting guide consumes engine tape readings including blade width', () {
    final group = CutGroup(12, [4, 3, 2], 1);
    expect(group.spans[0], (start: 0.0, end: 4.0));
    expect(group.spans[1].start, closeTo(4 + kKerf, 1e-10));
    expect(group.spans[2].end, closeTo(9 + 2 * kKerf, 1e-10));
    expect(group.scrap, closeTo(3 - 3 * kKerf, 1e-10));
  });
  // Frozen outputs from the supplied standalone implementation before extraction.
  for (final c in [
    (14.5, 11.0, 'mix', 'width', 15, [11.0], 0, 15, 180.0, 15.0),
    (10.0, 10.0, '10', 'length', 11, [10.0], 11, 0, 110.0, 0.0),
    (12.0, 8.0, '12', 'length', 9, [12.0], 0, 9, 108.0, 0.0),
    (20.0, 15.0, 'mix', 'length', 16, [10.0, 10.0], 32, 0, 320.0, 0.0),
  ]) {
    test('Supplied result ${c.$1} x ${c.$2}, ${c.$3}', () {
      final r = runBest([c.$1, c.$2, c.$3])!;
      expect(r.dir, c.$4);
      expect(r.rowsCount, c.$5);
      expect(r.pcs, c.$6);
      expect(r.q10, c.$7);
      expect(r.q12, c.$8);
      expect(r.total, c.$9);
      expect(r.waste, c.$10);
      expect(r.rowWidths.length, r.rowsCount);
      expect(r.rowWidths.reduce((a, b) => a + b), closeTo(r.across, 1e-8));
      final delivered = List<int>.filled(r.sizes.length, 0);
      for (final p in r.plan) {
        var used = 0.0, count = 0;
        for (var i = 0; i < p.counts.length; i++) {
          delivered[i] += p.counts[i];
          used += r.sizes[i] * p.counts[i];
          count += p.counts[i];
        }
        expect(used + (count - 1) * kKerf, lessThanOrEqualTo(p.stock + 1e-8));
      }
      for (var i = 0; i < r.sizes.length; i++) {
        expect(delivered[i],
            r.pcs.where((p) => p == r.sizes[i]).length * r.rowsCount);
      }
      final groups = buildGroups(r);
      expect(groups.fold<int>(0, (n, g) => n + g.q), r.count);
      for (final stock in [10.0, 12.0]) {
        expect(
            r.wholeCount(stock),
            groups
                .where((g) => g.stock == stock && g.whole)
                .fold<int>(0, (n, g) => n + g.q));
      }
    });
  }
  test('Engine rejects invalid dimensions and stock', () {
    for (final value in ['', 'abc', 'NaN', 'Infinity', '-1', '0', '100.01']) {
      expect(() => parsePvcDimension(value), throwsArgumentError);
    }
    expect(parsePvcDimension(' 14,5 '), 14.5);
    expect(() => bestLayout(double.nan, 10, [10]), throwsArgumentError);
    expect(() => bestLayout(10, 10, []), throwsArgumentError);
    expect(() => runBest([10.0, 10.0, 'unknown']), throwsArgumentError);
  });
  test('Multi-piece runs are supported; exact rows remain exact', () {
    final large = bestLayout(100, 100, [10, 12])!;
    expect(large.pcs.length, greaterThan(2));
    expect(large.pcs.reduce((a, b) => a + b), closeTo(large.run, .01));
    expect(rowsFor(kPW * 4).n, 4);
    expect(rowsFor(kPW * 4).edge, 0);
    expect(rowsFor(.1).ok, isFalse);
  });
}
