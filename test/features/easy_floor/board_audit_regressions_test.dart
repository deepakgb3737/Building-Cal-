import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'drawing_screen_test.dart' as harness;
import 'shape_interaction_test.dart' as shapes;

Offset middle(WidgetTester t) {
  final v = harness.painter(t), w = harness.painter(t).model.walls.values.first;
  return t.getTopLeft(harness.canvas) +
      (v.screen(v.model.corners[w.start]!) +
              v.screen(v.model.corners[w.end]!)) /
          2;
}

void main() {
  test('Moving a short endpoint does not snap onto its own neighbour', () {
    final m = WallNetwork()
      ..addPolyline([
        const DrawingPoint(0, 0),
        const DrawingPoint(1000, 0),
        const DrawingPoint(1000, 1000)
      ]);
    final id = m.corners.keys.first;
    final snapped = m.snap(const DrawingPoint(910, 0), 100, excludeCorner: id);
    expect(snapped.x, 910);
    m.moveCorners({id: snapped}, join: true);
    expect(m.length(m.walls.keys.first), 90);
  });
  testWidgets(
      'Undo during a drag cannot be overwritten by later pointer updates',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    final at = middle(t), drag = await t.startGesture(middle(t), pointer: 7);
    await drag.moveTo(at + const Offset(0, 25));
    await t.pump();
    await t.ensureVisible(find.byTooltip('Undo'));
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls, isEmpty);
    await drag.moveTo(at + const Offset(0, 40));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls, isEmpty);
  });
  testWidgets('Switching tools during a drag discards the uncommitted edit',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    final v = harness.painter(t),
        wall = harness.painter(t).model.walls.values.first;
    final old = v.model.corners[wall.start]!;
    final at = middle(t), drag = await t.startGesture(middle(t), pointer: 7);
    await drag.moveTo(at + const Offset(0, 25));
    await t.pump();
    await harness.tool(t, 'Text');
    await drag.up();
    await t.pumpAndSettle();
    expect(harness.painter(t).model.corners[wall.start]!.y, old.y);
  });
  testWidgets('Cancelling a preset resize restores its original draft',
      (t) async {
    await harness.open(t);
    await shapes.menu(t, 'Shape presets', 'Rectangle');
    await t.tap(find.text('Preview'));
    await t.pumpAndSettle();
    final before = harness.painter(t).preview;
    final origin = t.getTopLeft(harness.canvas);
    final drag = await t.startGesture(origin + const Offset(60, 60));
    await drag.moveTo(origin + const Offset(240, 160));
    await t.pump();
    await drag.cancel();
    await t.pumpAndSettle();
    final after = harness.painter(t).preview;
    expect(after.length, before.length);
    for (var i = 0; i < before.length; i++) {
      expect(after[i].x, before[i].x);
      expect(after[i].y, before[i].y);
    }
    expect(harness.painter(t).model.walls, isEmpty);
    expect(find.text('Place shape'), findsOneWidget);
  });
  testWidgets('Cancelling a pan restores its starting camera', (t) async {
    await harness.open(t);
    await harness.outline(t);
    await harness.tool(t, 'Pan');
    final old = harness.painter(t).origin,
        origin = t.getTopLeft(harness.canvas);
    final drag = await t.startGesture(origin + const Offset(160, 150));
    await drag.moveTo(origin + const Offset(200, 180));
    await t.pump();
    await drag.cancel();
    await t.pumpAndSettle();
    expect(harness.painter(t).origin, old);
  });
}
