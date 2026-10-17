import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_annotations.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_history.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/sketch_refinement.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';

void main() {
  test('Undo restores raw review separately from exact connected geometry', () {
    final base = WallNetwork()
      ..addPolyline([const DrawingPoint(0, 0), const DrawingPoint(4000, 0)]);
    base.setLength(base.walls.keys.single, 4000, lock: true);
    final notes = DrawingAnnotations()
      ..add('Keep note', const DrawingPoint(0, 500));
    final sketch = SketchRefinement.fromStroke([
      const DrawingPoint(2000, 0),
      const DrawingPoint(2000, 1000),
      const DrawingPoint(3000, 1010)
    ], tolerance: 30, recognize: false);
    final refined = base.copy()..addPolyline(sketch.refined);
    final history = DrawingHistory()..reset(base, annotations: notes);
    final savedRevision = history.revision;
    history.commit(base, sketch: sketch);
    final draftRevision = history.revision;
    history.commit(refined);
    final cleanRevision = history.revision;
    final restored = history.undo();
    expect(restored.toJson(), base.toJson());
    expect(history.sketch!.original, sketch.original);
    expect(history.annotations.items.values.single.text, 'Keep note');
    expect(history.revision, draftRevision);
    history.sketch!.original.clear();
    expect(history.sketch!.original, isNotEmpty);
    final redo = history.redo();
    expect(redo.toJson(), refined.toJson());
    expect(history.hasSketch, isFalse);
    expect(history.revision, cleanRevision);
    final fixed = redo.walls.keys.where(redo.isFixed);
    expect(fixed.map(redo.length).reduce((a, b) => a + b), 4000);
    final junction = redo.nearestCorner(const DrawingPoint(2000, 0), .001)!;
    expect(
        redo.walls.values
            .where((w) => w.start == junction || w.end == junction)
            .length,
        3);
    history.undo();
    expect(history.undo().toJson(), base.toJson());
    expect(history.hasSketch, isFalse);
    expect(history.revision, savedRevision);
  });
  test('Reaccepting a restored preview deduplicates it; reset clears drafts',
      () {
    final base = WallNetwork(), notes = DrawingAnnotations();
    final draft = SketchRefinement.fromStroke([
      const DrawingPoint(0, 0),
      const DrawingPoint(1000, 3),
      const DrawingPoint(2000, 0)
    ], tolerance: 30);
    final clean = base.copy()..addPolyline(draft.refined);
    final history = DrawingHistory();
    history.commit(base, sketch: draft);
    final revision = history.revision;
    history.commit(clean);
    history.undo();
    history.commit(base, sketch: history.sketch);
    expect(history.revision, revision);
    history.commit(clean);
    history.undo();
    expect(history.hasSketch, isTrue);
    expect(history.undo().walls, isEmpty);
    expect(history.canUndo, isFalse);
    history.reset(clean, annotations: notes);
    expect(history.hasSketch, isFalse);
    expect(history.canRedo, isFalse);
  });
}
