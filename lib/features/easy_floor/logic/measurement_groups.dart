import 'wall_network.dart';

/// Only isolated, unbranched rectangles have unambiguous redundant dimensions.
List<Set<int>> redundantMeasurementGroups(WallNetwork model) {
  final adjacent = <int, Set<int>>{};
  for (final wall in model.walls.values) {
    adjacent.putIfAbsent(wall.start, () => {}).add(wall.id);
    adjacent.putIfAbsent(wall.end, () => {}).add(wall.id);
  }
  final visited = <int>{}, groups = <Set<int>>[];
  for (final id in model.walls.keys) {
    if (visited.contains(id)) continue;
    final component = <int>{}, nodes = <int>{}, pending = [id];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      if (!visited.add(current)) continue;
      component.add(current);
      final wall = model.walls[current]!;
      for (final node in [wall.start, wall.end]) {
        if (nodes.add(node)) pending.addAll(adjacent[node]!);
      }
    }
    if (component.length != 4 ||
        nodes.length != 4 ||
        nodes.any((node) => adjacent[node]!.length != 2) ||
        component.any(model.isFixed)) {
      continue;
    }
    final corners = model.rectangle(id);
    if (corners == null) continue;
    final edges = [
      for (var i = 0; i < 4; i++)
        component.singleWhere((edge) {
          final w = model.walls[edge]!;
          return {w.start, w.end}
              .containsAll([corners[i], corners[(i + 1) % 4]]);
        })
    ];
    if ((model.length(edges[0]) - model.length(edges[2])).abs() >= .001 ||
        (model.length(edges[1]) - model.length(edges[3])).abs() >= .001) {
      continue;
    }
    if ((model.length(edges[0]) - model.length(edges[1])).abs() < .001) {
      groups.add(component);
    } else {
      groups.addAll([
        {edges[0], edges[2]},
        {edges[1], edges[3]}
      ]);
    }
  }
  return groups;
}
