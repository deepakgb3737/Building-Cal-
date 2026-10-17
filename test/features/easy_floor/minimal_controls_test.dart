import 'package:flutter_test/flutter_test.dart';
import 'drawing_screen_test.dart' as board;
import 'natural_drawing_test.dart' as sketch;
import 'annotation_interaction_test.dart' as actions;

void main() {
  testWidgets(
      'Automatic selection needs no Select button or duplicate menu actions',
      (t) async {
    await board.open(t);
    expect(find.byTooltip('Select / Move'), findsNothing);
    expect(find.byTooltip('Cancel action'), findsNothing);
    expect(find.byTooltip('Hide labels'), findsOneWidget);
    await t.tap(find.byTooltip('More drawing tools'));
    await t.pumpAndSettle();
    expect(find.text('Show all measurements'), findsNothing);
    expect(find.text('Cancel action'), findsNothing);
    expect(find.text('Drawing help'), findsOneWidget);
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(board.painter(t).model.walls, isEmpty);
    expect(t.takeException(), isNull);
  });

  for (final partition in [false, true]) {
    testWidgets(
        'Interior selection deletes only its ${partition ? 'partitioned' : 'single'} shape, with confirmation and Undo',
        (t) async {
      await board.open(t);
      await board.outline(t);
      await board.collapseTools(t);
      if (partition) {
        await sketch.stroke(t, const [Offset(160, 60), Offset(160, 220)],
            hold: true);
      }
      await sketch.stroke(t, const [Offset(40, 310), Offset(250, 310)]);
      final before = board.painter(t).model.toJson();
      final neighbour = board.painter(t).model.walls.values.last;
      final corners = Map.of(board.painter(t).model.corners);
      await t.tapAt(t.getTopLeft(board.canvas) + const Offset(110, 105));
      await t.pumpAndSettle();
      expect(find.text('Connected shape · ${partition ? 7 : 4} walls'),
          findsOneWidget);
      expect(find.byTooltip('Expand drawing tools'), findsOneWidget);
      final remove = find.byTooltip('Delete selected geometry');
      await t.ensureVisible(remove);
      await t.tap(remove);
      await t.pumpAndSettle();
      expect(find.text('Delete shape'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(board.painter(t).model.toJson(), before);
      await t.tap(remove);
      await t.pumpAndSettle();
      await t.tap(find.text('Delete shape'));
      await t.pumpAndSettle();
      final remaining = board.painter(t).model;
      expect(remaining.walls.keys, [neighbour.id]);
      expect(remaining.corners[neighbour.start], corners[neighbour.start]);
      expect(remaining.corners[neighbour.end], corners[neighbour.end]);
      expect(remove, findsNothing);
      await actions.undo(t, 'Undo');
      expect(board.painter(t).model.toJson(), before);
      await actions.undo(t, 'Redo');
      expect(board.painter(t).model.walls.keys, [neighbour.id]);
      expect(t.takeException(), isNull);
    });
  }
}
