import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_history.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_annotations.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/floor_document.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/sketch_refinement.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/document_repository.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/drawing_painter.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';
import 'drawing_screen_test.dart' as board;
import 'natural_drawing_test.dart' show stroke;
import 'advanced_interaction_test.dart' show selectWall;
import 'document_test_support.dart' show TestDocumentStorage;
import 'accessible_lock_test.dart' show press;
import 'annotation_interaction_test.dart' show undo;

const p = DrawingPoint.new;
Future<void> wallType(WidgetTester t, String label) async {
  await board.expandTools(t);
  await t.tap(find.byTooltip('Drawing assistance'));
  await t.pumpAndSettle();
  final item = find.widgetWithText(CheckedPopupMenuItem<String>, label);
  await t.ensureVisible(item);
  await t.pumpAndSettle();
  await t.tap(item);
  await t.pumpAndSettle();
}

void main() {
  test('Saving and reopening proposed complex outlines retains mixed types',
      () async {
    for (final points in [
      [
        p(0, 0),
        p(3000, 0),
        p(3000, 1000),
        p(1000, 1000),
        p(1000, 3000),
        p(0, 3000),
        p(0, 0)
      ],
      [p(0, 3000), p(0, 0), p(3000, 0), p(3000, 3000)],
      [
        p(0, 0),
        p(1000, 0),
        p(1000, 2000),
        p(2000, 2000),
        p(2000, 0),
        p(3000, 0),
        p(3000, 3000),
        p(0, 3000),
        p(0, 0)
      ],
    ]) {
      final model = WallNetwork()..addPolyline(points, dashed: true);
      model.addPolyline([p(5000, 0), p(6000, 500)]);
      final storage = TestDocumentStorage();
      final repo = DocumentRepository(storage);
      final entry = await repo.save(
          FloorDocument(model, DrawingAnnotations(), const DocumentSettings()),
          'Proposed');
      final loaded = (await DocumentRepository(storage).open(entry.id)).$2;
      expect(loaded.walls.toJson(), model.toJson());
      expect(loaded.walls.walls.values.last.dashed, isFalse);
      expect(storage.files, hasLength(1));
    }
  });
  test(
      'Moving unlike walls onto each other explains the style conflict atomically',
      () {
    final model = WallNetwork()
      ..addPolyline([p(0, 0), p(2000, 0)], dashed: true)
      ..addPolyline([p(0, 1000), p(2000, 1000)]);
    final before = model.toJson();
    expect(() => model.moveWall(model.walls.keys.last, p(0, -1000), join: true),
        throwsA(isA<DrawingConflict>()));
    expect(model.toJson(), before);
  });
  test('Dashed insertion splits both types without changing neighbours', () {
    final model = WallNetwork()..addPolyline([p(0, 0), p(3000, 0)]);
    model.addPolyline([p(1500, -1000), p(1500, 1000)], dashed: true);
    expect(model.walls.length, 4);
    expect(model.corners.length, 5);
    expect(model.walls.values.where((w) => w.dashed).length, 2);
    expect(
        model.walls.values
            .where((w) => !w.dashed)
            .map((w) => model.length(w.id))
            .reduce((a, b) => a + b),
        3000);
    final before = model.toJson();
    model.addPolyline([p(0, 0), p(3000, 0)], dashed: true);
    expect(model.toJson(), before,
        reason: 'Retracing does not restyle existing walls');
    expect(WallNetwork.fromJson(model.toJson()).toJson(), before);
  });
  test(
      'Move, corner edit, exact resize, lock, split and copy preserve dashed type',
      () {
    final model = WallNetwork()
      ..addPolyline([p(0, 0), p(3000, 0)], dashed: true);
    final id = model.walls.keys.single;
    model.moveWall(id, p(100, 200));
    model.moveCorners({model.walls[id]!.end: p(3100, 300)});
    model.setRoomWallLength(id, 3200);
    expect(model.walls[id]!.dashed, isTrue);
    model.lockLength(id);
    expect(model.walls[id]!.dashed, isTrue);
    model.splitWall(id, 1600);
    expect(model.walls.values.every((w) => w.dashed), isTrue);
    for (final edge in model.walls.values.toList()) {
      model.unlock(edge.id);
    }
    expect(model.walls.values.every((w) => w.dashed), isTrue);
    model.duplicateGroup(model.walls.keys.toSet(), {}, p(0, 2000));
    expect(model.walls.values.every((w) => w.dashed), isTrue);
    expect(() => WallNetwork.fromJson(model.toJson()), returnsNormally);
  });
  test('Conversion changes style only, preserves locks, and is undoable', () {
    final model = WallNetwork()
      ..addPolyline([p(0, 0), p(2000, 0), p(2000, 2000)]);
    final id = model.walls.keys.first;
    model.lockLength(id);
    final corners = Map.of(model.corners),
        ids = model.walls.keys.toList(),
        length = model.length(id);
    final history = DrawingHistory()..commit(model);
    model.setDashed(id, true);
    history.commit(model);
    expect(model.corners, corners);
    expect(model.walls.keys, ids);
    expect(model.length(id), length);
    expect(model.isFixed(id), isTrue);
    expect(model.walls.values.last.dashed, isFalse);
    expect(history.undo().walls[id]!.dashed, isFalse);
    expect(history.redo().walls[id]!.dashed, isTrue);
  });
  test('Old drawings load solid and new documents round trip both styles', () {
    final model = WallNetwork()..addPolyline([p(0, 0), p(2000, 0)]);
    final legacy = jsonDecode(jsonEncode(model.toJson()));
    expect((legacy['walls'] as List).single.length, 4);
    expect(WallNetwork.fromJson(legacy).walls.values.single.dashed, isFalse);
    model.setDashed(model.walls.keys.single, true);
    final doc =
        FloorDocument(model, DrawingAnnotations(), const DocumentSettings());
    final loaded = FloorDocument.fromJson(jsonDecode(jsonEncode(doc.toJson())));
    expect(loaded.toJson(), doc.toJson());
    legacy['walls'][0].add('invalid');
    expect(() => WallNetwork.fromJson(legacy), throwsFormatException);
  });
  test('Joining and straightening cannot implicitly restyle a mixed chain', () {
    final model = WallNetwork()
      ..addPolyline([p(0, 0), p(1000, 0), p(2000, 0)], dashed: true);
    final corner = model.walls.values.first.end;
    model.setDashed(model.walls.keys.last, false);
    final before = model.toJson();
    expect(() => model.joinAtCorner(corner), throwsA(isA<DrawingConflict>()));
    expect(model.toJson(), before);
    expect(
        () => SketchRefinement.straightenChain(model, model.walls.keys.first,
            tolerance: 30),
        throwsA(isA<DrawingConflict>()));
    model.setDashed(model.walls.keys.last, true);
    final result = SketchRefinement.straightenChain(
            model, model.walls.keys.first,
            tolerance: 30)
        .$1;
    expect(result.walls.values.single.dashed, isTrue);
    model.joinAtCorner(corner);
    expect(model.walls.values.single.dashed, isTrue);
  });
  test('Draft history retains dashed intent after review undo/redo', () {
    final history = DrawingHistory();
    history.commit(WallNetwork(),
        sketch: SketchRefinement(
            [p(0, 0), p(2000, 0)], [p(0, 0), p(2000, 0)], null,
            dashed: true));
    expect(history.sketch!.dashed, isTrue);
    history.undo();
    history.redo();
    expect(history.sketch!.dashed, isTrue);
  });
  for (final scale in [.05, .1, .5]) {
    test('Dash spacing is screen sized at zoom $scale, including locked red',
        () async {
      final model = WallNetwork()
        ..addPolyline([p(0, 0), p(6000, 0)], dashed: true);
      model.lockLength(model.walls.keys.single);
      final recorder = ui.PictureRecorder();
      DrawingPainter(
          model: model,
          origin: const Offset(40, 120),
          scale: scale,
          unit: DrawingUnit.mm,
          preview: []).paint(Canvas(recorder), const Size(320, 400));
      final picture = recorder.endRecording(),
          image = await picture.toImage(320, 400);
      final bytes =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final red = AppColors.drawingLockedWall.toARGB32();
      int pixel(int x) =>
          (bytes.getUint8((120 * 320 + x) * 4) << 16) |
          (bytes.getUint8((120 * 320 + x) * 4 + 1) << 8) |
          bytes.getUint8((120 * 320 + x) * 4 + 2);
      expect(pixel(57), red & 0xffffff);
      expect(pixel(65), isNot(red & 0xffffff));
      image.dispose();
      picture.dispose();
    });
  }
  testWidgets('Draw dashed, convert only selected wall, Undo, resize and lock',
      (t) async {
    await board.open(t);
    await wallType(t, 'Dashed wall');
    expect(find.widgetWithText(ChoiceChip, 'Dashed'), findsOneWidget);
    await board.collapseTools(t);
    await stroke(t, [const Offset(60, 100), const Offset(240, 100)]);
    final id = board.painter(t).model.walls.keys.single;
    expect(board.painter(t).model.walls[id]!.dashed, isTrue);
    await selectWall(t, id);
    final before = board.painter(t).model.toJson();
    await board.moreWallOptions(t);
    await press(t, 'Make normal');
    expect(board.painter(t).model.walls[id]!.dashed, isFalse);
    await undo(t, 'Undo');
    expect(board.painter(t).model.toJson(), before);
    await undo(t, 'Redo');
    expect(board.painter(t).model.walls[id]!.dashed, isFalse);
    await selectWall(t, id);
    await board.moreWallOptions(t);
    await press(t, 'Make dashed');
    expect(board.painter(t).model.toJson(), before);
    await selectWall(t, id);
    await press(t, 'Lock length');
    expect(board.painter(t).model.walls[id]!.dashed, isTrue);
    await press(t, 'Unlock length');
    await press(t, 'Enter length');
    await t.enterText(find.byType(TextFormField), '2.1');
    await press(t, 'Apply');
    expect(board.painter(t).model.length(id), closeTo(2100, .001));
    expect(board.painter(t).model.walls[id]!.dashed, isTrue);
    await wallType(t, 'Normal wall');
    await board.collapseTools(t);
    await stroke(t, [const Offset(60, 240), const Offset(240, 240)]);
    expect(board.painter(t).model.walls.values.last.dashed, isFalse);
    expect(board.painter(t).model.walls[id]!.dashed, isTrue);
    expect(t.takeException(), isNull);
  });
}
