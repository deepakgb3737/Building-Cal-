import 'dart:math' as math;
import 'dart:convert';
import 'document_json.dart';
import 'drawing_point.dart';
import 'wall_relation.dart';
import 'wall_resize.dart';

class DrawingConflict implements Exception {
  const DrawingConflict(this.message);
  final String message;
  @override
  String toString() => message;
}

class DrawingWall {
  const DrawingWall(this.id, this.start, this.end,
      {this.fixedLength, this.dashed = false});
  final int id;
  final int start;
  final int end;
  final double? fixedLength;
  final bool dashed;
}

class WallNetwork {
  final Map<int, DrawingPoint> corners = {};
  final Map<int, DrawingWall> walls = {};
  final Map<int, (List<int>, double)> _dimensions = {};
  final Map<int, WallRelation> _relations = {};
  Iterable<WallRelation> get relations => _relations.values;
  int _nextRelation = 1;
  bool calibrated = false;
  int _nextCorner = 1;
  int _nextWall = 1;

  Map<String, Object?> toJson() => {
        'corners': [
          for (final e in corners.entries) [e.key, e.value.x, e.value.y]
        ],
        'walls': [
          for (final w in walls.values)
            [w.id, w.start, w.end, w.fixedLength, if (w.dashed) true]
        ],
        'dimensions': [
          for (final e in _dimensions.entries) [e.key, e.value.$1, e.value.$2]
        ],
        'relations': [
          for (final r in _relations.values)
            [r.id, r.kind.name, r.first, r.second]
        ],
        'calibrated': calibrated,
      };

  static WallNetwork fromJson(Object? value) {
    final data = jsonObject(value), model = WallNetwork();
    for (final row in jsonArray(data['corners'])) {
      final r = jsonArray(row, max: 3);
      if (r.length != 3) throw const FormatException('Invalid corner.');
      final id = jsonInteger(r[0]);
      if (model.corners.containsKey(id)) {
        throw const FormatException('Duplicate corner.');
      }
      model.corners[id] = DrawingPoint(jsonNumber(r[1]), jsonNumber(r[2]));
      model._nextCorner = math.max(model._nextCorner, id + 1);
    }
    for (final row in jsonArray(data['walls'])) {
      final r = jsonArray(row, max: 5);
      if (r.length != 4 && r.length != 5) {
        throw const FormatException('Invalid wall.');
      }
      final id = jsonInteger(r[0]);
      if (model.walls.containsKey(id)) {
        throw const FormatException('Duplicate wall.');
      }
      final fixed = r[3] == null ? null : jsonNumber(r[3]);
      if (fixed != null && fixed < 10) {
        throw const FormatException('Invalid fixed length.');
      }
      model.walls[id] = DrawingWall(id, jsonInteger(r[1]), jsonInteger(r[2]),
          fixedLength: fixed,
          dashed: r.length == 5 ? jsonBoolean(r[4]) : false);
      model._nextWall = math.max(model._nextWall, id + 1);
    }
    for (final row in jsonArray(data['dimensions'])) {
      final r = jsonArray(row, max: 3);
      if (r.length != 3) throw const FormatException('Invalid dimension.');
      final id = jsonInteger(r[0], positive: false);
      final ids = jsonArray(r[1]).map((v) => jsonInteger(v)).toList();
      if (ids.isEmpty ||
          ids.toSet().length != ids.length ||
          !ids.every(model.walls.containsKey) ||
          model._dimensions.containsKey(id)) {
        throw const FormatException('Invalid measured span.');
      }
      model._dimensions[id] = (ids, jsonNumber(r[2]));
    }
    for (final row in jsonArray(data['relations'])) {
      final r = jsonArray(row, max: 4);
      if (r.length != 4) throw const FormatException('Invalid relation.');
      final id = jsonInteger(r[0]);
      final first = jsonArray(r[2]).map((v) => jsonInteger(v)).toList();
      final second = jsonArray(r[3]).map((v) => jsonInteger(v)).toList();
      if (first.isEmpty ||
          second.isEmpty ||
          first.toSet().length != first.length ||
          second.toSet().length != second.length ||
          first.any(second.contains) ||
          model._relations.containsKey(id)) {
        throw const FormatException('Invalid geometric relationship.');
      }
      model._relations[id] = WallRelation(
          id, jsonEnum(WallRelationKind.values, r[1]), first, second);
      model._nextRelation = math.max(model._nextRelation, id + 1);
    }
    model.calibrated = jsonBoolean(data['calibrated']);
    model._validate();
    final canonical = model.copy().._connectJunctions();
    canonical._validate();
    if (jsonEncode(model.toJson()) != jsonEncode(canonical.toJson())) {
      throw const FormatException(
          'Disconnected or overlapping wall junctions.');
    }
    return model;
  }

  WallNetwork copy() => WallNetwork()
    ..corners.addAll(corners)
    ..walls.addAll(walls)
    .._dimensions.addAll(_dimensions
        .map((id, value) => MapEntry(id, (List.of(value.$1), value.$2))))
    .._relations.addAll(_relations.map((id, r) => MapEntry(
        id, WallRelation(r.id, r.kind, List.of(r.first), List.of(r.second)))))
    .._nextRelation = _nextRelation
    ..calibrated = calibrated
    .._nextCorner = _nextCorner
    .._nextWall = _nextWall;

  double length(int wallId) {
    final w = walls[wallId]!;
    return (corners[w.end]! - corners[w.start]!).length;
  }

  void setDashed(int id, bool dashed) {
    final wall = walls[id];
    if (wall == null) {
      throw const DrawingConflict('Select an existing wall first.');
    }
    walls[id] = DrawingWall(id, wall.start, wall.end,
        fixedLength: wall.fixedLength, dashed: dashed);
  }

  bool isFixed(int id) =>
      _dimensions.values.any((value) => value.$1.contains(id));
  List<double> fixedSpans(int id) => _dimensions.values
      .where((value) => value.$1.contains(id))
      .map((value) => value.$2)
      .toList();
  String get constraintSignature =>
      '${_dimensions.entries.map((e) => '${e.key}:${e.value.$1.join(',')}:${e.value.$2}').join(';')}|${_relations.values.map((r) => r.signature).join(';')}|calibrated:$calibrated';

  void constrain(WallRelationKind kind, int first, int second) {
    if (first == second ||
        !walls.containsKey(first) ||
        !walls.containsKey(second))
      throw const DrawingConflict('Select two different existing walls.');
    if (kind == WallRelationKind.rightAngle) {
      final a = walls[first]!, b = walls[second]!;
      if (![a.start, a.end].any((n) => n == b.start || n == b.end))
        throw const DrawingConflict(
            'Right-angle constraints require walls sharing a corner.');
    }
    _transaction((next) {
      if (next._relations.values.any((r) =>
          r.kind == kind &&
          r.first.length == 1 &&
          r.second.length == 1 &&
          {r.first.single, r.second.single}.containsAll([first, second])))
        return;
      final id = next._nextRelation++;
      next._relations[id] = WallRelation(id, kind, [first], [second]);
    });
  }

  void removeRelations(Set<int> wallIds) =>
      _relations.removeWhere((_, r) => r.touches(wallIds));

  Set<int> groupNodes(Set<int> wallIds, Set<int> cornerIds) {
    if (!wallIds.every(walls.containsKey) ||
        !cornerIds.every(corners.containsKey))
      throw const DrawingConflict(
          'The selection contains geometry that no longer exists.');
    return {
      ...cornerIds,
      for (final id in wallIds) ...[walls[id]!.start, walls[id]!.end]
    };
  }

  List<(List<int>, double)> _boundedFaces() {
    final neighbours = <int, List<int>>{};
    for (final w in walls.values) {
      neighbours.putIfAbsent(w.start, () => []).add(w.end);
      neighbours.putIfAbsent(w.end, () => []).add(w.start);
    }
    for (final entry in neighbours.entries) {
      final origin = corners[entry.key]!;
      entry.value.sort((a, b) => math
          .atan2(corners[a]!.y - origin.y, corners[a]!.x - origin.x)
          .compareTo(
              math.atan2(corners[b]!.y - origin.y, corners[b]!.x - origin.x)));
    }
    final visited = <(int, int)>{}, faces = <(List<int>, double)>[];
    for (final wall in walls.values) {
      for (final start in [(wall.start, wall.end), (wall.end, wall.start)]) {
        if (visited.contains(start)) continue;
        var edge = start;
        final face = <int>[];
        while (visited.add(edge)) {
          face.add(edge.$1);
          final linked = neighbours[edge.$2]!;
          final reverse = linked.indexOf(edge.$1);
          edge =
              (edge.$2, linked[(reverse + linked.length - 1) % linked.length]);
        }
        var winding = 0.0;
        for (var i = 0; i < face.length; i++) {
          winding +=
              corners[face[i]]!.cross(corners[face[(i + 1) % face.length]]!);
        }
        if (winding > .001) faces.add((face, winding));
      }
    }
    return faces;
  }

  bool _insideFace(DrawingPoint point, List<int> face) {
    var inside = false;
    for (var i = 0, j = face.length - 1; i < face.length; j = i++) {
      final a = corners[face[i]]!, b = corners[face[j]]!;
      if ((a.y > point.y) != (b.y > point.y) &&
          point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// A bounded face selects its whole connected network, never a torn shared wall.
  Set<int> enclosedComponentAt(DrawingPoint point) {
    _checkPoint(point);
    if (nearestWall(point, .001) != null) return {};
    final containing = _boundedFaces()
        .where((face) => _insideFace(point, face.$1))
        .toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
    if (containing.isEmpty) return {};
    final nodes = containing.first.$1.toSet();
    final selected = <int>{};
    final incident = <int, List<DrawingWall>>{};
    for (final wall in walls.values) {
      incident.putIfAbsent(wall.start, () => []).add(wall);
      incident.putIfAbsent(wall.end, () => []).add(wall);
    }
    final pending = nodes.toList();
    for (var i = 0; i < pending.length; i++) {
      for (final wall in incident[pending[i]] ?? <DrawingWall>[]) {
        if (!selected.add(wall.id)) continue;
        for (final id in [wall.start, wall.end]) {
          if (nodes.add(id)) pending.add(id);
        }
      }
    }
    return selected;
  }

  /// Whole-room placement stays independent; use endpoint editing to connect rooms.
  DrawingPoint moveRoom(Set<int> wallIds, DrawingPoint delta,
      {double alignmentRadius = 0}) {
    if (!alignmentRadius.isFinite || alignmentRadius < 0) {
      throw ArgumentError.value(alignmentRadius, 'alignmentRadius');
    }
    if (alignmentRadius > 0) {
      final nodes = groupNodes(wallIds, {});
      var x = delta.x, y = delta.y;
      var bestX = alignmentRadius, bestY = alignmentRadius;
      for (final id in nodes) {
        final moved = corners[id]! + delta;
        for (final entry in corners.entries) {
          if (nodes.contains(entry.key) ||
              (entry.value - moved).length > alignmentRadius * 12) {
            continue;
          }
          final dx = (entry.value.x - moved.x).abs(),
              dy = (entry.value.y - moved.y).abs();
          final offsetX = entry.value.x - corners[id]!.x,
              offsetY = entry.value.y - corners[id]!.y;
          if (dx < bestX || (dx == bestX && offsetX < x)) {
            bestX = dx;
            x = offsetX;
          }
          if (dy < bestY || (dy == bestY && offsetY < y)) {
            bestY = dy;
            y = offsetY;
          }
        }
      }
      final alternatives = [DrawingPoint(x, delta.y), DrawingPoint(delta.x, y)]
        ..sort((a, b) {
          final distance = (a - delta).length.compareTo((b - delta).length);
          return distance != 0 ? distance : b.x.compareTo(a.x);
        });
      for (final aligned in [DrawingPoint(x, y), ...alternatives]) {
        if ((aligned - delta).length <= .001) continue;
        try {
          return moveRoom(wallIds, aligned);
        } on DrawingConflict {
          // Alignment must not prevent a valid independent placement nearby.
        }
      }
    }
    _transaction((next) {
      next.moveGroup(wallIds, {}, delta);
      final nodes = next.groupNodes(wallIds, {});
      final outside =
          next.walls.values.where((w) => !wallIds.contains(w.id)).toList();
      if (outside.isEmpty) return;
      for (final id in wallIds) {
        final wall = next.walls[id]!;
        for (final other in outside) {
          if (_intersections(next.corners[wall.start]!, next.corners[wall.end]!,
                  next.corners[other.start]!, next.corners[other.end]!)
              .isNotEmpty) {
            throw const DrawingConflict(
                'Rooms cannot overlap or merge during a whole-shape move. Leave a gap; use endpoint editing to connect them.');
          }
        }
      }
      final otherNodes = {
        for (final w in outside) w.start,
        for (final w in outside) w.end
      };
      for (final face in next._boundedFaces()) {
        final insideNodes = nodes.contains(face.$1.first) ? otherNodes : nodes;
        if (insideNodes
            .any((id) => next._insideFace(next.corners[id]!, face.$1))) {
          throw const DrawingConflict(
              'That placement would overlap another room. Move the shape to a clear location.');
        }
      }
    });
    return delta;
  }

  Set<int> attachedWalls(Set<int> wallIds, Set<int> cornerIds) {
    final nodes = groupNodes(wallIds, cornerIds);
    return {
      for (final w in walls.values)
        if (!wallIds.contains(w.id) &&
            (nodes.contains(w.start) || nodes.contains(w.end)))
          w.id
    };
  }

  void moveGroup(Set<int> wallIds, Set<int> cornerIds, DrawingPoint delta,
      {bool stretchAttached = false}) {
    _checkPoint(delta);
    final nodes = groupNodes(wallIds, cornerIds);
    if (nodes.isEmpty)
      throw const DrawingConflict('Select walls or corners first.');
    if (!stretchAttached && attachedWalls(wallIds, cornerIds).isNotEmpty)
      throw const DrawingConflict(
          'This group connects to unselected walls. Include them or enable Stretch attached walls.');
    moveCorners({for (final id in nodes) id: corners[id]! + delta});
  }

  Set<int> duplicateGroup(
      Set<int> wallIds, Set<int> cornerIds, DrawingPoint delta) {
    _checkPoint(delta);
    final nodes = groupNodes(wallIds, cornerIds);
    if (wallIds.isEmpty ||
        cornerIds.any((id) =>
            !wallIds.any((w) => walls[w]!.start == id || walls[w]!.end == id)))
      throw const DrawingConflict(
          'Select walls to duplicate; isolated corner copies are not supported.');
    Set<int> result = {};
    _transaction((next) {
      for (final span in next._dimensions.values) {
        if (span.$1.any(wallIds.contains) && !span.$1.every(wallIds.contains))
          throw const DrawingConflict(
              'Include the entire fixed measured span before duplicating.');
      }
      for (final r in next._relations.values) {
        if (r.touches(wallIds) &&
            ![...r.first, ...r.second].every(wallIds.contains))
          throw const DrawingConflict(
              'Include both sides of constrained relationships before duplicating.');
      }
      final original = next.walls.values.toList(),
          nodeMap = <int, int>{},
          wallMap = <int, int>{};
      for (final id in nodes) {
        final p = next.corners[id]! + delta;
        _checkPoint(p);
        if (original.any((w) =>
            (p -
                    projectToSegment(
                        p, next.corners[w.start]!, next.corners[w.end]!))
                .length <
            .001))
          throw const DrawingConflict(
              'The copy is too close to existing geometry. Drag it to a clear location.');
        nodeMap[id] = next._nextCorner++;
        next.corners[nodeMap[id]!] = p;
      }
      for (final id in wallIds) {
        final w = walls[id]!;
        wallMap[id] =
            next._edge(nodeMap[w.start]!, nodeMap[w.end]!, dashed: w.dashed);
        final copy = next.walls[wallMap[id]]!;
        for (final other in original) {
          if (_intersections(next.corners[copy.start]!, next.corners[copy.end]!,
                  next.corners[other.start]!, next.corners[other.end]!)
              .isNotEmpty)
            throw const DrawingConflict(
                'The copy touches, crosses or overlaps existing geometry. Drag it to a clear location.');
        }
      }
      for (final span
          in _dimensions.values.where((v) => v.$1.every(wallIds.contains))) {
        var key = -1;
        while (next._dimensions.containsKey(key)) {
          key--;
        }
        next._dimensions[key] =
            ([for (final id in span.$1) wallMap[id]!], span.$2);
      }
      for (final r in _relations.values
          .where((r) => [...r.first, ...r.second].every(wallIds.contains))) {
        final id = next._nextRelation++;
        next._relations[id] = WallRelation(
            id,
            r.kind,
            [for (final w in r.first) wallMap[w]!],
            [for (final w in r.second) wallMap[w]!]);
      }
      result = wallMap.values.toSet();
    });
    return result;
  }

  void deleteGroup(Set<int> wallIds, Set<int> cornerIds) =>
      _transaction((next) {
        next.groupNodes(wallIds, cornerIds);
        final deleted = {
          ...wallIds,
          for (final w in next.walls.values)
            if (cornerIds.contains(w.start) || cornerIds.contains(w.end)) w.id
        };
        for (final id in deleted) {
          next.deleteWall(id);
        }
      });

  void calibrateFromWall(int id, double knownMm) {
    if (!walls.containsKey(id) ||
        !knownMm.isFinite ||
        knownMm < 10 ||
        knownMm > 10000000)
      throw const DrawingConflict(
          'Select a wall and enter a known length from 10 mm to 10,000 m.');
    final factor = knownMm / length(id), origin = corners[walls[id]!.start]!;
    if (_dimensions.isNotEmpty && (factor - 1).abs() > 1e-9)
      throw const DrawingConflict(
          'Unlock fixed measured spans before calibrating the whole plan.');
    _transaction((next) {
      next.moveCorners({
        for (final e in next.corners.entries)
          e.key: origin + (e.value - origin) * factor
      });
      next.calibrated = true;
    });
  }

  void lockLength(int id) {
    _transaction((next) {
      final wall = next.walls[id];
      if (wall == null)
        throw const DrawingConflict('Select an existing wall first.');
      if (next.isFixed(id)) return;
      final mm = next.length(id);
      next.walls[id] = DrawingWall(id, wall.start, wall.end,
          fixedLength: mm, dashed: wall.dashed);
      next._dimensions[id] = ([id], mm);
    });
  }

  void setGroupLengthLocks(Set<int> ids, {required bool locked}) {
    groupNodes(ids, {});
    _transaction((next) {
      for (final id in ids) {
        if (locked) {
          next.lockLength(id);
        } else {
          next.unlock(id);
        }
      }
    });
  }

  void unlock(int id) {
    _dimensions.removeWhere((_, value) => value.$1.contains(id));
    for (final w in walls.values.toList()) {
      if (!isFixed(w.id) && w.fixedLength != null)
        walls[w.id] = DrawingWall(w.id, w.start, w.end, dashed: w.dashed);
    }
  }

  DrawingPoint snap(DrawingPoint point, double radius, {int? excludeCorner}) {
    var candidate = point;
    var best = radius;
    int? cornerId, wallId;
    final neighbours = {
      for (final w in walls.values)
        if (w.start == excludeCorner)
          w.end
        else if (w.end == excludeCorner)
          w.start
    };
    for (final entry in corners.entries) {
      if (entry.key == excludeCorner || neighbours.contains(entry.key))
        continue;
      final distance = (entry.value - point).length;
      if (distance < best ||
          (cornerId != null && distance == best && entry.key < cornerId)) {
        best = distance;
        candidate = entry.value;
        cornerId = entry.key;
      }
    }
    for (final wall in walls.values) {
      if (wall.start == excludeCorner || wall.end == excludeCorner) continue;
      final projected =
          projectToSegment(point, corners[wall.start]!, corners[wall.end]!);
      if ([wall.start, wall.end].any((id) {
        final gap = (corners[id]! - projected).length;
        return gap > .001 && gap < 10 - 1e-6;
      })) {
        continue;
      }
      if (neighbours.any((id) => (corners[id]! - projected).length < 10))
        continue;
      final distance = (projected - point).length;
      if (distance < best ||
          (cornerId == null &&
              wallId != null &&
              distance == best &&
              wall.id < wallId)) {
        best = distance;
        candidate = projected;
        cornerId = null;
        wallId = wall.id;
      }
    }
    return candidate;
  }

  int? nearestCorner(DrawingPoint point, double radius) {
    int? chosen;
    for (final entry in corners.entries) {
      final distance = (point - entry.value).length;
      if (distance < radius ||
          (chosen != null && distance == radius && entry.key < chosen)) {
        chosen = entry.key;
        radius = distance;
      }
    }
    return chosen;
  }

  int? nearestWall(DrawingPoint point, double radius) {
    int? chosen;
    for (final wall in walls.values) {
      final distance = (point -
              projectToSegment(point, corners[wall.start]!, corners[wall.end]!))
          .length;
      if (distance < radius ||
          (chosen != null && distance == radius && wall.id < chosen)) {
        chosen = wall.id;
        radius = distance;
      }
    }
    return chosen;
  }

  /// Give the wall body its full two-sided hit band, reserving endpoint cores.
  ({int? corner, int? wall}) hitTest(DrawingPoint point,
      {required double cornerRadius,
      required double wallRadius,
      required double endpointRadius}) {
    final corner = nearestCorner(point, cornerRadius);
    final wallId = nearestWall(point, wallRadius);
    if (corner != null && wallId != null) {
      final wall = walls[wallId]!;
      final a = corners[wall.start]!, b = corners[wall.end]!, delta = b - a;
      final fraction = (point - a).dot(delta) / delta.dot(delta);
      final along = fraction * delta.length;
      final endZone = math.min(endpointRadius, delta.length * .2);
      if (along > endZone &&
          delta.length - along > endZone &&
          (point - projectToSegment(point, a, b)).length <= wallRadius &&
          (point - corners[corner]!).length > endZone) {
        return (corner: null, wall: wallId);
      }
    }
    return (corner: corner, wall: corner == null ? wallId : null);
  }

  void addPolyline(List<DrawingPoint> points,
      {double snapRadius = 0, bool dashed = false}) {
    for (final point in points) {
      _checkPoint(point);
    }
    _transaction((next) {
      for (var i = 0; i < points.length - 1; i++) {
        final a = next.snap(points[i], snapRadius);
        final b = next.snap(points[i + 1], snapRadius);
        final size = (b - a).length;
        if (size < .001) continue;
        if (size < 10)
          throw const DrawingConflict(
              'A wall segment is below 10 mm. Increase its length; no part of this stroke was added.');
        _checkPoint(a);
        _checkPoint(b);
        next._insertSegment(a, b, dashed: dashed);
      }
    });
  }

  void moveCorners(Map<int, DrawingPoint> positions, {bool join = false}) {
    _transaction((next) {
      DrawingPoint? translation;
      var rigid = positions.isNotEmpty;
      for (final entry in positions.entries) {
        if (!next.corners.containsKey(entry.key))
          throw const DrawingConflict('This corner no longer exists.');
        _checkPoint(entry.value);
        final delta = entry.value - next.corners[entry.key]!;
        translation ??= delta;
        if ((delta - translation).length > 1e-9) rigid = false;
        next.corners[entry.key] = entry.value;
      }
      next._validate();
      if (positions.isNotEmpty) {
        final affected = next.walls.values.where((w) =>
            positions.containsKey(w.start) || positions.containsKey(w.end));
        final translated = rigid
            ? {
                for (final w in next.walls.values)
                  if (positions.containsKey(w.start) &&
                      positions.containsKey(w.end))
                    w.id
              }
            : <int>{};
        final external =
            next.walls.values.where((w) => !translated.contains(w.id)).toList();
        final checked = <(int, int)>{};
        for (final a in affected) {
          // A common translation cannot introduce intersections within that set.
          for (final b
              in translated.contains(a.id) ? external : next.walls.values) {
            if (a.id == b.id ||
                !checked.add(a.id < b.id ? (a.id, b.id) : (b.id, a.id)))
              continue;
            final hits = _intersections(
                next.corners[a.start]!,
                next.corners[a.end]!,
                next.corners[b.start]!,
                next.corners[b.end]!);
            final overlap = hits.length > 1 &&
                hits.any((p) => (p - hits.first).length > .001);
            final crossing = hits.any((p) => [a.start, a.end, b.start, b.end]
                .every((id) => (next.corners[id]! - p).length > .001));
            if (overlap || crossing)
              throw const DrawingConflict(
                  'That edit crosses or overlaps another wall. Move the corner or wall less.');
          }
        }
      }
      if (join) next._connectJunctions();
    });
  }

  Set<int> straightRun(int id) {
    final wall = walls[id];
    if (wall == null)
      throw const DrawingConflict('Select an existing wall first.');
    final a = corners[wall.start]!, direction = corners[wall.end]! - a;
    final adjacency = <int, List<DrawingWall>>{};
    for (final w in walls.values) {
      adjacency.putIfAbsent(w.start, () => []).add(w);
      adjacency.putIfAbsent(w.end, () => []).add(w);
    }
    final nodes = <int>{wall.start, wall.end},
        pending = [wall.start, wall.end],
        result = <int>{id};
    while (pending.isNotEmpty) {
      final node = pending.removeLast();
      for (final edge in adjacency[node] ?? <DrawingWall>[]) {
        if ((corners[edge.start]! - a).cross(direction).abs() /
                    direction.length >
                .001 ||
            (corners[edge.end]! - a).cross(direction).abs() / direction.length >
                .001) continue;
        result.add(edge.id);
        for (final end in [edge.start, edge.end]) {
          if (nodes.add(end)) pending.add(end);
        }
      }
    }
    return result;
  }

  void moveWall(int id, DrawingPoint delta,
      {bool join = false, bool includeStraightRun = true}) {
    _checkPoint(delta);
    final run = straightRun(id);
    if (!includeStraightRun && run.length > 1)
      throw const DrawingConflict(
          'This wall has collinear connected segments. Enable Move straight run to move them together, or move a corner.');
    final nodes = {
      for (final id in run) ...[walls[id]!.start, walls[id]!.end]
    };
    moveCorners({for (final node in nodes) node: corners[node]! + delta},
        join: join);
  }

  /// Snap a rigid translation, never stretch or rotate the moving wall.
  ({DrawingPoint delta, DrawingPoint? connection}) snapWallTranslation(
      int id, DrawingPoint delta, double radius) {
    final run = straightRun(id);
    final nodes = {
      for (final id in run) ...[walls[id]!.start, walls[id]!.end]
    };
    final targets = walls.values
        .where((w) => !nodes.contains(w.start) && !nodes.contains(w.end))
        .toList();
    var best = radius;
    var result = delta;
    DrawingPoint? connection;
    for (final node in nodes) {
      final desired = corners[node]! + delta;
      for (final wall in targets) {
        final a = corners[wall.start]!, b = corners[wall.end]!;
        final projected = projectToSegment(desired, a, b);
        for (final target in [
          a,
          b,
          if ((projected - a).length >= 10 && (projected - b).length >= 10)
            projected,
        ]) {
          final correction = target - desired;
          if (correction.length >= best) continue;
          best = correction.length;
          result = delta + correction;
          connection = target;
        }
      }
    }
    return (delta: result, connection: connection);
  }

  void splitWall(int id, double distanceMm) {
    _transaction((next) {
      final wall = next.walls[id];
      if (wall == null)
        throw const DrawingConflict('Select an existing wall first.');
      final size = next.length(id);
      if (!distanceMm.isFinite || distanceMm < 10 || size - distanceMm < 10)
        throw const DrawingConflict('Each split part must be at least 10 mm.');
      final a = next.corners[wall.start]!, b = next.corners[wall.end]!;
      next._split(id, [a + (b - a) * (distanceMm / size)]);
    });
  }

  bool isStraightCorner(int id) {
    final linked =
        walls.values.where((w) => w.start == id || w.end == id).toList();
    return linked.length == 2 &&
        straightRun(linked.first.id).contains(linked.last.id);
  }

  int joinAtCorner(int id) {
    int? result;
    _transaction((next) {
      final linked =
          next.walls.values.where((w) => w.start == id || w.end == id).toList();
      if (linked.length != 2)
        throw const DrawingConflict(
            'Join requires exactly two walls at this corner. Branch junctions cannot be removed.');
      final a = linked[0], b = linked[1];
      if (a.dashed != b.dashed) {
        throw const DrawingConflict(
            'Use the same wall type before joining segments.');
      }
      final start = a.start == id ? a.end : a.start,
          end = b.start == id ? b.end : b.start;
      final u = next.corners[start]! - next.corners[id]!,
          v = next.corners[end]! - next.corners[id]!;
      if (u.dot(v) >= 0 || u.cross(v).abs() / (u.length * v.length) > 1e-6)
        throw const DrawingConflict(
            'Only straight, opposite wall segments can be joined.');
      for (final span in next._dimensions.values) {
        if (span.$1.contains(a.id) != span.$1.contains(b.id))
          throw const DrawingConflict(
              'Unlock individual segment lengths before joining them.');
      }
      for (final r in next._relations.values) {
        for (final side in [r.first, r.second]) {
          if (side.contains(a.id) != side.contains(b.id))
            throw const DrawingConflict(
                'Remove geometric relationships on individual segments before joining them.');
        }
      }
      next.walls.remove(a.id);
      next.walls.remove(b.id);
      next.corners.remove(id);
      result = next._edge(start, end, dashed: a.dashed);
      for (final r in next._relations.values.toList()) {
        next._relations[r.id] = r.remap({
          a.id: [result!],
          b.id: []
        });
      }
      for (final entry in next._dimensions.entries.toList()) {
        next._dimensions[entry.key] = (
          [
            for (final wallId in entry.value.$1)
              if (wallId != a.id && wallId != b.id) wallId,
            if (entry.value.$1.contains(a.id)) result!
          ],
          entry.value.$2
        );
      }
    });
    return result!;
  }

  void setLength(int id, double mm,
      {required bool lock,
      bool join = true,
      WallResizeAnchor anchor = WallResizeAnchor.start}) {
    if (!mm.isFinite || mm < 10 || mm > 10000000)
      throw const DrawingConflict('Wall length must be 10 mm to 10,000 m.');
    _transaction((next) {
      final wall = next.walls[id];
      if (wall == null) throw const DrawingConflict('Select a wall first.');
      final a = next.corners[wall.start]!, b = next.corners[wall.end]!;
      final direction = (b - a) * (1 / (b - a).length);
      next.walls[id] =
          DrawingWall(id, wall.start, wall.end, dashed: wall.dashed);
      next._dimensions.removeWhere(
          (_, value) => value.$1.length == 1 && value.$1.single == id);
      next.moveCorners(switch (anchor) {
        WallResizeAnchor.start => {wall.end: a + direction * mm},
        WallResizeAnchor.end => {wall.start: b - direction * mm},
        WallResizeAnchor.center => {
            wall.start: (a + b) * .5 - direction * (mm * .5),
            wall.end: (a + b) * .5 + direction * (mm * .5),
          }
      });
      next._validate();
      next.walls[id] = DrawingWall(id, wall.start, wall.end,
          fixedLength: lock ? mm : null, dashed: wall.dashed);
      if (lock) next._dimensions[id] = ([id], mm);
      if (join) next._connectJunctions();
    });
  }

  /// Exact entry keeps rectangular rooms rectangular; other outlines stay local.
  void setRoomWallLength(int id, double mm) {
    if (isFixed(id) && (length(id) - mm).abs() > .01) {
      throw const DrawingConflict(
          'Unlock this wall before changing its length.');
    }
    final nodes = rectangle(id);
    if (nodes == null) {
      setLength(id, mm, lock: isFixed(id));
      return;
    }
    resizeRectangle(id, mm, (corners[nodes[3]]! - corners[nodes[0]]!).length);
  }

  void deleteWall(int id) {
    unlock(id);
    removeRelations({id});
    walls.remove(id);
    final used = {
      for (final w in walls.values) ...[w.start, w.end]
    };
    corners.removeWhere((id, _) => !used.contains(id));
    if (walls.isEmpty) calibrated = false;
  }

  void deleteCorner(int id) {
    final linked = walls.values
        .where((w) => w.start == id || w.end == id)
        .map((w) => w.id)
        .toList();
    for (final wall in linked) {
      deleteWall(wall);
    }
  }

  List<int>? rectangle(int id) {
    final wall = walls[id];
    if (wall == null) return null;
    final a = wall.start, b = wall.end;
    Iterable<int> neighbours(int node) => walls.values
        .where((w) => w.start == node || w.end == node)
        .map((w) => w.start == node ? w.end : w.start);
    for (final c in neighbours(b).where((p) => p != a)) {
      for (final d in neighbours(c).where((p) => p != a && p != b)) {
        if (!neighbours(d).contains(a)) continue;
        final pts = [a, b, c, d].map((p) => corners[p]!).toList();
        final edges = [for (var i = 0; i < 4; i++) pts[(i + 1) % 4] - pts[i]];
        if (List.generate(
                4,
                (i) =>
                    edges[i].dot(edges[(i + 1) % 4]).abs() <=
                    edges[i].length * edges[(i + 1) % 4].length * 1e-6)
            .every((v) => v)) return [a, b, c, d];
      }
    }
    return null;
  }

  void resizeRectangle(int wallId, double width, double lengthMm) {
    final nodes = rectangle(wallId);
    if (nodes == null)
      throw const DrawingConflict('Select a wall of a rectangular room.');
    if (![width, lengthMm].every((v) => v.isFinite && v >= 10 && v <= 10000000))
      throw const DrawingConflict('Enter valid room dimensions.');
    final a = corners[nodes[0]]!;
    final u = corners[nodes[1]]! - a;
    final v = corners[nodes[3]]! - a;
    final b = a + u * (width / u.length);
    final d = a + v * (lengthMm / v.length);
    moveCorners({nodes[1]: b, nodes[2]: b + d - a, nodes[3]: d}, join: true);
  }

  void _transaction(void Function(WallNetwork) action) {
    final next = copy();
    action(next);
    next._validate();
    corners
      ..clear()
      ..addAll(next.corners);
    walls
      ..clear()
      ..addAll(next.walls);
    _dimensions
      ..clear()
      ..addAll(next._dimensions);
    _relations
      ..clear()
      ..addAll(next._relations);
    _nextRelation = next._nextRelation;
    calibrated = next.calibrated;
    _nextCorner = next._nextCorner;
    _nextWall = next._nextWall;
  }

  static void _checkPoint(DrawingPoint p) {
    if (!p.isFinite || p.x.abs() > 100000000 || p.y.abs() > 100000000)
      throw const DrawingConflict(
          'This drawing exceeds the supported coordinate range.');
  }

  void _validate() {
    for (final p in corners.values) {
      _checkPoint(p);
    }
    final edges = <(int, int)>{};
    final measuredWalls = {
      for (final dimension in _dimensions.values) ...dimension.$1
    };
    for (final wall in walls.values) {
      if (!corners.containsKey(wall.start) || !corners.containsKey(wall.end))
        throw const DrawingConflict('A wall has a missing connection.');
      final key = wall.start < wall.end
          ? (wall.start, wall.end)
          : (wall.end, wall.start);
      if (!edges.add(key))
        throw const DrawingConflict('Duplicate wall segments are not allowed.');
      final size = length(wall.id);
      if (!size.isFinite || size < 10 - 1e-6)
        throw const DrawingConflict('That edit collapses a wall below 10 mm.');
      final fixed = wall.fixedLength;
      if (fixed != null &&
          (!fixed.isFinite ||
              (fixed - size).abs() > .01 ||
              !measuredWalls.contains(wall.id))) {
        throw const DrawingConflict(
            'A fixed wall length conflicts with its geometry or measured-span lock. Unlock its length before editing, or restore a valid plan.');
      }
    }
    for (final r in _relations.values) {
      if (![...r.first, ...r.second].every(walls.containsKey))
        throw const DrawingConflict(
            'A geometric constraint references a missing wall.');
      DrawingPoint direction(List<int> ids) {
        final w = walls[ids.first]!;
        final d = corners[w.end]! - corners[w.start]!;
        if (ids.any((id) {
          final edge = walls[id]!;
          return !parallelVectors(d, corners[edge.end]! - corners[edge.start]!);
        }))
          throw DrawingConflict(
              '${r.kind.label} constraint requires its split walls to stay straight.');
        return d;
      }

      final valid = switch (r.kind) {
        WallRelationKind.equalLength =>
          (r.first.map(length).fold(0.0, (a, b) => a + b) -
                      r.second.map(length).fold(0.0, (a, b) => a + b))
                  .abs() <=
              .01,
        WallRelationKind.parallel =>
          parallelVectors(direction(r.first), direction(r.second)),
        WallRelationKind.rightAngle =>
          direction(r.first).dot(direction(r.second)).abs() /
                  (direction(r.first).length * direction(r.second).length) <=
              1e-6,
      };
      if (!valid)
        throw DrawingConflict(
            '${r.kind.label} constraint conflicts with this edit. Align or resize the walls first, or remove the constraint.');
    }
    for (final dimension in _dimensions.entries) {
      final size = dimension.value.$1.map(length).fold(0.0, (a, b) => a + b);
      if ((size - dimension.value.$2).abs() > .01)
        throw DrawingConflict(
            'Measured span ${dimension.key} is fixed at ${dimension.value.$2.toStringAsFixed(1)} mm. Unlock its length before changing connected corners.');
    }
  }

  int _node(DrawingPoint point) {
    final old = nearestCorner(point, .001);
    if (old != null) return old;
    final id = _nextCorner++;
    corners[id] = point;
    return id;
  }

  int _edge(int a, int b, {double? fixed, bool dashed = false}) {
    for (final wall in walls.values) {
      if ((wall.start == a && wall.end == b) ||
          (wall.start == b && wall.end == a)) return wall.id;
    }
    final id = _nextWall++;
    walls[id] = DrawingWall(id, a, b, fixedLength: fixed, dashed: dashed);
    return id;
  }

  void _split(int wallId, List<DrawingPoint> points) {
    final wall = walls[wallId];
    if (wall == null) return;
    final a = corners[wall.start]!, b = corners[wall.end]!;
    final direction = b - a;
    // Coincident endpoints merge later; they must not create replacement walls.
    final nodes = {
      wall.start,
      wall.end,
      ...points
          .where((p) => (p - a).length >= .001 && (p - b).length >= .001)
          .map(_node)
    }.toList()
      ..sort((i, j) => (corners[i]! - a)
          .dot(direction)
          .compareTo((corners[j]! - a).dot(direction)));
    if (nodes.length == 2) return;
    walls.remove(wallId);
    final replacements = <int>[];
    for (var i = 0; i < nodes.length - 1; i++) {
      final size = (corners[nodes[i + 1]]! - corners[nodes[i]]!).length;
      if (size < .001) continue;
      replacements.add(_edge(nodes[i], nodes[i + 1], dashed: wall.dashed));
    }
    for (final r in _relations.values.toList()) {
      _relations[r.id] = r.remap({wallId: replacements});
    }
    for (final entry in _dimensions.entries.toList()) {
      if (entry.value.$1.contains(wallId))
        _dimensions[entry.key] = (
          [
            for (final id in entry.value.$1)
              ...id == wallId ? replacements : [id]
          ],
          entry.value.$2
        );
    }
  }

  void _insertSegment(DrawingPoint a, DrawingPoint b, {bool dashed = false}) {
    final cuts = <DrawingPoint>[a, b];
    for (final wall in walls.values.toList()) {
      final c = corners[wall.start]!, d = corners[wall.end]!;
      final intersections = _intersections(a, b, c, d);
      cuts.addAll(intersections);
      _split(wall.id, intersections);
    }
    final direction = b - a;
    final nodes = cuts.map(_node).toSet().toList()
      ..sort((i, j) => (corners[i]! - a)
          .dot(direction)
          .compareTo((corners[j]! - a).dot(direction)));
    for (var i = 0; i < nodes.length - 1; i++) {
      if ((corners[nodes[i + 1]]! - corners[nodes[i]]!).length >= .001)
        _edge(nodes[i], nodes[i + 1], dashed: dashed);
    }
  }

  void _connectJunctions() {
    final entries = walls.values.toList();
    final cuts = <int, List<DrawingPoint>>{};
    final boxes = [
      for (final w in entries)
        (
          math.min(corners[w.start]!.x, corners[w.end]!.x),
          math.min(corners[w.start]!.y, corners[w.end]!.y),
          math.max(corners[w.start]!.x, corners[w.end]!.x),
          math.max(corners[w.start]!.y, corners[w.end]!.y)
        )
    ];
    for (var i = 0; i < entries.length; i++) {
      for (var j = i + 1; j < entries.length; j++) {
        final a = entries[i], b = entries[j], boxA = boxes[i], boxB = boxes[j];
        if (a.start == b.start ||
            a.start == b.end ||
            a.end == b.start ||
            a.end == b.end) {
          continue;
        }
        if (boxA.$3 < boxB.$1 - .001 ||
            boxB.$3 < boxA.$1 - .001 ||
            boxA.$4 < boxB.$2 - .001 ||
            boxB.$4 < boxA.$2 - .001) {
          continue;
        }
        final points = _intersections(corners[a.start]!, corners[a.end]!,
            corners[b.start]!, corners[b.end]!);
        if (points.isEmpty) continue;
        cuts.putIfAbsent(a.id, () => []).addAll(points);
        cuts.putIfAbsent(b.id, () => []).addAll(points);
      }
    }
    for (final entry in cuts.entries) {
      _split(entry.key, entry.value);
    }
    // Reuse coincident corner IDs after a dragged endpoint reaches a junction.
    final merged = <int, int>{};
    final buckets = <(int, int), List<int>>{};
    for (final id in corners.keys) {
      final p = corners[id]!,
          x = (p.x / .001).floor(),
          y = (p.y / .001).floor();
      int? canonical;
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          for (final other in buckets[(x + dx, y + dy)] ?? <int>[]) {
            if ((corners[other]! - p).length < .001 &&
                (canonical == null || other < canonical)) {
              canonical = other;
            }
          }
        }
      }
      merged[id] = canonical ?? id;
      if (canonical == null) buckets.putIfAbsent((x, y), () => []).add(id);
    }
    final existing = walls.values.toList();
    walls.clear();
    final edgeIds = <(int, int), int>{};
    for (final w in existing) {
      final a = merged[w.start]!, b = merged[w.end]!;
      if (a == b) {
        throw const DrawingConflict(
            'The corners cannot be merged because a wall would collapse.');
      }
      final key = a < b ? (a, b) : (b, a);
      final duplicate = edgeIds[key];
      if (duplicate == null) {
        walls[w.id] = DrawingWall(w.id, a, b,
            fixedLength: w.fixedLength, dashed: w.dashed);
        edgeIds[key] = w.id;
      } else {
        final canonical = duplicate;
        if (walls[canonical]!.dashed != w.dashed) {
          throw const DrawingConflict(
              'Overlapping walls have different types. Convert one before merging.');
        }
        for (final r in _relations.values.toList()) {
          _relations[r.id] = r.remap({
            w.id: [canonical]
          });
        }
        for (final entry in _dimensions.entries.toList()) {
          _dimensions[entry.key] = (
            entry.value.$1
                .map((id) => id == w.id ? canonical : id)
                .toSet()
                .toList(),
            entry.value.$2
          );
        }
      }
    }
    final used = {
      for (final w in walls.values) ...[w.start, w.end]
    };
    corners.removeWhere((id, _) => !used.contains(id));
  }

  static List<DrawingPoint> _intersections(
      DrawingPoint a, DrawingPoint b, DrawingPoint c, DrawingPoint d) {
    final ab = b - a, cd = d - c;
    final determinant = ab.cross(cd);
    if (determinant.abs() < 1e-8) {
      if ((c - a).cross(ab).abs() > 1e-5) return [];
      return [a, b, c, d]
          .where((p) =>
              (p - projectToSegment(p, a, b)).length < .001 &&
              (p - projectToSegment(p, c, d)).length < .001)
          .toList();
    }
    final t = (c - a).cross(cd) / determinant,
        u = (c - a).cross(ab) / determinant;
    return t >= -1e-9 && t <= 1 + 1e-9 && u >= -1e-9 && u <= 1 + 1e-9
        ? [a + ab * t.clamp(0.0, 1.0)]
        : [];
  }
}
