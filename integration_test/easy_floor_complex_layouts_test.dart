import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/easy_floor_screen.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/dimension_dialog.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'easy_floor_wall_sides_test.dart' show canvas, view, palette, stroke;

Future<void> history(WidgetTester t, String action) async {
  await palette(t, true);
  await t.ensureVisible(find.byTooltip(action));
  await t.tap(find.byTooltip(action));
  await t.pumpAndSettle();
  await palette(t, false);
}

void valid(WidgetTester t) {
  final model = view(t).model;
  expect(() => WallNetwork.fromJson(model.toJson()), returnsNormally);
  for (final wall in model.walls.values) {
    expect(model.length(wall.id), greaterThanOrEqualTo(10));
  }
  expect(t.takeException(), isNull);
}

List<Offset> rough(List<Offset> corners) => [
      corners.first,
      for (var edge = 1; edge < corners.length; edge++)
        for (var step = 1; step <= 8; step++)
          Offset.lerp(corners[edge - 1], corners[edge], step / 8)! +
              (step == 8
                  ? Offset.zero
                  : Offset(-(corners[edge] - corners[edge - 1]).dy,
                          (corners[edge] - corners[edge - 1]).dx) /
                      (corners[edge] - corners[edge - 1]).distance *
                      (step.isEven ? 1.2 : -1.2)),
    ];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const layouts = <String, List<Offset>>{
    'L': [
      Offset(.16, .12),
      Offset(.82, .12),
      Offset(.82, .30),
      Offset(.50, .30),
      Offset(.50, .53),
      Offset(.16, .53),
      Offset(.16, .12)
    ],
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
    'T': [
      Offset(.16, .12),
      Offset(.84, .12),
      Offset(.84, .29),
      Offset(.62, .29),
      Offset(.62, .53),
      Offset(.38, .53),
      Offset(.38, .29),
      Offset(.16, .29),
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
    'junctions': [
      Offset(.16, .12),
      Offset(.84, .12),
      Offset(.84, .53),
      Offset(.16, .53),
      Offset(.16, .12)
    ],
  };
  for (final entry in layouts.entries) {
    testWidgets('Redmi complex workflow ${entry.key}', (t) async {
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.light, home: EasyFloorScreen(key: UniqueKey())));
      await t.pumpAndSettle();
      await palette(t, false);
      final size = t.getSize(canvas);
      Offset at(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
      await stroke(t, rough(entry.value.map(at).toList()), refine: true);
      expect(view(t).model.walls.length, entry.value.length - 1);
      if (entry.key == 'junctions') {
        await stroke(t, [at(const Offset(.5, .12)), at(const Offset(.5, .53))],
            hold: true);
        await stroke(
            t, [at(const Offset(.16, .325)), at(const Offset(.84, .325))],
            hold: true);
        expect(view(t).model.walls.length, 12);
        expect(view(t).model.corners.length, 9);
      }
      valid(t);
      // Leave the rendered plan available for an adb screenshot, not just model assertions.
      debugPrint('DEVICE_REVIEW_READY:${entry.key}');
      await Future<void>.delayed(const Duration(seconds: 5));
      final baseline = view(t).model.toJson();
      final id = view(t).model.walls.keys.first;
      var v = view(t);
      final wall = v.model.walls[id]!;
      final a = v.screen(v.model.corners[wall.start]!);
      final b = v.screen(v.model.corners[wall.end]!);
      final origin = t.getTopLeft(canvas);
      final middle = origin + (a + b) / 2;
      final delta = Offset(-(b - a).dy, (b - a).dx) / (b - a).distance * 18;
      final drag = await t.startGesture(middle);
      await drag.moveBy(delta);
      await t.pump();
      expect(view(t).selectedWall, id);
      expect(view(t).measuredWalls, contains(id));
      await drag.up();
      await t.pumpAndSettle();
      valid(t);
      expect(view(t).model.toJson(), isNot(baseline));
      final moved = view(t).model.toJson();
      await history(t, 'Undo');
      expect(view(t).model.toJson(), baseline);
      await history(t, 'Redo');
      expect(view(t).model.toJson(), moved);
      await history(t, 'Undo');

      v = view(t);
      final corner =
          await t.startGesture(origin + v.screen(v.model.corners[wall.start]!));
      await corner.moveBy(const Offset(-18, -16));
      await t.pump();
      await corner.up();
      await t.pumpAndSettle();
      valid(t);
      expect(view(t).model.toJson(), isNot(baseline));
      await history(t, 'Undo');
      expect(view(t).model.toJson(), baseline);

      await t.tapAt(middle);
      await t.pumpAndSettle();
      v = view(t);
      final label = v.labelBounds![id];
      expect(label, isNotNull);
      await t.tapAt(origin + label!.center);
      await t.pumpAndSettle();
      expect(find.byType(DimensionDialog), findsOneWidget);
      final target = v.model.length(id) + 100;
      final entered = v.unit.input(target, decimalPlaces: 2);
      await t.enterText(find.byType(TextFormField), entered);
      await t.tap(find.text('Apply'));
      await t.pumpAndSettle();
      expect(find.byType(DimensionDialog), findsNothing);
      expect(view(t).model.length(id), closeTo(v.unit.readMm(entered)!, .01));
      valid(t);
      await history(t, 'Undo');
      expect(view(t).model.toJson(), baseline);

      await t.tapAt(middle);
      await t.pumpAndSettle();
      final wallCount = view(t).model.walls.length;
      await t.ensureVisible(find.byTooltip('Delete selected geometry'));
      await t.tap(find.byTooltip('Delete selected geometry'));
      await t.pumpAndSettle();
      expect(view(t).model.walls.length, wallCount - 1);
      valid(t);
      await history(t, 'Undo');
      expect(view(t).model.toJson(), baseline);

      final first =
          await t.startGesture(origin + at(const Offset(.25, .7)), pointer: 1);
      final second =
          await t.startGesture(origin + at(const Offset(.75, .7)), pointer: 2);
      final scale = view(t).scale;
      await first.moveBy(const Offset(-12, 12));
      await second.moveBy(const Offset(12, 12));
      await t.pump();
      expect(view(t).scale, greaterThan(scale));
      await first.up();
      await second.up();
      await t.pumpAndSettle();
      expect(view(t).model.toJson(), baseline);
      valid(t);
      debugPrint('DEVICE_WORKFLOW_PASS:${entry.key}');
    });
  }
}
