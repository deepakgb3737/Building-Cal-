import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/document_repository.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_annotations.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/floor_document.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'drawing_screen_test.dart' as board;
import 'annotation_interaction_test.dart' as notes;
import 'document_interaction_test.dart' as documents;
import 'document_test_support.dart';
import 'shape_interaction_test.dart' as shapes;
import 'natural_drawing_test.dart' as strokes;

DrawingPoint world(WidgetTester t, Offset p) {
  final v = board.painter(t);
  return DrawingPoint(
      (p.dx - v.origin.dx) / v.scale, (p.dy - v.origin.dy) / v.scale);
}

Future<void> tool(WidgetTester t, String name) async {
  await board.expandTools(t);
  await t.ensureVisible(find.widgetWithText(ChoiceChip, name));
  await t.tap(find.widgetWithText(ChoiceChip, name));
  await t.pumpAndSettle();
  await board.collapseTools(t);
}

Future<void> fit(WidgetTester t) async {
  await board.expandTools(t);
  await t.ensureVisible(find.byTooltip('Fit to Screen'));
  await t.tap(find.byTooltip('Fit to Screen'));
  await t.pumpAndSettle();
  await board.collapseTools(t);
}

void main() {
  testWidgets('Pinch in/out preserves finger midpoint, geometry and history',
      (t) async {
    await board.open(t);
    await board.outline(t);
    final geometry = board.painter(t).model.toJson();
    final origin = t.getTopLeft(board.canvas);
    final a = await t.startGesture(origin + const Offset(90, 290), pointer: 1);
    final b = await t.startGesture(origin + const Offset(230, 290), pointer: 2);
    await a.moveTo(origin + const Offset(80, 290));
    await b.moveTo(origin + const Offset(240, 290));
    await t.pump();
    final anchor = world(t, const Offset(160, 290));
    final initial = board.painter(t).scale;
    await a.moveTo(origin + const Offset(50, 300));
    await b.moveTo(origin + const Offset(270, 340));
    await t.pump();
    final after = world(t, const Offset(160, 320));
    expect(after.x, closeTo(anchor.x, .001));
    expect(after.y, closeTo(anchor.y, .001));
    expect(board.painter(t).scale, greaterThan(initial));
    await a.moveTo(origin + const Offset(110, 300));
    await b.moveTo(origin + const Offset(210, 300));
    await t.pump();
    expect(board.painter(t).scale, lessThan(initial));
    await b.up();
    await a.moveTo(origin + const Offset(40, 240));
    await t.pump();
    await a.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), geometry);
    expect(find.text('Straighten and refine this sketch?'), findsNothing);
    await notes.undo(t, 'Undo');
    expect(board.painter(t).model.walls, isEmpty);
  });
  testWidgets('Pan mode moves only the camera and cancellation restores it',
      (t) async {
    await board.open(t);
    await board.outline(t);
    await tool(t, 'Pan');
    final geometry = board.painter(t).model.toJson();
    final camera = board.painter(t).origin;
    final at = t.getTopLeft(board.canvas) + const Offset(100, 300);
    final drag = await t.startGesture(at);
    await drag.moveTo(at + const Offset(70, 30));
    await t.pump();
    expect(board.painter(t).origin, camera + const Offset(70, 30));
    await drag.cancel();
    await t.pumpAndSettle();
    expect(board.painter(t).origin, camera);
    expect(board.painter(t).model.toJson(), geometry);
  });
  testWidgets(
      'Fit includes full annotations at distant coordinates and double tap matches it',
      (t) async {
    final walls = WallNetwork()
      ..addPolyline(const [
        DrawingPoint(-1000000, 0),
        DrawingPoint(1000000, 0),
        DrawingPoint(1000000, 1000000)
      ]);
    final layer = DrawingAnnotations()
      ..add(
          'Site note\nOutside the plan', const DrawingPoint(-1100000, -100000));
    final repo = DocumentRepository(TestDocumentStorage());
    await repo.save(
        FloorDocument(walls, layer, const DocumentSettings()), 'Large plan');
    await documents.openWorkspace(t, repo);
    await documents.openSaved(t, 'Large plan');
    final before = board.painter(t).model.toJson();
    await fit(t);
    final scale = board.painter(t).scale;
    final size = t.getSize(board.canvas);
    for (final p in board.painter(t).model.corners.values) {
      final at = board.painter(t).screen(p);
      expect(at.dx, inInclusiveRange(20, size.width - 20));
      expect(at.dy, inInclusiveRange(20, size.height - 20));
    }
    final rect = notes.textView(t).bounds.values.single;
    expect(rect.left, greaterThanOrEqualTo(20));
    expect(rect.top, greaterThanOrEqualTo(20));
    expect(rect.right, lessThanOrEqualTo(size.width - 20));
    expect(rect.bottom, lessThanOrEqualTo(size.height - 20));
    expect(scale, lessThan(.005));
    await tool(t, 'Pan');
    await fit(t);
    final camera = board.painter(t).origin;
    final origin = t.getTopLeft(board.canvas);
    final drag = await t.startGesture(origin + const Offset(30, 300));
    await drag.moveBy(const Offset(25, 20));
    await drag.up();
    await t.pumpAndSettle();
    final empty = origin + const Offset(8, 8);
    await t.tapAt(empty);
    await t.pump(const Duration(milliseconds: 80));
    await t.tapAt(empty);
    await t.pumpAndSettle();
    expect(board.painter(t).origin.dx, closeTo(camera.dx, .001));
    expect(board.painter(t).origin.dy, closeTo(camera.dy, .001));
    expect(board.painter(t).scale, closeTo(scale, 1e-10));
    expect(board.painter(t).model.toJson(), before);
    expect(
        notes.textView(t).annotations.items.values.single.position.x, -1100000);
  });
  testWidgets('Empty double tap is a no-op; text tapping opens edit, not fit',
      (t) async {
    await board.open(t);
    final camera = board.painter(t).origin, scale = board.painter(t).scale;
    final at = t.getTopLeft(board.canvas) + const Offset(100, 100);
    await t.tapAt(at);
    await t.pump(const Duration(milliseconds: 80));
    await t.tapAt(at);
    await t.pumpAndSettle();
    expect(board.painter(t).origin, camera);
    expect(board.painter(t).scale, scale);
    await notes.add(t, 'Room A', const Offset(90, 120));
    final id = notes.textView(t).annotations.items.keys.single;
    await t.tapAt(notes.noteAt(t, id));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('annotationText')), findsOneWidget);
    expect(board.painter(t).scale, scale);
  });
  testWidgets('Text handle resizes only text and is undoable and cancellable',
      (t) async {
    await board.open(t);
    await board.outline(t);
    await notes.add(t, 'Room A', const Offset(90, 110));
    final model = board.painter(t).model.toJson();
    final original = notes.textView(t).annotations.items.values.single;
    final origin = t.getTopLeft(board.canvas);
    var at = origin +
        notes.textView(t).bounds[original.id]!.bottomRight +
        const Offset(5, 5);
    var drag = await t.startGesture(at);
    await drag.moveBy(const Offset(60, 40));
    await t.pump();
    expect(notes.textView(t).annotations.items[original.id]!.sizeMm,
        greaterThan(original.sizeMm));
    await drag.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), model);
    expect(notes.textView(t).annotations.items[original.id]!.position.x,
        original.position.x);
    await notes.undo(t, 'Undo');
    expect(notes.textView(t).annotations.items[original.id]!.sizeMm,
        original.sizeMm);
    await notes.undo(t, 'Redo');
    final resized = notes.textView(t).annotations.items[original.id]!.sizeMm;
    // Tap/edit to reselect without changing content.
    await t.tapAt(notes.noteAt(t, original.id));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    at = origin +
        notes.textView(t).bounds[original.id]!.bottomRight +
        const Offset(5, 5);
    drag = await t.startGesture(at);
    await drag.moveBy(const Offset(-30, -20));
    await t.pump();
    await drag.cancel();
    await t.pumpAndSettle();
    expect(notes.textView(t).annotations.items[original.id]!.sizeMm, resized);
  });
  testWidgets('Preset handle preserves the anchor while resizing dimensions',
      (t) async {
    await board.open(t);
    await shapes.menu(t, 'Shape presets', 'Rectangle');
    await t.tap(find.text('Preview'));
    await t.pumpAndSettle();
    final v = board.painter(t),
        anchor = v.preview.first,
        handle = v.presetHandle!;
    final drag =
        await t.startGesture(t.getTopLeft(board.canvas) + v.screen(handle));
    await drag.moveBy(const Offset(30, 20));
    await t.pump();
    final next = board.painter(t).preview;
    expect(next.first.x, anchor.x);
    expect(next.first.y, anchor.y);
    expect((next[1] - next[0]).length, closeTo(2300, .001));
    expect((next[2] - next[1]).length, closeTo(1700, .001));
    await drag.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.walls, isEmpty);
  });
  testWidgets('A second finger cancels text resizing and never resumes it',
      (t) async {
    await board.open(t);
    await board.outline(t);
    await notes.add(t, 'Room A', const Offset(90, 110));
    final model = board.painter(t).model.toJson();
    final original = notes.textView(t).annotations.copy();
    final note = original.items.values.single;
    final origin = t.getTopLeft(board.canvas);
    final at = origin +
        notes.textView(t).bounds[note.id]!.bottomRight +
        const Offset(5, 5);
    final a = await t.startGesture(at, pointer: 1);
    await a.moveBy(const Offset(30, 20));
    await t.pump();
    expect(notes.textView(t).annotations.items[note.id]!.sizeMm,
        greaterThan(note.sizeMm));
    final b = await t.startGesture(origin + const Offset(50, 280), pointer: 2);
    await t.pump();
    expect(notes.textView(t).annotations.sameAs(original), isTrue);
    await b.moveBy(const Offset(-20, 20));
    await t.pump();
    await b.up();
    await a.moveBy(const Offset(30, 10));
    await t.pump();
    await a.up();
    await t.pumpAndSettle();
    expect(notes.textView(t).annotations.sameAs(original), isTrue);
    expect(board.painter(t).model.toJson(), model);
  });
  testWidgets('Fit text-only long multiline annotations without clipping',
      (t) async {
    await board.open(t);
    await notes.add(t, List.filled(30, 'Construction notes').join('\n'),
        const Offset(20, 80));
    final original = notes.textView(t).annotations.copy();
    await fit(t);
    final rect = notes.textView(t).bounds.values.single;
    final size = t.getSize(board.canvas);
    expect(rect.left, greaterThanOrEqualTo(20));
    expect(rect.top, greaterThanOrEqualTo(20));
    expect(rect.right, lessThanOrEqualTo(size.width - 20));
    expect(rect.bottom, lessThanOrEqualTo(size.height - 20));
    expect(notes.textView(t).annotations.sameAs(original), isTrue);
    expect(board.painter(t).model.walls, isEmpty);
  });
  testWidgets('Pinching a restored sketch preserves its preview and redo',
      (t) async {
    await board.open(t);
    await strokes.stroke(
        t,
        const [
          Offset(60, 60),
          Offset(260, 62),
          Offset(258, 258),
          Offset(58, 260),
          Offset(60, 60)
        ],
        finish: false);
    for (final label in ['Yes, Straighten', 'Accept refinement']) {
      await t.ensureVisible(find.text(label));
      await t.tap(find.text(label));
      await t.pumpAndSettle();
    }
    await notes.undo(t, 'Undo');
    final original = board.painter(t).preview;
    final origin = t.getTopLeft(board.canvas);
    final a = await t.startGesture(origin + const Offset(80, 300), pointer: 1);
    final b = await t.startGesture(origin + const Offset(240, 300), pointer: 2);
    await a.moveBy(const Offset(-20, 0));
    await b.moveBy(const Offset(20, 0));
    await t.pump();
    await a.up();
    await b.up();
    await t.pumpAndSettle();
    expect(board.painter(t).preview, original);
    await notes.undo(t, 'Redo');
    expect(board.painter(t).model.walls.length, 4);
  });
}
