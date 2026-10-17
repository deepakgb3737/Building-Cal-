import 'drawing_point.dart';

enum WallRelationKind { rightAngle, parallel, equalLength }

extension RelationLabel on WallRelationKind {
  String get label => switch (this) {
        WallRelationKind.rightAngle => 'Right angle',
        WallRelationKind.parallel => 'Parallel',
        WallRelationKind.equalLength => 'Equal length',
      };
}

class WallRelation {
  const WallRelation(this.id, this.kind, this.first, this.second);
  final int id;
  final WallRelationKind kind;
  final List<int> first, second;
  bool touches(Set<int> ids) => [...first, ...second].any(ids.contains);
  WallRelation remap(Map<int, List<int>> replacements) =>
      WallRelation(id, kind, [
        for (final id in first) ...replacements[id] ?? [id]
      ], [
        for (final id in second) ...replacements[id] ?? [id]
      ]);
  String get signature =>
      '$id:${kind.name}:${first.join(',')}:${second.join(',')}';
}

bool parallelVectors(DrawingPoint a, DrawingPoint b) =>
    a.cross(b).abs() / (a.length * b.length) <= 1e-6;
