import 'dart:async';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/document_storage.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_annotations.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/floor_document.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_relation.dart';

class TestDocumentStorage implements DocumentStorage {
  final Map<String, String> files = {};
  bool failWrite = false;
  Completer<void>? gate;
  @override
  Future<Map<String, String>> readAll() async => Map.of(files);
  @override
  Future<void> write(String id, String content) async {
    if (gate != null) await gate!.future;
    if (failWrite) throw StateError('Storage full');
    files[id] = content;
  }

  @override
  Future<void> delete(String id) async {
    files.remove(id);
  }
}

FloorDocument documentFixture() {
  const p = DrawingPoint.new;
  final m = WallNetwork()
    ..addPolyline([p(0, 0), p(3000, 0), p(3000, 2000), p(0, 2000), p(0, 0)]);
  m.addPolyline([p(1500, 0), p(1500, 2000)]);
  final main = m.nearestWall(p(1500, 1000), 1)!;
  final a = m.nearestWall(p(750, 0), 1)!, b = m.nearestWall(p(750, 2000), 1)!;
  m.constrain(WallRelationKind.rightAngle, main, a);
  m.constrain(WallRelationKind.parallel, a, b);
  m.constrain(WallRelationKind.equalLength, a, b);
  m.setLength(main, 2000, lock: true);
  m.calibrated = true;
  m.addPolyline([p(6000, 0), p(8000, 0)]);
  final stock = m.nearestWall(p(7000, 0), 1)!;
  m.setLength(stock, 2000, lock: true);
  m.splitWall(stock, 1000);
  m.duplicateGroup(
      m.straightRun(m.nearestWall(p(6500, 0), 1)!), {}, p(0, 4000));
  final notes = DrawingAnnotations();
  notes.add('Kitchen\nNotes', p(500, 600),
      sizeMm: 240,
      ink: AnnotationInk.red,
      alignment: AnnotationAlignment.center);
  notes.add('Outside outline', p(-1000, 3000));
  return FloorDocument(
      m,
      notes,
      const DocumentSettings(
          unit: DrawingUnit.feetInches,
          angleStep: 15,
          angleTolerance: 5,
          parallel: true,
          showLabels: true,
          originX: -120,
          originY: 80,
          scale: .2));
}
