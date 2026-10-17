import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'drawing_screen_test.dart' as harness;
import 'natural_drawing_test.dart' as natural;

Future<void> menu(WidgetTester t, String tooltip, String label) async {
  await harness.expandTools(t);
  final target =
      find.byTooltip(tooltip == 'Shape presets' ? 'Shapes' : tooltip);
  await t.ensureVisible(target);
  await t.tap(target);
  await t.pumpAndSettle();
  final name = label == 'Freeform polygon' ? 'Irregular Shape' : label;
  final item = tooltip == 'Shape presets'
      ? find.widgetWithText(ChoiceChip, name)
      : find.text(name);
  await t.ensureVisible(item);
  await t.tap(item);
  await t.pumpAndSettle();
}

void main() {
  for (final unit in DrawingUnit.values) {
    testWidgets('Exact dimension entry respects ${unit.symbol}', (t) async {
      await harness.open(t);
      await harness.outline(t);
      await menu(t, 'Measurement unit', unit.name);
      final view = harness.painter(t),
          wall = harness.painter(t).model.walls.values.first;
      final at = t.getTopLeft(harness.canvas) +
          (view.screen(view.model.corners[wall.start]!) +
                  view.screen(view.model.corners[wall.end]!)) /
              2;
      await t.tapAt(at);
      await t.pumpAndSettle();
      await t.tap(find.text('Enter length'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField), unit.input(2500));
      await t.tap(find.text('Apply'));
      await t.pumpAndSettle();
      expect(harness.painter(t).model.length(wall.id), closeTo(2500, 1e-6));
      expect(harness.painter(t).unit, unit);
    });
  }
  testWidgets('Preset drag resizes and connects to an existing room boundary',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    await menu(t, 'Shape presets', 'Rectangle');
    await t.tap(find.text('Preview'));
    await t.pumpAndSettle();
    final view = harness.painter(t);
    final anchor = view.model.corners.values
        .reduce((a, b) => a.y > b.y || (a.y == b.y && a.x < b.x) ? a : b);
    final at = t.getTopLeft(harness.canvas) + view.screen(anchor);
    final drag = await t.startGesture(at);
    await drag.moveTo(at + const Offset(200, 100));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    final points = harness.painter(t).preview;
    expect((points[1] - points[0]).length, closeTo(2000, .001));
    expect((points[2] - points[1]).length, closeTo(1000, .001));
    await t.ensureVisible(find.text('Place shape'));
    await t.tap(find.text('Place shape'));
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls.length, 7);
    expect(harness.painter(t).model.corners.length, 6);
  });

  testWidgets(
      'Rough square offers clean preview with accept and retain choices',
      (t) async {
    await harness.open(t);
    await natural.stroke(
        t,
        const [
          Offset(60, 60),
          Offset(260, 62),
          Offset(258, 258),
          Offset(58, 260),
          Offset(60, 60)
        ],
        finish: false);
    expect(find.text('Straighten and refine this sketch?'), findsOneWidget);
    expect(harness.painter(t).model.walls, isEmpty);
    expect(harness.painter(t).rawStroke, isNotEmpty);
    await t.ensureVisible(find.text('Yes, Straighten'));
    await t.tap(find.text('Yes, Straighten'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Accept refinement'));
    await t.tap(find.text('Accept refinement'));
    await t.pumpAndSettle();
    final m = harness.painter(t).model;
    expect(m.walls.length, 4);
    final lengths = m.walls.keys.map(m.length).toList();
    for (final length in lengths) {
      expect(length, closeTo(lengths.first, .001));
    }
    await t.ensureVisible(find.byTooltip('Undo'));
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls, isEmpty);
  });
  testWidgets('Keep sketch preserves original vertices', (t) async {
    await harness.open(t);
    await natural.stroke(
        t,
        const [
          Offset(60, 60),
          Offset(260, 62),
          Offset(258, 258),
          Offset(58, 260),
          Offset(60, 60)
        ],
        finish: false);
    await t.ensureVisible(find.text('Keep Original'));
    await t.tap(find.text('Keep Original'));
    await t.pumpAndSettle();
    final m = harness.painter(t).model;
    expect(m.nearestCorner(const DrawingPoint(2200, 220), .001), isNotNull);
  });
  testWidgets('Preset dimensions and rotation remain editable before placement',
      (t) async {
    await harness.open(t);
    await menu(t, 'Shape presets', 'Rectangle');
    final fields = find.byType(TextFormField);
    await t.enterText(fields.at(0), '3');
    await t.enterText(fields.at(1), '2');
    await t.enterText(fields.at(2), '30');
    await t.tap(find.text('Preview'));
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls, isEmpty);
    expect(harness.painter(t).preview.length, 5);
    await t.ensureVisible(find.text('Place shape'));
    await t.tap(find.text('Place shape'));
    await t.pumpAndSettle();
    final m = harness.painter(t).model;
    expect(m.length(m.walls.keys.first), closeTo(3000, .001));
    expect(m.walls.length, 4);
    expect(harness.painter(t).preview, isEmpty);
  });
  testWidgets(
      'Select all delete and confirmed clear are undoable without changing units',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    final before = harness.painter(t);
    final fixedWall = before.model.walls.values.first;
    await t.tapAt(t.getTopLeft(harness.canvas) +
        (before.screen(before.model.corners[fixedWall.start]!) +
                before.screen(before.model.corners[fixedWall.end]!)) /
            2);
    await t.pumpAndSettle();
    await t.tap(find.text('Enter length'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField), '2');
    await t.tap(find.text('Apply'));
    await t.pumpAndSettle();
    await harness.moreWallOptions(t);
    await t.ensureVisible(find.text('Lock length'));
    await t.tap(find.text('Lock length'));
    await t.pumpAndSettle();
    await menu(t, 'Plan actions', 'Select all');
    expect(harness.painter(t).allSelected, isTrue);
    await t.ensureVisible(find.byTooltip('Delete selected geometry'));
    await t.tap(find.byTooltip('Delete selected geometry'));
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls, isEmpty);
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(harness.painter(t).model.corners.length, 4);
    expect(harness.painter(t).model.isFixed(fixedWall.id), isTrue);
    expect(harness.painter(t).unit, DrawingUnit.metres);
    await menu(t, 'Plan actions', 'Clear plan');
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls.length, 4);
    await menu(t, 'Plan actions', 'Clear plan');
    await t.tap(find.text('Clear plan'));
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls, isEmpty);
    await t.ensureVisible(find.byTooltip('Undo'));
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls.length, 4);
    expect(harness.painter(t).model.corners.length, 4);
  });
  testWidgets(
      'Global unit switch changes labels but not wall geometry; exact ft/in input works',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    var view = harness.painter(t);
    final wall = view.model.walls.values.first;
    final length = view.model.length(wall.id);
    await menu(t, 'Measurement unit', 'Feet and inches');
    view = harness.painter(t);
    expect(view.unit, DrawingUnit.feetInches);
    expect(view.model.length(wall.id), length);
    final at = t.getTopLeft(harness.canvas) +
        (view.screen(view.model.corners[wall.start]!) +
                view.screen(view.model.corners[wall.end]!)) /
            2;
    await t.tapAt(at);
    await t.pumpAndSettle();
    await t.tap(find.text('Enter length'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField), '8 6');
    await t.tap(find.text('Apply'));
    await t.pumpAndSettle();
    expect(harness.painter(t).model.length(wall.id), closeTo(2590.8, .001));
  });
  testWidgets('Freeform polygon creates connected editable wall segments',
      (t) async {
    await harness.open(t);
    await menu(t, 'Shape presets', 'Freeform polygon');
    final origin = t.getTopLeft(harness.canvas);
    for (final p in const [
      Offset(50, 60),
      Offset(240, 90),
      Offset(200, 220),
      Offset(70, 190)
    ]) {
      await t.tapAt(origin + p);
      await t.pumpAndSettle();
    }
    await t.ensureVisible(find.text('Finish polygon'));
    await t.tap(find.text('Finish polygon'));
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls.length, 4);
    expect(harness.painter(t).model.corners.length, 4);
  });
}
