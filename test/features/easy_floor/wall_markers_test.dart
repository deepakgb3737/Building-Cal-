import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/floor_document.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/measurement_markers.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/wall_marker_painter.dart';
import 'drawing_screen_test.dart' as board;

class DotCanvas implements Canvas {
  final dots = <(Offset, double)>[];
  @override
  void drawCircle(Offset center, double radius, Paint paint) {
    dots.add((center, radius));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected painting: ${invocation.memberName}');
}

void main() {
  const p = DrawingPoint.new;
  test('Dots lie on the wall every 609.6 mm, larger every 1219.2 mm', () {
    for (final direction in [p(1, 0), p(0, 1), p(.6, .8)]) {
      final a = p(-100, 250), b = a + direction * 4000;
      final dots = wallIntervalMarkers(a, b).toList();
      expect(dots.length, 6);
      for (var i = 0; i < dots.length; i++) {
        expect(dots[i].distanceMm, closeTo((i + 1) * 609.6, 1e-8));
        expect((dots[i].point - a).length, closeTo(dots[i].distanceMm, 1e-8));
        expect((dots[i].point - a).cross(b - a), closeTo(0, 1e-6));
        expect(dots[i].level, i.isOdd ? 1 : 0);
      }
    }
    expect(wallIntervalMarkers(p(0, 0), p(609.6, 0)), isEmpty);
    expect(wallIntervalMarkers(p(0, 0), p(100, 0)), isEmpty);
    expect(() => wallIntervalMarkers(p(double.nan, 0), p(4000, 0)).toList(),
        throwsArgumentError);
  });

  test(
      'Painting stays on the wall at different zoom and pan; no text is painted',
      () {
    for (final scale in [.001, .05, .1, .2, 1.0]) {
      final canvas = DotCanvas();
      const origin = Offset(70, 30);
      paintWallMarkers(canvas, const Size(5000, 5000), p(0, 0), p(4000, 0),
          origin: origin, scale: scale);
      expect(canvas.dots.length, 6);
      for (var i = 0; i < canvas.dots.length; i++) {
        final dot = canvas.dots[i];
        expect(dot.$1.dx, closeTo(70 + (i + 1) * 609.6 * scale, 1e-8));
        expect(dot.$1.dy, 30);
        if (scale >= .05) {
          expect(dot.$2, i.isOdd ? 2.8 : 1.8);
        } else {
          expect(dot.$2, lessThan(609.6 * scale / 2));
        }
      }
    }
    final clipped = DotCanvas();
    paintWallMarkers(clipped, const Size(100, 100), p(0, 0), p(10000000, 0),
        origin: const Offset(-600, 50), scale: .1);
    expect(clipped.dots.length, lessThan(3));
    expect(clipped.dots, isNotEmpty);
  });

  test('Zoom-out keeps all exact markers separate and major dots prominent',
      () {
    for (final scale in [1e-7, .0001, .001, .005, .01, .02, .1, 2.0]) {
      for (final direction in [p(1, 0), p(0, 1), p(.6, .8)]) {
        final canvas = DotCanvas();
        paintWallMarkers(
            canvas, const Size(10000, 10000), p(0, 0), direction * 4000,
            origin: const Offset(20, 20), scale: scale);
        expect(canvas.dots.length, 6);
        for (var i = 1; i < canvas.dots.length; i++) {
          final previous = canvas.dots[i - 1], current = canvas.dots[i];
          final gap = (current.$1 - previous.$1).distance;
          expect(gap, closeTo(609.6 * scale, 1e-8));
          expect(current.$2 + previous.$2, lessThan(gap));
          expect(canvas.dots[1].$2, greaterThan(canvas.dots[0].$2));
        }
      }
    }
  });

  test('Old marker-off settings load without disabling the always-on dots', () {
    final data = const DocumentSettings().toJson();
    data['markers'] = 0;
    expect(DocumentSettings.fromJson(data).toJson(),
        const DocumentSettings().toJson());
    data.remove('markers');
    expect(DocumentSettings.fromJson(data).toJson(), data);
  });

  testWidgets('Dots are automatic and there is no marker-off menu option',
      (t) async {
    await board.open(t);
    await board.outline(t);
    final before = board.painter(t).model.toJson();
    await t.tap(find.byTooltip('Drawing assistance'));
    await t.pumpAndSettle();
    expect(find.textContaining('Measurement markers'), findsNothing);
    await t.tapAt(const Offset(1, 1));
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), before);
    await t.ensureVisible(find.byTooltip('Undo'));
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(board.painter(t).model.walls, isEmpty);
    expect(t.takeException(), isNull);
  });
}
