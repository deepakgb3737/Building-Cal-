import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_history.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';

void main() {
  const p = DrawingPoint.new;
  test('Fixed length metadata cannot disagree with geometry or lose its lock',
      () {
    final model = WallNetwork()..addPolyline([p(0, 0), p(2000, 0)]);
    model.setLength(model.walls.keys.single, 2000, lock: true);
    final invalidLength = model.toJson();
    (invalidLength['walls'] as List).single[3] = 2500.0;
    expect(() => WallNetwork.fromJson(invalidLength),
        throwsA(isA<DrawingConflict>()));
    final missingLock = model.toJson();
    missingLock['dimensions'] = <Object>[];
    expect(() => WallNetwork.fromJson(missingLock),
        throwsA(isA<DrawingConflict>()));
    expect(model.length(model.walls.keys.single), 2000);
    expect(model.isFixed(model.walls.keys.single), isTrue);
  });

  test('Locked shared span survives splits, shared movement, join and history',
      () {
    final model = WallNetwork()
      ..addPolyline([p(0, 0), p(4000, 0), p(4000, 3000), p(0, 3000), p(0, 0)]);
    final top = model.walls.keys.first;
    model.setLength(top, 4000, lock: true);
    model.addPolyline([p(2000, 0), p(2000, 3000)]);
    final branch = model.nearestWall(p(2000, 1500), 1)!;
    final history = DrawingHistory()..commit(model), before = model.toJson();
    model.moveWall(branch, p(200, 0), join: true);
    final topParts = model.straightRun(model.nearestWall(p(1000, 0), 1)!);
    expect(topParts.map(model.length).reduce((a, b) => a + b), 4000);
    expect(topParts.every(model.isFixed), isTrue);
    final moved = model.toJson();
    expect(() => model.moveWall(branch, p(3000, 0), join: true),
        throwsA(isA<DrawingConflict>()));
    expect(model.toJson(), moved);
    expect(WallNetwork.fromJson(moved).toJson(), moved);
    history.commit(model);
    expect(history.undo().toJson(), before);
    expect(history.redo().toJson(), moved);
    model.deleteWall(branch);
    final topCorner = model.nearestCorner(p(2200, 0), 1)!;
    final joined = model.joinAtCorner(topCorner);
    expect(model.isFixed(joined), isTrue);
    expect(model.length(joined), 4000);
    expect(WallNetwork.fromJson(model.toJson()).toJson(), model.toJson());
  });
}
