import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/logic/pvc_ceiling_calculator.dart';

void main() {
  final reference = jsonDecode(
      File('test/features/pvc_ceiling/fixtures/multi_layout_reference.json')
          .readAsStringSync()) as List;
  for (var i = 0; i < PvcShape.values.length; i++) {
    final shape = PvcShape.values[i], expected = reference[i] as Map;
    test('${shape.label}: supplied reference and complete cut demand', () {
      final room = buildPvcRoom(shape, pvcDefaults(shape));
      final r = runPvcCalculation(PvcCalculation(room, 'mix'))!;
      expect(room.area, expected['area']);
      expect(r.area, room.area);
      expect(r.turned, expected['turned']);
      expect(r.rowsCount, expected['rows']);
      expect(r.total, expected['total']);
      expect(r.q10, expected['q10']);
      expect(r.q12, expected['q12']);
      expect(r.joints, expected['joints']);
      if (shape != PvcShape.angled && shape != PvcShape.cutCorner) {
        expect(r.sizes, expected['sizes']);
        expect(r.pieceTotal, expected['pieceTotal']);
      } else {
        // HTML sampled 0.01 ft inside row edges; exact envelopes need more cover.
        expect(r.pieceTotal, greaterThan(expected['pieceTotal'] as num));
      }
      final demand = <double, int>{};
      for (final row in r.layoutRows) {
        for (final segment in row.segments) {
          expect(segment.pieces.reduce((a, b) => a + b),
              closeTo(segment.x1 - segment.x0, .01));
          for (final piece in segment.pieces) {
            demand[piece] = (demand[piece] ?? 0) + 1;
          }
        }
        // Every interior cross-section must be covered, including concave arms.
        for (final fraction in [.000001, .25, .5, .75, .999999]) {
          for (final iv
              in scanPvcPolygon(r.polygon, row.y0 + row.width * fraction)) {
            expect(
                row.segments
                    .any((s) => s.x0 <= iv.$1 + 1e-6 && s.x1 >= iv.$2 - 1e-6),
                isTrue);
          }
        }
      }
      for (var j = 0; j < r.sizes.length; j++) {
        expect(
            r.plan.fold<int>(0, (n, p) => n + p.counts[j]), demand[r.sizes[j]]);
      }
      for (final plan in r.plan) {
        final count = plan.counts.fold(0, (a, b) => a + b);
        final used = [
          for (var j = 0; j < r.sizes.length; j++) r.sizes[j] * plan.counts[j]
        ].fold(0.0, (a, b) => a + b);
        expect(
            used + (count - 1) * kKerf, lessThanOrEqualTo(plan.stock + 1e-8));
      }
      expect(buildGroups(r).fold<int>(0, (n, g) => n + g.q), r.count);
    });
  }
  test('L mirrors preserve letter mapping and area', () {
    for (final corner in ['tr', 'tl', 'br', 'bl']) {
      final v = {'A': '20.58', 'B': '21.39', 'C': '9.88', 'D': '10.70'};
      final room = buildPvcRoom(PvcShape.l, v, corner: corner);
      for (final entry in room.edges.entries) {
        final a = room.points[entry.value.$1], b = room.points[entry.value.$2];
        final length = ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));
        final expected = double.parse(v[entry.key]!);
        expect(length, closeTo(expected * expected, 1e-8));
      }
      expect(room.area, closeTo(20.58 * 21.39 - 9.88 * 10.70, 1e-8));
    }
  });
  test('Centered and offset U/T openings; conflicting dimensions explained',
      () {
    for (final shape in [PvcShape.t, PvcShape.u]) {
      final v = pvcDefaults(shape);
      final centered = buildPvcRoom(shape, v);
      final offset = buildPvcRoom(shape, {...v, 'E': '2'});
      expect(offset.area, centered.area);
      expect(offset.points, isNot(centered.points));
      expect(() => buildPvcRoom(shape, {...v, 'E': '99'}),
          throwsA(isA<PvcInputError>().having((e) => e.field, 'field', 'E')));
    }
    expect(
        () => buildPvcRoom(PvcShape.l, {...pvcDefaults(PvcShape.l), 'C': '16'}),
        throwsA(isA<PvcInputError>().having((e) => e.field, 'field', 'C')));
    expect(
        () => buildPvcRoom(PvcShape.cutCorner,
            {...pvcDefaults(PvcShape.cutCorner), 'D': '11'}),
        throwsA(isA<PvcInputError>()));
  });
  test('Zero pointed side is allowed, zero base/empty area are not', () {
    final values = pvcDefaults(PvcShape.angled);
    expect(buildPvcRoom(PvcShape.angled, {...values, 'B': '0'}).area,
        greaterThan(0));
    expect(() => buildPvcRoom(PvcShape.angled, {...values, 'A': '0'}),
        throwsA(isA<PvcInputError>()));
    expect(() => buildPvcRoom(PvcShape.angled, {...values, 'B': '0', 'C': '0'}),
        throwsA(isA<PvcInputError>()));
  });
  test('Exact slope envelope and notch boundary have no unmeasured gap', () {
    final p = [pvcPoint(0, 0), pvcPoint(10, 10), pvcPoint(0, 10)];
    expect(pvcRowIntervals(p, 1, 2), [(0.0, 2.0)]);
    final u = buildPvcRoom(PvcShape.u, pvcDefaults(PvcShape.u));
    expect(pvcRowIntervals(u.points, 0, 7), [(0.0, 5.0), (11.0, 16.0)]);
    expect(pvcRowIntervals(u.points, 7, 8), [(0.0, 16.0)]);
  });
  test('Stock selections and long runs use the same model', () {
    final room = buildPvcRoom(PvcShape.rectangle, {'A': '50', 'B': '25'});
    for (final mode in ['10', '12', 'mix']) {
      final r = runPvcCalculation(PvcCalculation(room, mode))!;
      if (mode != 'mix') {
        expect(r.plan.every((p) => p.stock == double.parse(mode)), isTrue);
      }
      expect(r.pcs.length, greaterThan(2));
      expect(r.count, greaterThan(0));
    }
  });
}
