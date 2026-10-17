import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_annotations.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_guides.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/annotation_painter.dart';
import 'drawing_screen_test.dart' as harness;
import 'advanced_interaction_test.dart' as editing;

AnnotationPainter textView(WidgetTester t) => t
    .widget<CustomPaint>(
        find.descendant(of: harness.canvas, matching: find.byType(CustomPaint)))
    .foregroundPainter! as AnnotationPainter;
Future<void> textTool(WidgetTester t) async {
  await harness.expandTools(t);
  final chip = find.widgetWithText(ChoiceChip, 'Text');
  await t.ensureVisible(chip);
  if (!t.widget<ChoiceChip>(chip).selected) {
    await t.tap(chip);
  }
  await t.pumpAndSettle();
  await harness.collapseTools(t);
}

Future<void> add(WidgetTester t, String text, Offset position) async {
  await textTool(t);
  await t.tapAt(t.getTopLeft(harness.canvas) + position);
  await t.pumpAndSettle();
  await t.enterText(find.byKey(const ValueKey('annotationText')), text);
  await t.tap(find.text('Apply text'));
  await t.pumpAndSettle();
}

Offset noteAt(WidgetTester t, int id) =>
    t.getTopLeft(harness.canvas) + textView(t).bounds[id]!.center;
Future<void> undo(WidgetTester t, String name) async {
  await harness.expandTools(t);
  await t.ensureVisible(find.byTooltip(name));
  await t.tap(find.byTooltip(name));
  await t.pumpAndSettle();
  await harness.collapseTools(t);
}

void main() {
  testWidgets(
      'Editing text applies content and participates in ordered undo and redo',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    final geometry = editing.geometry(t);
    await add(t, 'Room A', const Offset(90, 120));
    final id = textView(t).annotations.items.keys.single;
    await t.tapAt(noteAt(t, id));
    await t.pumpAndSettle();
    await t.enterText(
        find.byKey(const ValueKey('annotationText')), 'Kitchen\nSite note');
    // A modal barrier absorbs drawing attempts until editing is complete.
    await t.tapAt(const Offset(5, 400));
    await t.pump();
    expect(find.byKey(const ValueKey('annotationText')), findsOneWidget);
    await t.tap(find.text('Apply text'));
    await t.pumpAndSettle();
    expect(textView(t).annotations.items[id]!.text, 'Kitchen\nSite note');
    expect(editing.geometry(t), geometry);
    await undo(t, 'Undo');
    expect(textView(t).annotations.items[id]!.text, 'Room A');
    await undo(t, 'Redo');
    expect(textView(t).annotations.items[id]!.text, 'Kitchen\nSite note');
    expect(editing.geometry(t), geometry);
  });
  for (final size in [const Size(240, 420), const Size(740, 360)]) {
    testWidgets('Text editor fits $size with enlarged system text', (t) async {
      await harness.open(t);
      t.view.physicalSize = size;
      t.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpAndSettle();
      await add(t, 'Room label', const Offset(80, 50));
      expect(textView(t).annotations.items.length, 1);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Create multiline text, format it, tap to edit and cancel safely',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    final geometry = editing.geometry(t);
    await textTool(t);
    await t.tapAt(t.getTopLeft(harness.canvas) + const Offset(90, 110));
    await t.pumpAndSettle();
    await t.tap(find.text('Apply text'));
    await t.pump();
    expect(find.text('Enter text'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('annotationText')),
        'Room A\nConstruction note');
    await t.drag(find.byType(Slider), const Offset(20, 0));
    await t.pumpAndSettle();
    final color = find.byType(DropdownButtonFormField<AnnotationInk>);
    await t.ensureVisible(color);
    await t.tap(color);
    await t.pumpAndSettle();
    await t.tap(find.text('red').last);
    await t.pumpAndSettle();
    final align = find.byType(DropdownButtonFormField<AnnotationAlignment>);
    await t.ensureVisible(align);
    await t.tap(align);
    await t.pumpAndSettle();
    await t.tap(find.text('right').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Apply text'));
    await t.pumpAndSettle();
    final note = textView(t).annotations.items.values.single;
    expect(note.text, 'Room A\nConstruction note');
    expect(note.sizeMm, greaterThan(180));
    expect(note.ink, AnnotationInk.red);
    expect(note.alignment, AnnotationAlignment.right);
    expect(editing.geometry(t), geometry);
    await t.tapAt(noteAt(t, note.id));
    await t.pumpAndSettle();
    expect(find.text('Edit text'), findsWidgets);
    await t.enterText(find.byKey(const ValueKey('annotationText')), 'Rejected');
    await t.tap(find.text('Cancel').last);
    await t.pumpAndSettle();
    expect(textView(t).annotations.items[note.id]!.text, note.text);
    expect(editing.geometry(t), geometry);
  });
  testWidgets(
      'Text over walls moves independently; repeated moves and cancel preserve formatting',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    final geometry = editing.geometry(t);
    await add(t, 'Room A', const Offset(60, 60));
    final original = textView(t).annotations.items.values.single;
    await harness.expandTools(t);
    await t.ensureVisible(find.widgetWithText(ChoiceChip, 'Text'));
    await t.tap(find.widgetWithText(ChoiceChip, 'Text'));
    await t.pumpAndSettle();
    await harness.collapseTools(t);
    for (var i = 0; i < 3; i++) {
      final at = noteAt(t, original.id),
          drag = await t.startGesture(noteAt(t, original.id));
      await drag.moveTo(at + const Offset(20, 15));
      await t.pump();
      await drag.up();
      await t.pumpAndSettle();
      expect(editing.geometry(t), geometry);
    }
    final moved = textView(t).annotations.items[original.id]!;
    expect(moved.position.x, closeTo(original.position.x + 600, 1e-6));
    expect(moved.position.y, closeTo(original.position.y + 450, 1e-6));
    expect(moved.text, original.text);
    final at = noteAt(t, original.id),
        drag = await t.startGesture(noteAt(t, original.id));
    await drag.moveTo(at + const Offset(30, 30));
    await t.pump();
    await drag.cancel();
    await t.pumpAndSettle();
    expect(textView(t).annotations.items[original.id]!.position,
        same(moved.position));
    await undo(t, 'Undo');
    expect(textView(t).annotations.items[original.id]!.position.x,
        closeTo(original.position.x + 400, 1e-6));
    expect(editing.geometry(t), geometry);
  });
  testWidgets(
      'Text groups move, duplicate, delete and restore without changing walls',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    final geometry = editing.geometry(t);
    await add(t, 'A', const Offset(90, 100));
    await add(t, 'B', const Offset(180, 190));
    final before = textView(t).annotations.copy(),
        ids = before.items.keys.toList();
    await t.tap(find.text('Select texts'));
    await t.pumpAndSettle();
    for (final id in ids) {
      await t.tapAt(noteAt(t, id));
      await t.pumpAndSettle();
    }
    expect(textView(t).selected.length, 2);
    final at = noteAt(t, ids.first),
        drag = await t.startGesture(noteAt(t, ids.first));
    await drag.moveTo(at + const Offset(30, 20));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    for (final id in ids) {
      expect(textView(t).annotations.items[id]!.position.x,
          closeTo(before.items[id]!.position.x + 300, 1e-6));
    }
    await t.ensureVisible(find.byTooltip('Duplicate text'));
    await t.tap(find.byTooltip('Duplicate text'));
    await t.pumpAndSettle();
    expect(textView(t).annotations.items.length, 4);
    await t.ensureVisible(find.byTooltip('Delete text'));
    await t.tap(find.byTooltip('Delete text'));
    await t.pumpAndSettle();
    expect(textView(t).annotations.items.length, 2);
    await undo(t, 'Undo');
    expect(textView(t).annotations.items.length, 4);
    await undo(t, 'Redo');
    expect(textView(t).annotations.items.length, 2);
    expect(editing.geometry(t), geometry);
  });
  testWidgets('Text guides align notes without adding wall geometry',
      (t) async {
    await harness.open(t);
    await add(t, 'A', const Offset(60, 100));
    await add(t, 'B', const Offset(180, 190));
    final id = textView(t).annotations.items.keys.last;
    final at = noteAt(t, id), drag = await t.startGesture(noteAt(t, id));
    await drag.moveTo(at - const Offset(120, 0));
    await t.pump();
    expect(harness.painter(t).guides.any((g) => g.kind == GuideKind.vertical),
        isTrue);
    expect(harness.painter(t).guideOpacity, .5);
    await drag.up();
    await t.pumpAndSettle();
    expect(harness.painter(t).model.walls, isEmpty);
    expect(harness.painter(t).guides, isEmpty);
  });
  testWidgets(
      'Pinch during a text drag rolls back the edit and preserves positions during zoom',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    await add(t, 'Kitchen', const Offset(90, 120));
    final before = textView(t).annotations.copy(),
        geometry = editing.geometry(t);
    final id = before.items.keys.single,
        at = noteAt(t, before.items.keys.single);
    final a = await t.startGesture(at, pointer: 1);
    await a.moveTo(at + const Offset(30, 20));
    await t.pump();
    final origin = t.getTopLeft(harness.canvas);
    final b = await t.startGesture(origin + const Offset(260, 40), pointer: 2);
    await b.moveTo(origin + const Offset(290, 40));
    await t.pump();
    await a.up();
    await b.up();
    await t.pumpAndSettle();
    expect(textView(t).annotations.sameAs(before), isTrue);
    expect(textView(t).annotations.items[id]!.position,
        same(before.items[id]!.position));
    expect(editing.geometry(t), geometry);
    expect(harness.painter(t).scale, isNot(.1));
    await undo(t, 'Undo');
    expect(textView(t).annotations.items, isEmpty);
    expect(editing.geometry(t), geometry);
  });
  testWidgets('Clear and undo restore both independent text and walls',
      (t) async {
    await harness.open(t);
    await harness.outline(t);
    await add(t, 'Site notes', const Offset(90, 120));
    final geometry = editing.geometry(t),
        notes = textView(t).annotations.copy();
    await editing.menu(t, 'Plan actions', 'Clear plan');
    await t.tap(find.text('Clear plan'));
    await t.pumpAndSettle();
    expect(textView(t).annotations.items, isEmpty);
    expect(harness.painter(t).model.walls, isEmpty);
    await undo(t, 'Undo');
    expect(textView(t).annotations.sameAs(notes), isTrue);
    expect(editing.geometry(t), geometry);
  });
}
