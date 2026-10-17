import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_annotations.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_history.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/annotation_painter.dart';

void main() {
  test('Independent text moves and duplicates retain every formatting property',
      () {
    final layer = DrawingAnnotations();
    final a = layer.add('Room A\nSite note', const DrawingPoint(-1000, 200),
        sizeMm: 240,
        ink: AnnotationInk.red,
        alignment: AnnotationAlignment.right);
    final b = layer.add('B', const DrawingPoint(4000, -500));
    for (var i = 0; i < 30; i++) {
      layer.move({a, b}, const DrawingPoint(10, -20));
    }
    final note = layer.items[a]!;
    expect(note.position.x, -700);
    expect(note.position.y, -400);
    final copies = layer.duplicate({a, b}, const DrawingPoint(200, 200));
    final copy = layer.items[copies.first]!;
    expect(copy.text, note.text);
    expect(copy.sizeMm, 240);
    expect(copy.ink, AnnotationInk.red);
    expect(copy.alignment, AnnotationAlignment.right);
    layer.delete(copies);
    expect(layer.items.length, 2);
    expect(() => layer.items.clear(), throwsUnsupportedError);
  });
  test('Validation and group failures are atomic', () {
    final layer = DrawingAnnotations();
    for (final text in ['', '  ', 'a' * 2001]) {
      expect(
          () => layer.add(text, const DrawingPoint(0, 0)), throwsArgumentError);
    }
    final a = layer.add('A', const DrawingPoint(0, 0));
    final b = layer.add('B', const DrawingPoint(99999999, 0));
    final before = layer.copy();
    expect(() => layer.move({a, b}, const DrawingPoint(100, 0)),
        throwsArgumentError);
    expect(layer.sameAs(before), isTrue);
    expect(() => layer.duplicate({a, b}, const DrawingPoint(100, 0)),
        throwsArgumentError);
    expect(layer.sameAs(before), isTrue);
    expect(() => layer.delete({a, 999}), throwsArgumentError);
    for (final size in [double.nan, 119.0, 481.0]) {
      expect(() => layer.update(layer.items[a]!.copyWith(sizeMm: size)),
          throwsArgumentError);
    }
    expect(layer.sameAs(before), isTrue);
  });
  test('Wall and text operations share ordered history without mixing geometry',
      () {
    final history = DrawingHistory(),
        walls = WallNetwork(),
        notes = DrawingAnnotations();
    walls.addPolyline(const [DrawingPoint(0, 0), DrawingPoint(2000, 0)]);
    history.commit(walls);
    final id = notes.add('Kitchen', const DrawingPoint(500, 500));
    history.commit(walls, annotations: notes);
    walls.setLength(walls.walls.keys.single, 3000, lock: false);
    history.commit(walls);
    expect(history.annotations.items[id]!.text, 'Kitchen');
    expect(history.undo().length(walls.walls.keys.single), 2000);
    expect(history.annotations.items.length, 1);
    history.undo();
    expect(history.annotations.items, isEmpty);
    history.redo();
    expect(history.annotations.items[id]!.position.x, 500);
    final restored = history.annotations;
    restored.delete({id});
    expect(history.annotations.items.length, 1);
    history.undo();
    history.commit(walls);
    expect(history.canRedo, isFalse);
    expect(history.annotations.items, isEmpty);
  });
  test('Zoom scales annotation display proportionally, never stored formatting',
      () {
    expect(annotationFontPixels(180, .1), 18);
    expect(annotationFontPixels(180, .2), 36);
    expect(annotationFontPixels(120, .005), .6);
    expect(annotationFontPixels(480, 2), 960);
  });
  test('Zoom preserves note wrapping and exposes accessible text targets', () {
    final layer = DrawingAnnotations();
    final id = layer.add(
        'Construction notes over several lines with a deliberate\nline break',
        const DrawingPoint(0, 0));
    double? ratio;
    for (final scale in [.005, .1, .2, 2.0]) {
      final recorder = ui.PictureRecorder(), bounds = <int, Rect>{};
      final painter = AnnotationPainter(
          annotations: layer,
          origin: const Offset(20, 20),
          scale: scale,
          bounds: bounds,
          onEdit: (_) {});
      painter.paint(Canvas(recorder), const Size(800, 800));
      recorder.endRecording().dispose();
      final rect = bounds[id]!;
      ratio ??= rect.width / rect.height;
      expect(rect.width / rect.height, closeTo(ratio, 1e-8));
      final semantics = painter.semanticsBuilder(const Size(800, 800)).single;
      expect(semantics.properties.label, layer.items[id]!.text);
      expect(semantics.properties.onTap, isNotNull);
    }
    expect(layer.items[id]!.sizeMm, 180);
  });
}
