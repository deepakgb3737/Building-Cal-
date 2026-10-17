import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/easy_floor_screen.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/drawing_painter.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';

Finder get canvas => find.byKey(const ValueKey('drawingCanvas'));
Future<void> moreWallOptions(WidgetTester t) async {
  await t.ensureVisible(find.text('More wall options'));
  await t.tap(find.text('More wall options'));
  await t.pumpAndSettle();
}

Future<void> expandTools(WidgetTester tester) async {
  final button = find.byTooltip('Expand drawing tools');
  if (button.evaluate().isNotEmpty) {
    await tester.tap(button);
    await tester.pumpAndSettle();
  }
}

Future<void> collapseTools(WidgetTester tester) async {
  final button = find.byTooltip('Collapse drawing tools');
  if (button.evaluate().isNotEmpty) {
    await tester.tap(button);
    await tester.pumpAndSettle();
  }
}

DrawingPainter painter(WidgetTester tester) => tester
    .widget<CustomPaint>(
        find.descendant(of: canvas, matching: find.byType(CustomPaint)))
    .painter! as DrawingPainter;
// Existing geometry/label scenarios explicitly exercise the all-measurements view.
Future<void> open(WidgetTester tester, {bool showLabels = true}) async {
  tester.view.physicalSize = const Size(320, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const EasyFloorScreen()));
  final labels =
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Labels'));
  if (labels.selected != showLabels) {
    labels.onSelected!(showLabels);
  }
  await tester.pumpAndSettle();
}

Future<void> outline(WidgetTester tester) async {
  final origin = tester.getTopLeft(canvas);
  final gesture = await tester.startGesture(origin + const Offset(60, 60));
  for (final p in [
    const Offset(260, 60),
    const Offset(260, 220),
    const Offset(60, 220),
    const Offset(61, 61)
  ]) {
    await gesture.moveTo(origin + p);
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
  await keepSketch(tester);
}

Future<void> keepSketch(WidgetTester tester) async {
  final button = find.text('Keep Original');
  if (button.evaluate().isEmpty && painter(tester).rawStroke.isNotEmpty) {
    await expandTools(tester);
  }
  if (button.evaluate().isEmpty) return;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> tool(WidgetTester tester, String label) async {
  await expandTools(tester);
  final chip =
      find.widgetWithText(ChoiceChip, label == 'Outline' ? 'Draw' : label);
  if (chip.evaluate().isNotEmpty) {
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    return;
  }
  await tester.ensureVisible(find.byTooltip('Shapes'));
  await tester.tap(find.byTooltip('Shapes'));
  await tester.pumpAndSettle();
  final item = find.text(label);
  final button = find.ancestor(of: item, matching: find.byType(ChoiceChip));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'Visible Single wall draws one straight wall and Freehand remains available',
      (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Text'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Wall'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Wall'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Wall'))
            .selected,
        isTrue);
    final origin = tester.getTopLeft(canvas);
    final gesture = await tester.startGesture(origin + const Offset(60, 60));
    await gesture.moveTo(origin + const Offset(150, 140));
    await tester.pump();
    await gesture.moveTo(origin + const Offset(260, 60));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(painter(tester).model.walls.length, 1);
    expect(painter(tester).model.corners.length, 2);
    expect(find.text('Straighten and refine this sketch?'), findsNothing);
    expect(find.byKey(const ValueKey('annotationText')), findsNothing);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Draw'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Draw'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Draw'))
            .selected,
        isTrue);
    final freehandOrigin = tester.getTopLeft(canvas);
    final freehand =
        await tester.startGesture(freehandOrigin + const Offset(70, 180));
    await freehand.moveTo(freehandOrigin + const Offset(200, 180));
    await tester.pump();
    await freehand.moveTo(freehandOrigin + const Offset(200, 300));
    await tester.pump();
    await freehand.up();
    await tester.pumpAndSettle();
    expect(find.text('Straighten and refine this sketch?'), findsOneWidget);
    expect(painter(tester).model.walls.length, 1);
  });
  testWidgets(
      'Smart touch edits walls and nearby corners without tool switching',
      (tester) async {
    await open(tester);
    await outline(tester);
    var view = painter(tester);
    final wall = view.model.walls.values.first;
    final old = view.model.corners[wall.start]!;
    var at = tester.getTopLeft(canvas) +
        (view.screen(old) + view.screen(view.model.corners[wall.end]!)) / 2;
    var drag = await tester.startGesture(at);
    await drag.moveTo(at + const Offset(25, 25));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    view = painter(tester);
    expect(view.model.length(wall.id), closeTo(2000, .001));
    expect(view.model.corners[wall.start]!.y, closeTo(old.y + 250, .001));
    final cornerBefore = view.model.corners[wall.start]!;
    at = tester.getTopLeft(canvas) +
        view.screen(cornerBefore) +
        const Offset(5, 5);
    drag = await tester.startGesture(at);
    await drag.moveTo(at + const Offset(30, 20));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    view = painter(tester);
    expect(view.selectedCorner, wall.start);
    expect(
        view.model.corners[wall.start]!.x, closeTo(cornerBefore.x + 300, .001));
    expect(view.model.walls.length, 4);
  });
  testWidgets(
      'Tapping a rendered dimension opens precise entry without drawing',
      (tester) async {
    await open(tester);
    await outline(tester);
    final view = painter(tester);
    expect(view.labelBounds!.length, 2);
    final wall = view.model.walls.values.first;
    await tester.tapAt(tester.getTopLeft(canvas) +
        (view.screen(view.model.corners[wall.start]!) +
                view.screen(view.model.corners[wall.end]!)) /
            2);
    await tester.pumpAndSettle();
    final label = painter(tester).labelBounds!.entries.first;
    await tester.tapAt(tester.getTopLeft(canvas) + label.value.center);
    await tester.pumpAndSettle();
    expect(find.text('Apply'), findsOneWidget);
    expect(painter(tester).model.walls.length, 4);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Smart edits use world coordinates after fit zoom',
      (tester) async {
    await open(tester);
    await outline(tester);
    await tester.ensureVisible(find.byTooltip('Fit to Screen'));
    await tester.tap(find.byTooltip('Fit to Screen'));
    await tester.pumpAndSettle();
    final view = painter(tester);
    expect(view.scale, isNot(closeTo(.1, .001)));
    final wall = view.model.walls.values.first;
    final old = view.model.corners[wall.start]!;
    final at = tester.getTopLeft(canvas) +
        (view.screen(old) + view.screen(view.model.corners[wall.end]!)) / 2;
    final drag = await tester.startGesture(at);
    await drag.moveTo(at + const Offset(0, 25));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    expect(painter(tester).model.corners[wall.start]!.y,
        closeTo(old.y + 25 / view.scale, .001));
    expect(painter(tester).model.length(wall.id), closeTo(2000, .001));
  });
  testWidgets('Stylus input creates an independent single wall',
      (tester) async {
    await open(tester);
    await tool(tester, 'Wall');
    final origin = tester.getTopLeft(canvas);
    final gesture = await tester.startGesture(origin + const Offset(60, 60),
        kind: PointerDeviceKind.stylus);
    await gesture.moveTo(origin + const Offset(180, 110));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(painter(tester).model.walls.length, 1);
    expect(painter(tester).model.corners.length, 2);
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets('Drawing controls fit $size with enlarged text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!),
          home: const EasyFloorScreen()));
      expect(tester.getSize(canvas).height, greaterThan(100));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('A selected wall can be resized by dragging along its direction',
      (tester) async {
    await open(tester);
    await outline(tester);
    var view = painter(tester);
    final wall = view.model.walls.values.first;
    var at = tester.getTopLeft(canvas) +
        (view.screen(view.model.corners[wall.start]!) +
                view.screen(view.model.corners[wall.end]!)) /
            2;
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    await tester.tap(find.text('More wall options'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Drag length'));
    await tester.tap(find.text('Drag length'));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(at);
    await gesture.moveTo(at + const Offset(40, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    view = painter(tester);
    expect(view.model.length(wall.id), closeTo(2400, .001));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Live dimensions use world units and a closed stroke creates four connected walls',
      (tester) async {
    await open(tester);
    final origin = tester.getTopLeft(canvas);
    final gesture = await tester.startGesture(origin + const Offset(60, 60));
    await gesture.moveTo(origin + const Offset(260, 60));
    await tester.pump();
    final live = painter(tester);
    expect(live.preview.length, 2);
    expect(
        (live.preview.last - live.preview.first).length, closeTo(2000, .001));
    expect(live.unit.format(2000), '2 m');
    for (final p in [
      const Offset(260, 220),
      const Offset(60, 220),
      const Offset(61, 61)
    ]) {
      await gesture.moveTo(origin + p);
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    await keepSketch(tester);
    expect(painter(tester).model.walls.length, 4);
    expect(painter(tester).model.corners.length, 4);
    expect(find.text('Save'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byTooltip('Undo'));
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(painter(tester).model.walls, isEmpty);
    await tester.tap(find.byTooltip('Redo'));
    await tester.pumpAndSettle();
    expect(painter(tester).model.walls.length, 4);
  });
  testWidgets(
      'Corner drag respects finger offset and updates only connected walls',
      (tester) async {
    await open(tester);
    await outline(tester);
    final before = painter(tester);
    final id = before.model.corners.keys.first;
    final old = before.model.corners[id]!;
    final at =
        tester.getTopLeft(canvas) + before.screen(old) + const Offset(4, 4);
    final gesture = await tester.startGesture(at);
    await gesture.moveTo(at + const Offset(24, 14));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    final point = painter(tester).model.corners[id]!;
    expect(point.x, closeTo(old.x + 240, .001));
    expect(point.y, closeTo(old.y + 140, .001));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Selected wall translates freely and exact dimensions are editable',
      (tester) async {
    await open(tester);
    await outline(tester);
    var view = painter(tester);
    final wall = view.model.walls.values.first;
    final a = view.model.corners[wall.start]!,
        b = view.model.corners[wall.end]!;
    final at =
        tester.getTopLeft(canvas) + (view.screen(a) + view.screen(b)) / 2;
    final gesture = await tester.startGesture(at);
    await gesture.moveTo(at + const Offset(40, 20));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    view = painter(tester);
    expect(view.model.corners[wall.start]!.x, closeTo(a.x + 400, .001));
    expect(view.model.corners[wall.start]!.y, closeTo(a.y + 200, .001));
    expect(view.model.length(wall.id), closeTo(2000, .001));
    await tester.tap(find.text('Enter length'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '2.5');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(painter(tester).model.length(wall.id), closeTo(2500, .001));
    expect(painter(tester).model.isFixed(wall.id), isFalse);
    expect(painter(tester).model.rectangle(wall.id), isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Pinch changes the camera without changing the drawing',
      (tester) async {
    await open(tester);
    await outline(tester);
    final before = painter(tester);
    final lengths = before.model.walls.keys.map(before.model.length).toList();
    final origin = tester.getTopLeft(canvas);
    final one =
        await tester.startGesture(origin + const Offset(120, 140), pointer: 1);
    final two =
        await tester.startGesture(origin + const Offset(200, 140), pointer: 2);
    await one.moveTo(origin + const Offset(90, 140));
    await two.moveTo(origin + const Offset(230, 140));
    await tester.pump();
    await one.moveTo(origin + const Offset(60, 140));
    await two.moveTo(origin + const Offset(260, 140));
    await tester.pump();
    await one.up();
    await two.up();
    await tester.pumpAndSettle();
    final after = painter(tester);
    expect(after.scale, greaterThan(before.scale));
    expect(after.model.walls.keys.map(after.model.length).toList(), lengths);
    expect(tester.takeException(), isNull);
  });
}
