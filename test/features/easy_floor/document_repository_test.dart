import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/document_files_io.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/document_repository.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_annotations.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_history.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_shapes.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/floor_document.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'document_test_support.dart';

void main() {
  test(
      'Rotated L/U/T shapes, diagonals and shared junctions round-trip unchanged',
      () {
    for (final kind
        in ShapePreset.values.where((k) => k != ShapePreset.polygon)) {
      for (final angle in [0.0, 17.0, 45.0, 91.0]) {
        final model = WallNetwork()
          ..addPolyline(ShapeSpec(kind, 2438.23, 3200.17, angle)
              .points(const DrawingPoint(-780.3, 1234.567)));
        final original = jsonEncode(model.toJson());
        var restored = model;
        for (var i = 0; i < 3; i++) {
          restored =
              WallNetwork.fromJson(jsonDecode(jsonEncode(restored.toJson())));
        }
        expect(jsonEncode(restored.toJson()), original,
            reason: '${kind.label} at $angle degrees');
      }
    }
    final grid = WallNetwork();
    for (var i = 0; i < 4; i++) {
      final n = i * 1300.25;
      grid.addPolyline([DrawingPoint(n, 0), DrawingPoint(n, 3900.75)]);
      grid.addPolyline([DrawingPoint(0, n), DrawingPoint(3900.75, n)]);
    }
    expect(WallNetwork.fromJson(jsonDecode(jsonEncode(grid.toJson()))).toJson(),
        grid.toJson());
  });
  test('Every metric and imperial unit survives document serialization', () {
    final fixture = documentFixture();
    for (final unit in DrawingUnit.values) {
      final doc = FloorDocument(
          fixture.walls, fixture.annotations, DocumentSettings(unit: unit));
      final restored =
          FloorDocument.fromJson(jsonDecode(jsonEncode(doc.toJson())));
      expect(restored.settings.unit, unit);
      expect(restored.walls.toJson(), fixture.walls.toJson());
    }
  });
  test('Oversized UTF-8 document is rejected before replacing the saved file',
      () async {
    final storage = TestDocumentStorage();
    final repository = DocumentRepository(storage), doc = documentFixture();
    final entry = await repository.save(doc, 'Keep original');
    final before = storage.files[entry.id];
    final content = List.filled(2000, '\u4e2d').join();
    for (var i = 0; i < 2800; i++) {
      doc.annotations.add(content, DrawingPoint(i.toDouble(), 0));
    }
    await expectLater(
        repository.save(doc, entry.name, id: entry.id), throwsFormatException);
    expect(storage.files[entry.id], before);
  });
  test(
      'Complete round trip preserves connected geometry, measured spans, relations, text and settings',
      () async {
    final storage = TestDocumentStorage();
    final repo = DocumentRepository(storage);
    final original = documentFixture(),
        first = await repo.save(documentFixture(), 'House Plan');
    final reopened = (await repo.open(first.id)).$2;
    expect(jsonEncode(reopened.toJson()), jsonEncode(original.toJson()));
    final history = DrawingHistory()
      ..reset(reopened.walls, annotations: reopened.annotations);
    expect(history.canUndo, isFalse);
    final id = reopened.annotations.items.keys.first;
    reopened.annotations
        .update(reopened.annotations.items[id]!.copyWith(text: 'Updated'));
    history.commit(reopened.walls, annotations: reopened.annotations);
    history.undo();
    expect(history.annotations.items[id]!.text, 'Kitchen\nNotes');
    history.redo();
    expect(history.annotations.items[id]!.text, 'Updated');
    expect(storage.files.length, 1);
  });
  test(
      'Save updates one document; Save As and rename preserve independent copies',
      () async {
    final repo = DocumentRepository(TestDocumentStorage()),
        original = documentFixture();
    final a = await repo.save(original, '  House   Plan  ');
    expect(a.name, 'House Plan');
    final copy = await repo.save(original, 'Ground Floor');
    original.annotations.add('Only A', const DrawingPoint(9000, 500));
    final updated = await repo.save(original, a.name, id: a.id);
    expect(updated.id, a.id);
    expect((await repo.open(a.id)).$2.annotations.items.length, 3);
    expect((await repo.open(copy.id)).$2.annotations.items.length, 2);
    expect((await repo.list()).length, 2);
    await expectLater(repo.save(original, 'house plan'), throwsFormatException);
    await expectLater(
        repo.rename(copy.id, 'HOUSE PLAN'), throwsFormatException);
    await repo.rename(copy.id, 'Site Layout');
    expect((await repo.open(copy.id)).$1.name, 'Site Layout');
    await repo.delete(copy.id);
    expect((await repo.list()).single.id, a.id);
    expect((await repo.open(a.id)).$2.annotations.items.length, 3);
  });
  test('Failed and concurrent saves preserve the last complete persisted copy',
      () async {
    final storage = TestDocumentStorage(), doc = documentFixture();
    final repo = DocumentRepository(storage),
        a = await DocumentRepository(storage).save(doc, 'A');
    final before = storage.files[a.id];
    storage.failWrite = true;
    doc.annotations.add('Unsaved note', const DrawingPoint(0, 0));
    await expectLater(repo.save(doc, 'A', id: a.id), throwsStateError);
    expect(storage.files[a.id], before);
    expect(doc.annotations.items.length, 3);
    storage.failWrite = false;
    storage.gate = Completer<void>();
    final pending = repo.save(doc, 'A', id: a.id);
    await expectLater(repo.save(doc, 'B'), throwsStateError);
    storage.gate!.complete();
    await pending;
    expect((await repo.open(a.id)).$2.annotations.items.length, 3);
  });
  test(
      'Invalid files, versions, IDs and geometry are rejected without modifying valid data',
      () async {
    final storage = TestDocumentStorage();
    final repo = DocumentRepository(storage);
    final a = await repo.save(documentFixture(), 'A');
    final valid = (repo.storage as TestDocumentStorage).files[a.id]!;
    final data = jsonDecode(valid) as Map<String, dynamic>;
    data['data']['walls']['dimensions'][0][1] = [999999];
    storage.files['bad'] = jsonEncode({...data, 'id': 'bad'});
    await expectLater(repo.open('bad'), throwsFormatException);
    storage.files['broken'] = '{';
    expect(
        (await repo.list()).any((e) => e.id == 'broken' && e.invalid), isTrue);
    expect((await repo.open(a.id)).$1.name, 'A');
    await expectLater(repo.open('../escape'), throwsFormatException);
    await expectLater(repo.save(documentFixture(), ' '), throwsFormatException);
    expect(storage.files[a.id], valid);
    final unknown = jsonDecode(valid) as Map<String, dynamic>;
    unknown['version'] = 999;
    storage.files[a.id] = jsonEncode(unknown);
    await expectLater(repo.open(a.id), throwsFormatException);
  });
  test(
      'File storage survives repository recreation and ignores interrupted pending writes',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('easyfloor-doc-test-');
    addTearDown(() => directory.delete(recursive: true));
    final repo = DocumentRepository(FileDocumentStorage(directory: directory));
    final entry = await repo.save(documentFixture(), 'Persisted');
    await File('${directory.path}/${entry.id}.pending')
        .writeAsString('{incomplete');
    final reopened =
        DocumentRepository(FileDocumentStorage(directory: directory));
    expect((await reopened.open(entry.id)).$1.name, 'Persisted');
    await reopened.save(documentFixture(), 'Persisted', id: entry.id);
    expect(
        await File('${directory.path}/${entry.id}.pending').exists(), isFalse);
    expect((await reopened.list()).length, 1);
    await expectLater(
        FileDocumentStorage(directory: directory).write('../escape', 'x'),
        throwsFormatException);
  });
  test('Dirty revisions return to saved state on undo and reset per document',
      () {
    final doc = documentFixture(), history = DrawingHistory();
    history.reset(doc.walls, annotations: doc.annotations);
    final saved = history.revision;
    doc.annotations.add('Changed', const DrawingPoint(0, 0));
    history.commit(doc.walls, annotations: doc.annotations);
    expect(history.revision, isNot(saved));
    history.undo();
    expect(history.revision, saved);
    history.redo();
    expect(history.revision, isNot(saved));
    history.reset(documentFixture().walls, annotations: DrawingAnnotations());
    expect(history.canUndo, isFalse);
    expect(history.canRedo, isFalse);
    expect(history.revision, isNot(saved));
  });
}
