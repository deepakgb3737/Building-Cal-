import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/easy_floor_screen.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/drawing_painter.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';

final canvas = find.byKey(const ValueKey('drawingCanvas'));
DrawingPainter view(WidgetTester t) => t
    .widget<CustomPaint>(
        find.descendant(of: canvas, matching: find.byType(CustomPaint)))
    .painter! as DrawingPainter;

Future<void> palette(WidgetTester t, bool expanded) async {
  final control = find
      .byTooltip(expanded ? 'Expand drawing tools' : 'Collapse drawing tools');
  if (control.evaluate().isNotEmpty) {
    await t.tap(control);
    await t.pumpAndSettle();
  }
}

Future<void> stroke(WidgetTester t, List<Offset> points,
    {bool hold = false, bool refine = false}) async {
  final origin = t.getTopLeft(canvas);
  final drag = await t.startGesture(origin + points.first);
  if (hold) await t.pump(const Duration(milliseconds: 500));
  for (final p in points.skip(1)) {
    await drag.moveTo(origin + p);
    await t.pump();
  }
  await drag.up();
  await t.pumpAndSettle();
  if (find.text('Keep Original').evaluate().isNotEmpty) {
    final choice = find.text(refine ? 'Yes, Straighten' : 'Keep Original');
    await t.ensureVisible(choice);
    await t.tap(choice);
    await t.pumpAndSettle();
    if (refine) {
      await t.ensureVisible(find.text('Accept refinement'));
      await t.tap(find.text('Accept refinement'));
      await t.pumpAndSettle();
    }
  }
  await palette(t, false);
}

Future<void> exercise(WidgetTester t, List<int> ids) async {
  final baseline = view(t).model.toJson();
  for (final id in ids) {
    final v = view(t), wall = v.model.walls[id]!;
    final a = v.model.corners[wall.start]!, b = v.model.corners[wall.end]!;
    final direction = (b - a) * (1 / (b - a).length);
    final normal = DrawingPoint(-direction.y, direction.x);
    final run = v.model.straightRun(id);
    final changed = {
      for (final edge in run) ...[
        v.model.walls[edge]!.start,
        v.model.walls[edge]!.end
      ]
    };
    for (final fraction in [.12, .5, .88]) {
      for (final side in [-12.0, 0.0, 12.0]) {
        for (final sign in [-1.0, 1.0]) {
          final at = t.getTopLeft(canvas) +
              v.screen(a + (b - a) * fraction) +
              Offset(normal.x * side, normal.y * side);
          final drag = await t.startGesture(at);
          await drag
              .moveTo(at + Offset(normal.x * sign * 28, normal.y * sign * 28));
          await t.pump();
          final live = view(t);
          expect(live.selectedWall, id,
              reason: 'wall=$id fraction=$fraction side=$side sign=$sign');
          expect(live.selectedCorner, isNull);
          expect(live.measuredWalls, contains(id));
          expect(live.model.length(id), closeTo(v.model.length(id), .01));
          final delta = live.model.corners[wall.start]! - a;
          expect(delta.dot(normal), closeTo(sign * 28 / v.scale, .01));
          expect(delta.dot(direction), closeTo(0, .01));
          for (final entry in v.model.corners.entries) {
            if (!changed.contains(entry.key)) {
              expect(live.model.corners[entry.key]!.x, entry.value.x);
              expect(live.model.corners[entry.key]!.y, entry.value.y);
            }
          }
          await drag.cancel();
          await t.pumpAndSettle();
          expect(view(t).model.toJson(), baseline);
        }
      }
    }
    final at = t.getTopLeft(canvas) + v.screen((a + b) * .5);
    final drag = await t.startGesture(at);
    await drag.moveTo(at + Offset(normal.x * 28, normal.y * 28));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    expect(view(t).model.toJson(), isNot(baseline));
    await palette(t, true);
    await t.ensureVisible(find.byTooltip('Undo'));
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(view(t).model.toJson(), baseline);
    await palette(t, false);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final layout in ['rectangle', 'diagonal', 'partition']) {
    testWidgets('Physical-device wall sides: $layout', (t) async {
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.light, home: EasyFloorScreen(key: UniqueKey())));
      await t.pumpAndSettle();
      await palette(t, false);
      final size = t.getSize(canvas);
      final left = size.width * .18, right = size.width * .82;
      final top = size.height * .18, bottom = size.height * .48;
      if (layout == 'diagonal') {
        await palette(t, true);
        await t.ensureVisible(find.widgetWithText(ChoiceChip, 'Wall'));
        await t.tap(find.widgetWithText(ChoiceChip, 'Wall'));
        await t.pumpAndSettle();
        await palette(t, false);
        await stroke(t, [Offset(left, top), Offset(right, bottom)]);
      } else {
        await stroke(t, [
          Offset(left, top),
          Offset(right, top),
          Offset(right, bottom),
          Offset(left, bottom),
          Offset(left, top)
        ]);
      }
      if (layout == 'partition') {
        await stroke(
            t,
            [
              Offset((left + right) / 2, top),
              Offset((left + right) / 2, bottom)
            ],
            hold: true);
        expect(view(t).model.walls.length, 7);
        final partition = view(t).model.walls.values.firstWhere((w) =>
            (view(t).model.corners[w.start]!.x -
                        view(t).model.corners[w.end]!.x)
                    .abs() <
                .001 &&
            (view(t).screen(view(t).model.corners[w.start]!).dx -
                        (left + right) / 2)
                    .abs() <
                .01);
        await exercise(t, [partition.id, view(t).model.walls.keys.first]);
      } else {
        await exercise(t, view(t).model.walls.keys.toList());
      }
    });
  }
}
