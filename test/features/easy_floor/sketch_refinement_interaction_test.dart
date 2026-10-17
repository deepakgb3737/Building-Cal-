import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'drawing_screen_test.dart' as drawing;
import 'natural_drawing_test.dart' as natural;

const roughSquare = [
  Offset(60, 60),
  Offset(260, 62),
  Offset(258, 258),
  Offset(58, 260),
  Offset(60, 60)
];

Future<void> choose(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text));
  await t.tap(find.text(text));
  await t.pumpAndSettle();
}

void main() {
  for (final size in [
    const Size(240, 420),
    const Size(320, 740),
    const Size(740, 360)
  ]) {
    testWidgets('Dense straight input commits without a review prompt on $size',
        (t) async {
      await drawing.open(t);
      t.view.physicalSize = size;
      await t.pumpAndSettle();
      await drawing.collapseTools(t);
      await natural.stroke(
          t,
          [
            for (var i = 0; i <= 50; i++)
              Offset(40 + i * (size.width - 80) / 50, 80)
          ],
          finish: false);
      final model = drawing.painter(t).model;
      expect(model.walls.length, 1);
      expect(model.corners.length, 2);
      expect(find.text('Straighten and refine this sketch?'), findsNothing);
      expect(model.length(model.walls.keys.single),
          closeTo((size.width - 80) * 10, .001));
      await drawing.expandTools(t);
      await t.ensureVisible(find.byTooltip('Undo'));
      await t.tap(find.byTooltip('Undo'));
      await t.pumpAndSettle();
      expect(drawing.painter(t).model.walls, isEmpty);
      await t.ensureVisible(find.byTooltip('Redo'));
      await t.tap(find.byTooltip('Redo'));
      await t.pumpAndSettle();
      expect(drawing.painter(t).model.toJson(), model.toJson());
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Ask only after completion; preview requires explicit acceptance',
      (t) async {
    await drawing.open(t);
    final origin = t.getTopLeft(drawing.canvas);
    final drag = await t.startGesture(origin + roughSquare.first);
    for (final point in roughSquare.skip(1)) {
      await drag.moveTo(origin + point);
      await t.pump();
      expect(find.text('Straighten and refine this sketch?'), findsNothing);
    }
    await drag.up();
    await t.pumpAndSettle();
    expect(find.text('Straighten and refine this sketch?'), findsOneWidget);
    expect(drawing.painter(t).model.walls, isEmpty);
    final original = drawing.painter(t).preview;
    await choose(t, 'Yes, Straighten');
    expect(drawing.painter(t).model.walls, isEmpty);
    expect(drawing.painter(t).preview[1].x, isNot(original[1].x));
    await choose(t, 'Accept refinement');
    expect(drawing.painter(t).model.walls.length, 4);
    await t.ensureVisible(find.byTooltip('Undo'));
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(drawing.painter(t).model.walls, isEmpty);
    expect(find.text('Straighten and refine this sketch?'), findsOneWidget);
    expect(drawing.painter(t).preview, original);
    await t.tap(find.byTooltip('Redo'));
    await t.pumpAndSettle();
    expect(drawing.painter(t).model.walls.length, 4);
  });
  testWidgets('Cancel refinement retains the original, not the clean proposal',
      (t) async {
    await drawing.open(t);
    await natural.stroke(t, roughSquare, finish: false);
    final original = List.of(drawing.painter(t).preview);
    await choose(t, 'Yes, Straighten');
    await choose(t, 'Cancel refinement');
    final model = drawing.painter(t).model;
    for (final p in original) {
      expect(model.nearestCorner(p, .001), isNotNull);
    }
    expect(model.walls.length, 4);
  });
  testWidgets('Discarding a sketch preserves existing walls and undo history',
      (t) async {
    await drawing.open(t);
    await natural.stroke(t, const [Offset(60, 60), Offset(260, 60)]);
    final original = drawing.painter(t).model.toJson();
    await natural.stroke(
        t, const [Offset(70, 150), Offset(240, 170), Offset(190, 300)],
        finish: false);
    await choose(t, 'Yes, Straighten');
    await choose(t, 'Discard sketch');
    expect(drawing.painter(t).model.toJson(), original);
    await t.ensureVisible(find.byTooltip('Undo'));
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(drawing.painter(t).model.walls, isEmpty);
  });
  testWidgets('Single walls do not repeatedly interrupt drawing', (t) async {
    await drawing.open(t);
    await natural.stroke(t, const [Offset(60, 60), Offset(260, 120)],
        finish: false);
    expect(drawing.painter(t).model.walls.length, 1);
    expect(find.text('Straighten and refine this sketch?'), findsNothing);
  });
  testWidgets('A shaky line commits only two vertices and remains editable',
      (t) async {
    await drawing.open(t);
    await natural.stroke(
        t,
        [
          for (var i = 0; i <= 40; i++)
            Offset(60 + i * 5, 120 + (i.isEven ? 1 : -1))
        ],
        finish: false);
    await choose(t, 'Yes, Straighten');
    await choose(t, 'Accept refinement');
    final view = drawing.painter(t), model = view.model;
    expect(model.corners.length, 2);
    expect(model.walls.length, 1);
    final wall = model.walls.values.single;
    await t.tapAt(t.getTopLeft(drawing.canvas) +
        (view.screen(model.corners[wall.start]!) +
                view.screen(model.corners[wall.end]!)) /
            2);
    await t.pumpAndSettle();
    await choose(t, 'Enter length');
    await t.enterText(find.byType(TextFormField), '2.5');
    await choose(t, 'Apply');
    expect(drawing.painter(t).model.length(wall.id), closeTo(2500, .001));
  });
  testWidgets('Nearly stationary input produces no wall or refinement prompt',
      (t) async {
    await drawing.open(t);
    final origin = t.getTopLeft(drawing.canvas);
    final drag = await t.startGesture(origin + const Offset(120, 120));
    await drag.moveBy(const Offset(1, 1));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    expect(drawing.painter(t).model.walls, isEmpty);
    expect(find.text('Straighten and refine this sketch?'), findsNothing);
  });
  testWidgets('A restored sketch can be discarded without phantom dirty work',
      (t) async {
    await drawing.open(t);
    await natural.stroke(t, roughSquare, finish: false);
    await choose(t, 'Yes, Straighten');
    await choose(t, 'Accept refinement');
    await t.ensureVisible(find.byTooltip('Undo'));
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    await choose(t, 'Discard sketch');
    expect(drawing.painter(t).model.walls, isEmpty);
    expect(drawing.painter(t).preview, isEmpty);
    expect(find.text('Untitled'), findsOneWidget);
    await t.ensureVisible(find.byTooltip('Redo'));
    await t.tap(find.byTooltip('Redo'));
    await t.pumpAndSettle();
    expect(find.text('Straighten and refine this sketch?'), findsOneWidget);
  });
  testWidgets('Refining an attached outline preserves its shared anchor',
      (t) async {
    await drawing.open(t);
    await natural.stroke(t, const [Offset(60, 60), Offset(260, 60)]);
    final before = drawing.painter(t).model.toJson();
    await natural.stroke(
        t,
        const [
          Offset(160, 60),
          Offset(161, 160),
          Offset(260, 160),
          Offset(260, 280)
        ],
        hold: true,
        finish: false);
    await choose(t, 'Yes, Straighten');
    await choose(t, 'Accept refinement');
    final model = drawing.painter(t).model;
    expect(model.walls.length, 5);
    for (final point in (before['corners'] as List)) {
      expect(model.corners[point[0]]!.x, point[1]);
      expect(model.corners[point[0]]!.y, point[2]);
    }
    final shared = model.corners.keys.singleWhere((id) =>
        model.walls.values.where((w) => w.start == id || w.end == id).length ==
        3);
    expect(model.corners[shared]!.x, closeTo(1200, .001));
    expect(model.corners[shared]!.y, closeTo(200, .001));
  });
  testWidgets('Cancelling a gesture creates neither a proposal nor walls',
      (t) async {
    await drawing.open(t);
    final origin = t.getTopLeft(drawing.canvas);
    final drag = await t.startGesture(origin + roughSquare.first);
    await drag.moveTo(origin + roughSquare[1]);
    await drag.moveTo(origin + roughSquare[2]);
    await t.pump();
    await drag.cancel();
    await t.pumpAndSettle();
    expect(drawing.painter(t).model.walls, isEmpty);
    expect(find.text('Straighten and refine this sketch?'), findsNothing);
  });
}
