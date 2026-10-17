import 'dart:convert';
import 'drawing_point.dart';
import 'drawing_annotations.dart';
import 'document_json.dart';
import 'wall_network.dart';
import 'drawing_camera.dart';

class DocumentSettings {
  const DocumentSettings(
      {this.unit = DrawingUnit.metres,
      this.snapping = true,
      this.axes = true,
      this.recognition = true,
      this.parallel = false,
      this.grid = false,
      this.angleStep,
      this.angleTolerance = 3,
      this.showLabels = true,
      this.outline = true,
      this.originX = 40,
      this.originY = 40,
      this.scale = .1});
  final DrawingUnit unit;
  final bool snapping, axes, recognition, parallel, grid, showLabels, outline;
  final double? angleStep;
  final double angleTolerance, originX, originY, scale;
  Map<String, Object?> toJson() => {
        'unit': unit.symbol,
        'snap': snapping,
        'axes': axes,
        'recognition': recognition,
        'parallel': parallel,
        'grid': grid,
        'step': angleStep,
        'tolerance': angleTolerance,
        'labels': showLabels,
        'outline': outline,
        'x': originX,
        'y': originY,
        'scale': scale
      };
  // Camera, labels and stroke mode are view choices, not unsaved drawing edits.
  String get editSignature => jsonEncode(toJson()
    ..removeWhere(
        (k, _) => ['x', 'y', 'scale', 'labels', 'outline'].contains(k)));
  static DocumentSettings fromJson(Object? value) {
    final d = jsonObject(value),
        tolerance = jsonNumber(jsonObject(value)['tolerance']);
    final step = d['step'] == null ? null : jsonNumber(d['step']);
    final x = jsonNumber(d['x']),
        y = jsonNumber(d['y']),
        scale = jsonNumber(d['scale']);
    if (tolerance < 0 ||
        tolerance > 45 ||
        (step != null && step != 15) ||
        scale < minDrawingScale ||
        scale > maxDrawingScale ||
        x.abs() > 1e10 ||
        y.abs() > 1e10) {
      throw const FormatException('Invalid drawing settings.');
    }
    return DocumentSettings(
        unit: DrawingUnit.values.firstWhere((u) => u.symbol == d['unit'],
            orElse: () =>
                throw const FormatException('Unknown measurement unit.')),
        snapping: jsonBoolean(d['snap']),
        axes: jsonBoolean(d['axes']),
        recognition: jsonBoolean(d['recognition']),
        parallel: jsonBoolean(d['parallel']),
        grid: jsonBoolean(d['grid']),
        showLabels: jsonBoolean(d['labels']),
        outline: jsonBoolean(d['outline']),
        angleStep: step,
        angleTolerance: tolerance,
        originX: x,
        originY: y,
        scale: scale);
  }
}

class FloorDocument {
  const FloorDocument(this.walls, this.annotations, this.settings);
  final WallNetwork walls;
  final DrawingAnnotations annotations;
  final DocumentSettings settings;
  Map<String, Object?> toJson() => {
        'walls': walls.toJson(),
        'annotations': annotations.toJson(),
        'settings': settings.toJson()
      };
  static FloorDocument fromJson(Object? value) {
    final d = jsonObject(value);
    try {
      return FloorDocument(
          WallNetwork.fromJson(d['walls']),
          DrawingAnnotations.fromJson(d['annotations']),
          DocumentSettings.fromJson(d['settings']));
    } catch (e) {
      throw FormatException('Invalid floor plan: $e');
    }
  }
}
