import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../integration_test/easy_floor_complex_layouts_test.dart'
    show rough;
import 'drawing_screen_test.dart' as board;
import 'natural_drawing_test.dart' show stroke;
import 'sketch_refinement_interaction_test.dart' show choose;

void main() {
  const shapes = {
    'U': [
      Offset(.16, .12),
      Offset(.35, .12),
      Offset(.35, .35),
      Offset(.65, .35),
      Offset(.65, .12),
      Offset(.84, .12),
      Offset(.84, .53),
      Offset(.16, .53),
      Offset(.16, .12)
    ],
    'angled': [
      Offset(.16, .14),
      Offset(.64, .14),
      Offset(.84, .27),
      Offset(.72, .48),
      Offset(.46, .55),
      Offset(.16, .42),
      Offset(.16, .14)
    ],
  };
  for (final entry in shapes.entries) {
    testWidgets('Refine sampled ${entry.key} without extra wall fragments',
        (t) async {
      await board.open(t);
      t.view.physicalSize = const Size(393, 851);
      await t.pumpAndSettle();
      await board.collapseTools(t);
      final size = t.getSize(board.canvas);
      await stroke(
          t,
          rough(entry.value
              .map((p) => Offset(p.dx * size.width, p.dy * size.height))
              .toList()),
          finish: false);
      await choose(t, 'Yes, Straighten');
      await choose(t, 'Accept refinement');
      expect(board.painter(t).model.walls.length, entry.value.length - 1);
    });
  }
}
