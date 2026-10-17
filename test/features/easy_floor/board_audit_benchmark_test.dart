import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/drawing_painter.dart';

void main() {
  test(
      'Audit timing samples for preview, finalization and painting (debug, not a frame-rate guarantee)',
      () {
    for (final divisions in [5, 10, 20]) {
      final m = WallNetwork();
      for (var x = 0; x <= divisions; x++) {
        m.addPolyline(
            [DrawingPoint(x * 200, 0), DrawingPoint(x * 200, divisions * 200)]);
      }
      for (var y = 0; y <= divisions; y++) {
        m.addPolyline(
            [DrawingPoint(0, y * 200), DrawingPoint(divisions * 200, y * 200)]);
      }
      final id =
          m.nearestCorner(DrawingPoint(divisions * 100, divisions * 100), 150)!;
      final old = m.corners[id]!;
      final selectionWatch = Stopwatch()..start();
      final room = m.enclosedComponentAt(const DrawingPoint(100, 100));
      final selectionMicros = selectionWatch.elapsedMicroseconds;
      final groupTimes = <int>[];
      for (var repeat = 0; repeat < 5; repeat++) {
        final next = m.copy(), watch = Stopwatch()..start();
        next.moveRoom(room, const DrawingPoint(20, 30));
        groupTimes.add(watch.elapsedMicroseconds);
        expect(next.walls.keys.toSet(), m.walls.keys.toSet());
        for (final entry in m.corners.entries) {
          expect(next.corners[entry.key]!.x, closeTo(entry.value.x + 20, 1e-8));
          expect(next.corners[entry.key]!.y, closeTo(entry.value.y + 30, 1e-8));
        }
      }
      final samples = <int>[],
          finishes = <int>[],
          paints = <int>[],
          snaps = <int>[];
      for (var repeat = 0; repeat < 5; repeat++) {
        final next = m.copy(), watch = Stopwatch()..start();
        final snapped =
            next.snap(old + const DrawingPoint(4, 3), 60, excludeCorner: id);
        snaps.add(watch.elapsedMicroseconds);
        expect(snapped.isFinite, isTrue);
        watch.reset();
        next.moveCorners({id: old + const DrawingPoint(10, 10)});
        samples.add(watch.elapsedMicroseconds);
        watch.reset();
        next.moveCorners({}, join: true);
        finishes.add(watch.elapsedMicroseconds);
        watch.reset();
        final recorder = ui.PictureRecorder();
        DrawingPainter(
                model: next,
                origin: const Offset(40, 40),
                scale: .1,
                unit: DrawingUnit.mm,
                preview: [],
                selectedCorner: id,
                editingCorner: true)
            .paint(Canvas(recorder), const Size(400, 800));
        recorder.endRecording().dispose();
        paints.add(watch.elapsedMicroseconds);
      }
      int median(List<int> values) {
        values.sort();
        return values[values.length ~/ 2];
      }

      debugPrint(
          'AUDIT walls=${m.walls.length} corners=${m.corners.length} snap_us=${median(snaps)} preview_us=${median(samples)} finalize_us=${median(finishes)} paint_us=${median(paints)} room_select_us=$selectionMicros room_move_us=${median(groupTimes)}');
      expect(m.walls.length, 2 * divisions * (divisions + 1));
    }
  });
}
