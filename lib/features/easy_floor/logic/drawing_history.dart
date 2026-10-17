import 'wall_network.dart';
import 'drawing_annotations.dart';
import 'sketch_refinement.dart';

class DrawingHistory {
  final List<(WallNetwork, DrawingAnnotations, SketchRefinement?)> _states = [
    (WallNetwork(), DrawingAnnotations(), null)
  ];
  int _index = 0;
  int _nextRevision = 1;
  final List<int> _revisions = [0];
  int get revision => _revisions[_index];
  void reset(WallNetwork model, {required DrawingAnnotations annotations}) {
    _states
      ..clear()
      ..add((model.copy(), annotations.copy(), null));
    _revisions
      ..clear()
      ..add(_nextRevision++);
    _index = 0;
  }

  bool get canUndo => _index > 0;
  bool get canRedo => _index < _states.length - 1;
  WallNetwork undo() => _states[--_index].$1.copy();
  WallNetwork redo() => _states[++_index].$1.copy();
  DrawingAnnotations get annotations => _states[_index].$2.copy();
  bool get hasSketch => _states[_index].$3 != null;
  SketchRefinement? get sketch {
    final s = _states[_index].$3;
    return s == null
        ? null
        : SketchRefinement(List.of(s.original), List.of(s.refined), s.shape,
            dashed: s.dashed);
  }

  void commit(WallNetwork model,
      {DrawingAnnotations? annotations, SketchRefinement? sketch}) {
    String signature(WallNetwork m) =>
        '${m.corners.entries.map((e) => '${e.key}:${e.value.x},${e.value.y}').join(';')}|${m.walls.values.map((e) => '${e.id}:${e.start},${e.end},${e.fixedLength},${e.dashed}').join(';')}|${m.constraintSignature}';
    final notes = annotations ?? _states[_index].$2;
    String draftSignature(SketchRefinement? s) => s == null
        ? ''
        : '${s.shape}|${s.dashed}|${[
            s.original,
            s.refined
          ].map((points) => points.map((p) => '${p.x},${p.y}').join(';')).join('|')}';
    if (signature(_states[_index].$1) == signature(model) &&
        notes.sameAs(_states[_index].$2) &&
        draftSignature(_states[_index].$3) == draftSignature(sketch)) {
      return;
    }
    _states.removeRange(_index + 1, _states.length);
    _revisions.removeRange(_index + 1, _revisions.length);
    _states.add((
      model.copy(),
      notes.copy(),
      sketch == null
          ? null
          : SketchRefinement(
              List.of(sketch.original), List.of(sketch.refined), sketch.shape,
              dashed: sketch.dashed)
    ));
    _revisions.add(_nextRevision++);
    if (_states.length > 51) {
      _states.removeAt(0);
      _revisions.removeAt(0);
    }
    _index = _states.length - 1;
  }
}
