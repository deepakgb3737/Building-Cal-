import 'dart:ui' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'drawing_screen_test.dart' as board;
import 'endpoint_connection_test.dart' show wall;
import 'accessible_lock_test.dart' show press;
import 'floating_palette_test.dart' show handle, palette;
import 'natural_drawing_test.dart' show stroke;

void main() {
  testWidgets('A locked endpoint cannot rotate its wall at constant length',
      (t) async {
    await board.open(t, showLabels: false);
    await board.collapseTools(t);
    await wall(t, const Offset(80, 100), const Offset(180, 100));
    final offset = t.getTopLeft(board.canvas);
    await t.tapAt(offset + const Offset(130, 100));
    await t.pumpAndSettle();
    await press(t, 'Lock length');
    final locked = board.painter(t).model.toJson();
    final drag = await t.startGesture(offset + const Offset(180, 100));
    await drag.moveTo(offset + const Offset(80, 200));
    await t.pump();
    expect(board.painter(t).model.toJson(), locked);
    await drag.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), locked);
    expect(t.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 740),
    const Size(740, 360),
    const Size(240, 420)
  ]) {
    for (final move in [Offset.zero, const Offset(0, -600)]) {
      testWidgets(
          'Fit uses unobstructed canvas on $size with toolbar moved by $move',
          (t) async {
        await board.open(t, showLabels: false);
        await board.collapseTools(t);
        await stroke(t, const [
          Offset(80, 60),
          Offset(200, 60),
          Offset(200, 460),
          Offset(80, 460),
          Offset(80, 60)
        ]);
        await board.expandTools(t);
        t.view.physicalSize = size;
        await t.pumpAndSettle();
        final geometry = board.painter(t).model.toJson();
        if (move != Offset.zero) {
          await t.drag(handle, move);
          await t.pumpAndSettle();
        }
        await t.tap(find.byTooltip('Fit to Screen'));
        await t.pumpAndSettle();
        final offset = t.getTopLeft(board.canvas);
        final tools = t.getRect(palette).shift(-offset).inflate(12);
        final view = board.painter(t);
        final canvasRect = Offset.zero & t.getSize(board.canvas);
        final points = view.model.corners.values.map(view.screen).toList();
        for (final p in points) {
          expect(canvasRect.deflate(12).contains(p), isTrue);
          expect(tools.contains(p), isFalse);
        }
        // A segment can pass through the palette even with both ends outside it.
        for (final w in view.model.walls.values) {
          final a = view.screen(view.model.corners[w.start]!);
          final b = view.screen(view.model.corners[w.end]!);
          for (var i = 0; i <= 20; i++) {
            expect(tools.contains(a + (b - a) * (i / 20)), isFalse);
          }
        }
        expect(view.model.toJson(), geometry);
        expect(t.takeException(), isNull);
      });
    }
  }
}
