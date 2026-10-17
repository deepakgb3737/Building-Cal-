import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';
import 'package:grid_ceiling_calculator/ui/app_typography.dart';
import '../logic/drawing_point.dart';
import '../logic/drawing_guides.dart';
import '../logic/wall_network.dart';
import '../logic/drawing_history.dart';
import 'dimension_dialog.dart';
import 'drawing_painter.dart';
import 'board_directions.dart';
import 'shape_dialog.dart';
import '../logic/drawing_shapes.dart';
import '../logic/sketch_refinement.dart';
import '../logic/drawing_camera.dart';
import '../logic/wall_resize.dart';
import 'wall_resize_options.dart';
import 'drawing_tool_palette.dart';
import 'drawing_toolbar_row.dart';
import 'shape_picker.dart';
import '../logic/drawing_precision.dart';
import '../logic/wall_relation.dart';
import '../logic/drawing_annotations.dart';
import 'annotation_painter.dart';
import 'annotation_dialog.dart';
import 'annotation_controls.dart';
import '../logic/document_repository.dart';
import '../logic/document_platform_store.dart';
import '../logic/floor_document.dart';
import 'document_workspace.dart';

enum _Tool { smart, draw, wall, corner, pan, group, text, tape }

class EasyFloorScreen extends StatefulWidget {
  const EasyFloorScreen(
      {super.key,
      this.guideOpacity = .5,
      this.documents,
      this.drawingMovementThreshold = 8})
      : assert(guideOpacity >= 0 && guideOpacity <= 1),
        assert(drawingMovementThreshold > 0 &&
            drawingMovementThreshold < double.infinity);
  final double guideOpacity;

  /// Drawing intent distance in logical pixels, independent of camera zoom.
  final double drawingMovementThreshold;
  final DocumentRepository? documents;
  @override
  State<EasyFloorScreen> createState() => _EasyFloorScreenState();
}

class _EasyFloorScreenState extends State<EasyFloorScreen> {
  WallNetwork _model = WallNetwork();
  final _history = DrawingHistory();
  late final DocumentWorkspace _documents;
  late final AppLifecycleListener _exitListener;
  bool _allowClose = false;
  bool _hideUi = false;
  bool? _pendingHideUi;

  void _setUiHidden(bool hidden) {
    if (_pointers.isNotEmpty || _before != null) {
      _pendingHideUi = hidden;
      return;
    }
    setState(() {
      if (_hideUi != hidden) {
        _origin += Offset(0, hidden ? kToolbarHeight : -kToolbarHeight);
      }
      _hideUi = hidden;
      _pendingHideUi = null;
    });
  }

  void _finishUiToggle() {
    if (_pendingHideUi == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _pointers.isEmpty &&
          _before == null &&
          _pendingHideUi != null) {
        _setUiHidden(_pendingHideUi!);
      }
    });
    // The final pinch lift may not otherwise schedule a frame.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void initState() {
    super.initState();
    _documents = DocumentWorkspace(
        repository: widget.documents ?? createDocumentRepository(),
        context: () => context,
        capture: () => FloorDocument(
            _model.copy(), _annotations.copy(), _documentSettings),
        apply: _applyDocument,
        revision: () => _history.revision,
        settingsSignature: () => _documentSettings.editSignature,
        pending: () =>
            _preset != null ||
            _suggestion != null ||
            (_polygon && _polygonPoints.isNotEmpty) ||
            (_before != null && !_multiTouch && _gestureTool != _Tool.pan));
    _documents.addListener(_documentChanged);
    _exitListener = AppLifecycleListener(
        onInactive: () {
          if (_before != null || _pointerDown != null) {
            _cancelGesture();
            _pointers.clear();
            _pointerPositions.clear();
            _navigationLocked = false;
          }
        },
        onExitRequested: () async => await _documents.confirmLeave()
            ? AppExitResponse.exit
            : AppExitResponse.cancel);
  }

  DocumentSettings get _documentSettings => DocumentSettings(
      unit: _unit,
      snapping: _snapping,
      axes: _alignment,
      recognition: _recognition,
      parallel: _parallelSnap,
      grid: _gridSnap,
      angleStep: _angleStep,
      angleTolerance: _angleToleranceDegrees,
      showLabels: _showAllMeasurements,
      outline: _outline,
      originX: _origin.dx,
      originY: _origin.dy,
      scale: _scale);
  void _documentChanged() {
    if (mounted) setState(() {});
  }

  void _applyDocument(FloorDocument doc) {
    _cancel();
    setState(() {
      _model = doc.walls.copy();
      _annotations = doc.annotations.copy();
      _history.reset(_model, annotations: _annotations);
      _selectedWall = null;
      _selectedCorner = null;
      _labels.clear();
      _labelOffsets.clear();
      _annotationBounds.clear();
      final s = doc.settings;
      _unit = s.unit;
      _alignment = s.axes;
      _recognition = s.recognition;
      _parallelSnap = s.parallel;
      _gridSnap = s.grid;
      _angleStep = s.angleStep;
      _angleToleranceDegrees = s.angleTolerance;
      _showAllMeasurements = s.showLabels;
      _outline = s.outline;
      _origin = Offset(s.originX, s.originY);
      _scale = s.scale;
    });
  }

  Future<void> _closeWorkspace() async {
    if (await _documents.confirmLeave() && mounted && !_allowClose) {
      setState(() => _allowClose = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  DrawingAnnotations _annotations = DrawingAnnotations();
  DrawingAnnotations? _beforeAnnotations;
  final Map<int, Rect> _annotationBounds = {};
  final Set<int> _selectedAnnotations = {};
  bool _multiText = false, _textEditing = false;
  _Tool _tool = _Tool.smart;
  _Tool _gestureTool = _Tool.draw;
  final Map<int, Rect> _labels = {};
  final Map<int, double> _labelOffsets = {};
  List<DrawingGuide> _guides = [];
  bool _showAllMeasurements = const DocumentSettings().showLabels;
  bool _multiSelect = false, _duplicateGroup = false, _stretchAttached = false;
  final Set<int> _pickedWalls = {}, _pickedCorners = {};
  Set<int> _roomSelection = {};
  Set<int> _groupPreviewWalls = {};
  DrawingPoint? _groupDragOrigin;
  bool _recognition = true, _allSelected = false, _polygon = false;
  ShapeSuggestion? _suggestion;
  bool _refinementPreview = false;
  List<DrawingPoint> _originalShape = [], _polygonPoints = [];
  WallNetwork? _suggestionBase;
  ShapeSpec? _preset;
  ShapeSpec? _draftBefore;
  DrawingPoint? _draftAnchorBefore;
  List<DrawingPoint>? _polygonBefore;
  DrawingPoint _presetAnchor = const DrawingPoint(0, 0);
  Offset? _finger;
  double? _moveOffset;
  DrawingUnit _unit = DrawingUnit.metres;
  bool _outline = true;
  bool _drawDashed = false;
  (DrawingPoint, DrawingPoint)? _tape, _tapeBefore;
  bool _tapeSnap = true;
  bool _tapeStartHandle = false;

  DrawingPoint _tapePoint(Offset position) {
    final point = world(position);
    final corner = _tapeSnap ? _model.nearestCorner(point, 12 / _scale) : null;
    final snapped = corner != null
        ? _model.corners[corner]!
        : _tapeSnap
            ? _model.snap(point, 12 / _scale)
            : point;
    _connection = _tapeSnap &&
            (corner != null || _model.nearestWall(snapped, .001) != null)
        ? snapped
        : null;
    return snapped;
  }

  final bool _snapping = true;
  bool _alignment = true, _continueDrawing = false;
  bool _pressedSelectedCorner = false;
  Timer? _hold;
  final Set<int> _pointers = {};
  final Map<int, Offset> _pointerPositions = {};
  bool _navigationLocked = false;
  DrawingPoint? _connection;

  @override
  void dispose() {
    _hold?.cancel();
    _fitTapTimer?.cancel();
    _exitListener.dispose();
    _documents.removeListener(_documentChanged);
    _documents.dispose();
    super.dispose();
  }

  DrawingPoint _snap(DrawingPoint p,
      {int? excludeCorner, DrawingPoint? anchor, WallNetwork? model}) {
    final base = model ?? _model;
    final connected = base.snap(p, 16 / _scale, excludeCorner: excludeCorner);
    if ((connected - p).length > .001 ||
        (_snapping &&
            (base.nearestCorner(p, .001) != null ||
                base.walls.values.any((w) =>
                    w.start != excludeCorner &&
                    w.end != excludeCorner &&
                    (p -
                                projectToSegment(p, base.corners[w.start]!,
                                    base.corners[w.end]!))
                            .length <
                        .001)))) return connected;
    final incident = {
      for (final w in base.walls.values)
        if (w.start == excludeCorner || w.end == excludeCorner) w.id
    };
    return precisionPoint(base, p,
        anchor: anchor,
        grid: _gridSnap,
        axes: _alignment,
        angleStep: _angleStep,
        parallel: _parallelSnap,
        perpendicular: _parallelSnap,
        angleToleranceDegrees: _angleToleranceDegrees,
        tolerance: 6 / _scale,
        excludeWalls: incident);
  }

  ({int? corner, int? wall}) _touchTarget(DrawingPoint point) =>
      _model.hitTest(point,
          cornerRadius: 22 / _scale,
          wallRadius: 16 / _scale,
          endpointRadius: 6 / _scale);

  bool _resizeWall = false;
  WallResizeAnchor _resizeAnchor = WallResizeAnchor.start;
  int? _endpointResizeWall;
  bool _enteringWallLength = false;

  bool _editConflict = false;
  bool _gridSnap = false, _parallelSnap = false;
  double? _angleStep;
  double _angleToleranceDegrees = 3;

  void _toggleMeasurements() => setState(() {
        _showAllMeasurements = !_showAllMeasurements;
        if (!_showAllMeasurements && _before == null) {
          _selectedWall = null;
          _selectedCorner = null;
          _resizeWall = false;
        }
      });

  Future<void> _chooseAngleTolerance() async {
    if (_before != null) _cancelGesture();
    final value = await showDialog<double>(
        context: context,
        builder: (context) =>
            SimpleDialog(title: const Text('Angle snap tolerance'), children: [
              for (final degrees in [.5, 1.0, 2.0, 3.0, 5.0, 10.0])
                SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, degrees),
                    child: Text('$degrees°'))
            ]));
    if (mounted && value != null) {
      setState(() => _angleToleranceDegrees = value);
    }
  }

  Offset _origin = const Offset(40, 40);
  double _scale = .1;
  double _startScale = .1;
  Offset _startOrigin = Offset.zero;
  Offset _startFocal = Offset.zero;
  DrawingPoint? _dragStart;
  WallNetwork? _before;
  int? _selectedWall, _selectedCorner;
  List<DrawingPoint> _stroke = [], _preview = [];
  bool _multiTouch = false;
  bool _dragIntent = false;
  String? _error;
  Size _viewport = Size.zero;
  Offset? _pointerDown;
  int? _pressedLabel;
  double _navigationScale = .1, _navigationSpan = 1;
  DrawingPoint _navigationAnchor = const DrawingPoint(0, 0);

  Offset get _pointerMidpoint =>
      _pointerPositions.values.reduce((a, b) => a + b) /
      _pointerPositions.length.toDouble();

  double _pointerSpan(Offset center) =>
      _pointerPositions.values
          .map((p) => (p - center).distance)
          .reduce((a, b) => a + b) /
      _pointerPositions.length;

  void _captureNavigation() {
    final center = _pointerMidpoint;
    _navigationScale = _scale;
    _navigationSpan = math.max(.001, _pointerSpan(center));
    _navigationAnchor = world(center);
  }

  final _textControlsKey = GlobalKey();
  final _sketchControlsKey = GlobalKey();
  bool _toolsExpanded = true;
  final _wallControlsKey = GlobalKey(),
      _cornerControlsKey = GlobalKey(),
      _roomControlsKey = GlobalKey();
  Rect _toolBounds = Rect.zero;
  final _boardBoundsKey = GlobalKey();

  List<Rect> _measurementInterfaceObstacles() {
    if (_hideUi || !mounted) return [];
    final board = (_boardBoundsKey.currentContext as Element?)?.renderObject;
    if (board is! RenderBox || !board.attached || !board.hasSize) return [];
    return [
      for (final key in [
        _textControlsKey,
        _wallControlsKey,
        _cornerControlsKey,
        _roomControlsKey,
        _sketchControlsKey
      ])
        if (key.currentContext case final Element element)
          if (element.renderObject case final RenderBox panel)
            if (panel.attached && panel.hasSize)
              panel.localToGlobal(Offset.zero, ancestor: board) & panel.size,
    ];
  }

  double get _spaceAboveTools =>
      math.max(0, _toolBounds.top.clamp(0, _viewport.height) - 16);
  double get _spaceBelowTools => math.max(
      0, _viewport.height - _toolBounds.bottom.clamp(0, _viewport.height) - 16);
  double get _contextBottom => _spaceAboveTools > _spaceBelowTools
      ? _viewport.height - _toolBounds.top.clamp(0, _viewport.height) + 8
      : 8;

  Widget _contextPanel(GlobalKey key, {required Widget child}) =>
      ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: math.max(_spaceAboveTools, _spaceBelowTools)),
          child: Material(
              key: key,
              color: AppColors.white,
              child: SingleChildScrollView(child: child)));

  int? _resizingText;
  double _textResizeDistance = 1;
  Timer? _fitTapTimer;
  Offset? _emptyTapPosition;

  void _resetFitTap() {
    _fitTapTimer?.cancel();
    _emptyTapPosition = null;
  }

  int? _textResizeAt(Offset p) {
    if (_selectedAnnotations.length != 1 ||
        (_tool != _Tool.smart && _tool != _Tool.text)) {
      return null;
    }
    final id = _selectedAnnotations.single, rect = _annotationBounds[id];
    return rect != null &&
            (p - (rect.bottomRight + const Offset(5, 5))).distance <= 18
        ? id
        : null;
  }

  DrawingPoint? get _presetHandle {
    final spec = _preset;
    if (spec == null) return null;
    final radians = spec.rotation * math.pi / 180;
    final height = spec.kind == ShapePreset.square ? spec.width : spec.height;
    return _presetAnchor +
        DrawingPoint(
            spec.width * math.cos(radians) - height * math.sin(radians),
            spec.width * math.sin(radians) + height * math.cos(radians));
  }

  DrawingPoint world(Offset screen) => DrawingPoint(
      (screen.dx - _origin.dx) / _scale, (screen.dy - _origin.dy) / _scale);

  int? _labelAt(Offset position) {
    _labels.removeWhere((id, _) => !_model.walls.containsKey(id));
    final direct =
        nearestWallLabel(_labels, position, preferredWall: _selectedWall);
    if (direct != null) return direct;
    final point = world(position);
    // Enlarged label targets must not steal touches from visible geometry.
    if (_model.nearestWall(point, 16 / _scale) != null ||
        _model.nearestCorner(point, 6 / _scale) != null) {
      return null;
    }
    return nearestWallLabel(_labels, position,
        padding: 6, preferredWall: _selectedWall);
  }

  int? _annotationAt(Offset position) {
    for (final id in _annotationBounds.keys.toList().reversed) {
      if (_annotationBounds[id]!.inflate(10).contains(position)) return id;
    }
    return null;
  }

  Future<void> _editAnnotation({int? id, DrawingPoint? position}) async {
    if (_textEditing) return;
    if (_before != null) _cancelGesture();
    final note = id == null
        ? DrawingAnnotation(0, '', position!)
        : _annotations.items[id]!;
    _hold?.cancel();
    _pointerDown = null;
    _textEditing = true;
    final edited = await showDialog<DrawingAnnotation>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AnnotationDialog(note: note));
    if (!mounted) return;
    setState(() {
      _textEditing = false;
      if (edited == null) return;
      try {
        final chosen = id ??
            _annotations.add(edited.text, edited.position,
                sizeMm: edited.sizeMm,
                ink: edited.ink,
                alignment: edited.alignment);
        if (id != null) _annotations.update(edited);
        _selectedAnnotations
          ..clear()
          ..add(chosen);
        _selectedWall = null;
        _selectedCorner = null;
        _history.commit(_model, annotations: _annotations);
        _error = null;
      } on ArgumentError catch (e) {
        _error = e.message.toString();
      }
    });
  }

  void _changeAnnotations({bool duplicate = false}) {
    if (_before != null ||
        _pointers.isNotEmpty ||
        _navigationLocked ||
        _selectedAnnotations.isEmpty) {
      return;
    }
    setState(() {
      try {
        if (duplicate) {
          final ids = _annotations.duplicate(
              _selectedAnnotations, DrawingPoint(24 / _scale, 24 / _scale));
          _selectedAnnotations
            ..clear()
            ..addAll(ids);
        } else {
          _annotations.delete(_selectedAnnotations);
          _selectedAnnotations.clear();
        }
        _history.commit(_model, annotations: _annotations);
        _error = null;
      } on ArgumentError catch (e) {
        _error = e.message.toString();
      }
    });
  }

  void _moveAnnotations(DrawingPoint point) {
    final next = _beforeAnnotations!.copy();
    try {
      next.move(_selectedAnnotations, point - _dragStart!);
      final focus = next.items[_selectedAnnotations.first]!.position;
      final references = [
        world(_viewport.center(Offset.zero)),
        for (final note in _beforeAnnotations!.items.values)
          if (!_selectedAnnotations.contains(note.id)) note.position
      ];
      final candidates = <(double, DrawingGuide)>[];
      for (var i = 0; i < references.length; i++) {
        final target = references[i];
        for (final vertical in [false, true]) {
          final delta = vertical
              ? (focus.x - target.x).abs()
              : (focus.y - target.y).abs();
          if (delta <= 6 / _scale) {
            final end = vertical
                ? DrawingPoint(target.x, focus.y)
                : DrawingPoint(focus.x, target.y);
            if ((end - target).length > 6 / _scale) {
              candidates.add((
                delta,
                DrawingGuide(
                    'text$i$vertical',
                    vertical ? GuideKind.vertical : GuideKind.horizontal,
                    target,
                    end,
                    target)
              ));
            }
          }
        }
      }
      for (final guide in drawingGuides(_model, focus, 6 / _scale)) {
        candidates.add(((focus - guide.end).length, guide));
      }
      candidates.sort((a, b) => a.$1.compareTo(b.$1));
      _guides = candidates.take(2).map((g) => g.$2).toList();
      _annotations = next;
      _error = null;
    } on ArgumentError catch (e) {
      _annotations = _beforeAnnotations!.copy();
      _guides = [];
      _error = e.message.toString();
    }
  }

  void _start(ScaleStartDetails details) {
    if (_textEditing) return;
    // Raw touch navigation may start before the scale recognizer wins its arena.
    if (_before != null && _multiTouch && _navigationLocked) {
      return;
    }
    _resetFitTap();
    _resizingText = null;
    _roomSelection = {};
    _allSelected = false;
    _hold?.cancel();
    _before = _model.copy();
    _beforeAnnotations = _annotations.copy();
    _draftBefore = _preset;
    _draftAnchorBefore = _presetAnchor;
    _polygonBefore = List.of(_polygonPoints);
    _dragStart = world(details.pointerCount > 1
        ? details.localFocalPoint
        : (_pointerDown ?? details.localFocalPoint));
    _startScale = _scale;
    _startOrigin = _origin;
    _startFocal = _pointerDown ?? details.localFocalPoint;
    _multiTouch = details.pointerCount > 1 || _navigationLocked;
    if (details.pointerCount > 1 && _pointerPositions.length < 2) {
      _navigationScale = _scale;
      _navigationSpan = 1;
      _navigationAnchor = world(details.localFocalPoint);
    }
    _error = null;
    _editConflict = false;
    _dragIntent = false;
    if (_tool == _Tool.tape) {
      _tapeBefore = _tape;
      _gestureTool = _Tool.tape;
      if (_multiTouch) return;
      setState(() {
        final start = _pointerDown ?? details.localFocalPoint;
        _tapeStartHandle = _tape != null &&
            (_tape!.$1 - _dragStart!).length * _scale <= 22 &&
            (_tape!.$1 - _dragStart!).length <=
                (_tape!.$2 - _dragStart!).length;
        final endHandle =
            _tape != null && (_tape!.$2 - _dragStart!).length * _scale <= 22;
        if (!_tapeStartHandle && !endHandle) {
          final point = _tapePoint(start);
          _tape = (point, point);
        }
      });
      return;
    }
    if (_multiTouch) return;
    if (_suggestion != null) {
      _gestureTool = _Tool.pan;
      return;
    }
    _resizingText = _textResizeAt(_pointerDown ?? details.localFocalPoint);
    final text = _annotationAt(_pointerDown ?? details.localFocalPoint);
    if ((_tool == _Tool.smart || _tool == _Tool.text) &&
        _preset == null &&
        !_polygon &&
        !_multiSelect &&
        (text != null || _resizingText != null || _tool == _Tool.text)) {
      setState(() {
        _gestureTool = _Tool.text;
        _selectedWall = null;
        _selectedCorner = null;
        if (_resizingText != null) {
          _textResizeDistance =
              (_dragStart! - _beforeAnnotations!.items[_resizingText]!.position)
                  .length;
        }
        if (text != null) {
          if (!_selectedAnnotations.contains(text)) {
            if (!_multiText) _selectedAnnotations.clear();
            _selectedAnnotations.add(text);
          }
        } else if (_resizingText == null) {
          _selectedAnnotations.clear();
        }
      });
      _update(ScaleUpdateDetails(
          localFocalPoint: details.localFocalPoint,
          focalPoint: details.focalPoint,
          pointerCount: details.pointerCount));
      return;
    }
    _selectedAnnotations.clear();
    _gestureTool = _continueDrawing ? _Tool.draw : _tool;
    if (_preset != null || _polygon) {
      _gestureTool = _Tool.pan;
      if (_preset != null &&
          (_dragStart! - _presetHandle!).length * _scale > 22) {
        _presetAnchor = _snap(_dragStart!);
      }
      _update(ScaleUpdateDetails(
          localFocalPoint: details.localFocalPoint,
          focalPoint: details.focalPoint,
          pointerCount: details.pointerCount));
      return;
    }
    if (_multiSelect) {
      final corner = _model.nearestCorner(_dragStart!, 22 / _scale);
      final wall = _model.nearestWall(_dragStart!, 16 / _scale) ??
          (_pointerDown == null ? _labelAt(_startFocal) : _pressedLabel);
      final nodes = _model.groupNodes(_pickedWalls, _pickedCorners);
      _gestureTool = (corner != null && nodes.contains(corner)) ||
              (corner == null && wall != null && _pickedWalls.contains(wall))
          ? _Tool.group
          : _Tool.pan;
      _groupDragOrigin = _dragStart;
      _update(ScaleUpdateDetails(
          localFocalPoint: details.localFocalPoint,
          focalPoint: details.focalPoint,
          pointerCount: details.pointerCount));
      return;
    }
    final label = _pointerDown == null ? _labelAt(_startFocal) : _pressedLabel;
    if (label != null) {
      setState(() {
        _gestureTool = _Tool.smart;
        _selectedWall = label;
        _selectedCorner = null;
      });
      return;
    }
    final target =
        label == null ? _touchTarget(_dragStart!) : (corner: null, wall: label);
    // Wall strokes continue an unselected open end; tap it first to reshape it.
    if (!_outline &&
        _tool == _Tool.smart &&
        label == null &&
        target.corner != null &&
        !_pressedSelectedCorner &&
        _endpointResizeWall == null) {
      final attached = _model.walls.values
          .where((w) => w.start == target.corner || w.end == target.corner);
      if (attached.length == 1) _continueDrawing = true;
    }
    if (_continueDrawing) _gestureTool = _Tool.draw;
    if (_tool == _Tool.smart && !_continueDrawing) {
      final corner = target.corner;
      final wall = target.wall;
      _gestureTool = corner != null
          ? _Tool.corner
          : wall != null
              ? _Tool.wall
              : _Tool.draw;
      if (corner == null && wall == null) {
        _roomSelection = _model.enclosedComponentAt(_dragStart!);
        if (_roomSelection.isNotEmpty) {
          _gestureTool = _Tool.group;
          _groupDragOrigin = _dragStart;
          _selectedWall = null;
          _selectedCorner = null;
        }
      }
    }
    if (_endpointResizeWall != null && !_continueDrawing) {
      _gestureTool = _Tool.corner;
    }
    setState(() {
      if (_gestureTool == _Tool.draw) {
        var p = _snap(_dragStart!);
        if (_continueDrawing && _snapping) {
          if (_selectedCorner != null) {
            p = _model.corners[_selectedCorner!]!;
          } else if (_selectedWall != null) {
            final wall = _model.walls[_selectedWall!]!;
            p = projectToSegment(_dragStart!, _model.corners[wall.start]!,
                _model.corners[wall.end]!);
          }
        }
        _selectedWall = null;
        _selectedCorner = null;
        _stroke = [p];
        _preview = [];
      } else if (_gestureTool == _Tool.corner) {
        _selectedCorner = _tool == _Tool.smart && _endpointResizeWall == null
            ? target.corner
            : _model.nearestCorner(_dragStart!, 24 / _scale);
        _selectedWall = _endpointResizeWall;
      } else if (_gestureTool == _Tool.wall) {
        final previous = _selectedWall;
        _selectedWall = _tool == _Tool.smart
            ? target.wall
            : _model.nearestWall(_dragStart!, 20 / _scale) ?? label;
        if (previous != _selectedWall) {
          _resizeWall = false;
        }
        _selectedCorner = null;
      }
    });
    _update(ScaleUpdateDetails(
      focalPoint: details.focalPoint,
      localFocalPoint: details.localFocalPoint,
      pointerCount: details.pointerCount,
    ));
  }

  void _update(ScaleUpdateDetails details) {
    if (_before == null) return;
    if (details.pointerCount > 1) {
      setState(() {
        if (!_multiTouch) {
          if (_gestureTool == _Tool.tape) _tape = _tapeBefore;
          _model = _before!.copy();
          _annotations = _beforeAnnotations!.copy();
          _error = null;
          _editConflict = false;
          _stroke = [];
          _preset = _draftBefore;
          if (_draftAnchorBefore != null) _presetAnchor = _draftAnchorBefore!;
          if (_polygonBefore != null) _polygonPoints = List.of(_polygonBefore!);
          _resizingText = null;
          _preview = _suggestion != null
              ? List.of(
                  _refinementPreview ? _suggestion!.points : _originalShape)
              : _preset?.points(_presetAnchor) ??
                  (_polygon ? List.of(_polygonPoints) : []);
          _connection = null;
          _guides = [];
          _finger = null;
          _moveOffset = null;
          _continueDrawing = false;
          _multiTouch = true;
          _startScale = _scale;
        }
        final focal = _pointerPositions.length > 1
            ? _pointerMidpoint
            : details.localFocalPoint;
        final span = _pointerPositions.length > 1
            ? _pointerSpan(focal)
            : _navigationSpan * details.scale;
        _scale = (_navigationScale * span / _navigationSpan)
            .clamp(minDrawingScale, maxDrawingScale);
        _origin = focal -
            Offset(_navigationAnchor.x * _scale, _navigationAnchor.y * _scale);
      });
      return;
    }
    if (_multiTouch) return;
    if (_gestureTool == _Tool.tape) {
      setState(() {
        final point = _tapePoint(details.localFocalPoint);
        _tape = _tapeStartHandle ? (point, _tape!.$2) : (_tape!.$1, point);
        _finger = details.localFocalPoint;
      });
      return;
    }
    if (_suggestion != null) return;
    if (!_dragIntent) {
      if ((details.localFocalPoint - _startFocal).distance <
          widget.drawingMovementThreshold) {
        return;
      }
      _dragIntent = true;
    }
    setState(() {
      if (_gestureTool == _Tool.text) {
        if (_resizingText != null) {
          final note = _beforeAnnotations!.items[_resizingText]!;
          final ratio =
              (world(details.localFocalPoint) - note.position).length /
                  math.max(1e-9, _textResizeDistance);
          final layer = _beforeAnnotations!.copy();
          layer.update(
              note.copyWith(sizeMm: (note.sizeMm * ratio).clamp(120, 480)));
          _annotations = layer;
        } else if (_selectedAnnotations.isNotEmpty) {
          _moveAnnotations(world(details.localFocalPoint));
        }
        return;
      }
      if (_preset != null) {
        final spec = _preset!;
        final delta = world(details.localFocalPoint) - _presetAnchor;
        final radians = spec.rotation * math.pi / 180;
        final width =
            (delta.x * math.cos(radians) + delta.y * math.sin(radians))
                .abs()
                .clamp(10.0, 10000000.0);
        final height =
            (-delta.x * math.sin(radians) + delta.y * math.cos(radians))
                .abs()
                .clamp(10.0, 10000000.0);
        _preset = spec.resized(width, height);
        try {
          _preview = _preset!.points(_presetAnchor);
          _error = null;
        } on DrawingConflict catch (e) {
          _error = e.message;
          _preset = spec;
          _preview = spec.points(_presetAnchor);
        }
        _guides = drawingGuides(
            _model, world(details.localFocalPoint), 6 / _scale,
            previous: _guides);
        return;
      }
      if (_gestureTool == _Tool.group) {
        final candidate = _before!.copy();
        final delta = world(details.localFocalPoint) - _groupDragOrigin!;
        try {
          if (_roomSelection.isNotEmpty) {
            candidate.moveRoom(_roomSelection, delta,
                alignmentRadius: 6 / _scale);
          } else if (_duplicateGroup) {
            _groupPreviewWalls =
                candidate.duplicateGroup(_pickedWalls, _pickedCorners, delta);
          } else {
            candidate.moveGroup(_pickedWalls, _pickedCorners, delta,
                stretchAttached: _stretchAttached);
            _groupPreviewWalls = Set.of(_pickedWalls);
          }
          _model = candidate;
          final groupNodes = _roomSelection.isNotEmpty
              ? _before!.groupNodes(_roomSelection, {})
              : _before!.groupNodes(_pickedWalls, _pickedCorners);
          _guides = _roomSelection.isNotEmpty
              ? roomMovementGuides(candidate, groupNodes, 6 / _scale)
              : drawingGuides(
                  _before!, world(details.localFocalPoint), 6 / _scale,
                  anchor: _groupDragOrigin,
                  exclude: _duplicateGroup ? {} : groupNodes,
                  previous: _guides);
          _editConflict = false;
          _error = null;
        } on DrawingConflict catch (e) {
          _model = _before!.copy();
          _groupPreviewWalls = {};
          _guides = [];
          _editConflict = true;
          _error = e.message;
        }
        _finger = details.localFocalPoint;
        return;
      }
      if (_gestureTool == _Tool.pan) {
        _origin = _startOrigin + details.localFocalPoint - _startFocal;
        return;
      }
      _finger = details.localFocalPoint;
      final p = world(details.localFocalPoint);
      if (_gestureTool == _Tool.draw) {
        if ((p - _stroke.last).length * _scale >= 1.5) {
          _stroke.add(p);
          if (_stroke.length > 4096 && _stroke.length % 256 == 0) {
            // Retain genuine corners instead of blindly dropping alternate samples.
            _stroke = straightenStroke(_stroke, .35 / _scale);
          }
        }
        var snapped = _snap(p);
        _connection = _snapping &&
                (_model.nearestCorner(snapped, .001) != null ||
                    _model.nearestWall(snapped, .001) != null)
            ? snapped
            : null;
        final raw = [..._stroke.take(math.max(1, _stroke.length - 1)), snapped];
        if (_snapping &&
            (p - _stroke.first).length * _scale < 4 &&
            _stroke.length > 3) {
          raw[raw.length - 1] = _stroke.first;
          _connection = _stroke.first;
        }
        _preview = _outline
            ? straightenStroke(raw, 3 / _scale)
            : [raw.first, raw.last];
        if (_preview.length > 1 && _connection == null) {
          final previous = _preview[_preview.length - 2];
          final delta = _preview.last - previous;
          if (delta.length * _scale > 24) {
            final aligned = precisionPoint(_model, _preview.last,
                anchor: previous,
                previous:
                    _preview.length > 2 ? _preview[_preview.length - 3] : null,
                grid: _gridSnap,
                axes: _alignment,
                angleStep: _angleStep,
                parallel: _parallelSnap,
                perpendicular: _parallelSnap,
                angleToleranceDegrees: _angleToleranceDegrees,
                tolerance: 6 / _scale);
            _preview[_preview.length - 1] = aligned;
          }
        }
        if (_preview.length > 1) {
          _guides = drawingGuides(_model, _preview.last, 6 / _scale,
              anchor: _preview[_preview.length - 2], previous: _guides);
        }
        return;
      }
      if (_before == null) return;
      final candidate = _before!.copy();
      _connection = null;
      try {
        if (_gestureTool == _Tool.corner && _selectedCorner != null) {
          if (candidate.walls.values.any((w) =>
              candidate.isFixed(w.id) &&
              (w.start == _selectedCorner || w.end == _selectedCorner))) {
            throw const DrawingConflict(
                'Unlock the connected wall before moving this corner.');
          }
          if (_endpointResizeWall != null) {
            final wall = candidate.walls[_endpointResizeWall]!;
            if (candidate.isFixed(wall.id)) {
              throw const DrawingConflict(
                  'Unlock this wall’s fixed length before resizing by hand.');
            }
            final d =
                candidate.corners[wall.end]! - candidate.corners[wall.start]!;
            final change = (p - _dragStart!).dot(d) / d.length;
            final fromEnd = _selectedCorner == wall.end;
            candidate.setLength(
                wall.id, d.length + (fromEnd ? change : -change),
                lock: false,
                join: false,
                anchor:
                    fromEnd ? WallResizeAnchor.start : WallResizeAnchor.end);
          } else {
            final target =
                candidate.corners[_selectedCorner!]! + (p - _dragStart!);
            final linked = candidate.walls.values.firstWhere(
                (w) => w.start == _selectedCorner || w.end == _selectedCorner);
            final anchor = candidate.corners[
                linked.start == _selectedCorner ? linked.end : linked.start]!;
            final snapped = _snap(target,
                excludeCorner: _selectedCorner,
                anchor: anchor,
                model: candidate);
            if (candidate.walls.values.any((w) =>
                w.start != _selectedCorner &&
                w.end != _selectedCorner &&
                (snapped -
                            projectToSegment(
                                snapped,
                                candidate.corners[w.start]!,
                                candidate.corners[w.end]!))
                        .length <
                    .001)) {
              _connection = snapped;
            }
            candidate.moveCorners({_selectedCorner!: snapped});
          }
        } else if (_gestureTool == _Tool.wall && _selectedWall != null) {
          final wall = candidate.walls[_selectedWall!]!;
          if (candidate.isFixed(wall.id)) {
            throw const DrawingConflict(
                'Unlock this wall before moving or resizing it.');
          }
          final direction =
              candidate.corners[wall.end]! - candidate.corners[wall.start]!;
          if (_resizeWall) {
            final amount = (p - _dragStart!).dot(direction) / direction.length;
            final change = switch (_resizeAnchor) {
              WallResizeAnchor.start => amount,
              WallResizeAnchor.end => -amount,
              WallResizeAnchor.center => amount * 2,
            };
            candidate.setLength(wall.id, direction.length + change,
                lock: false, join: false, anchor: _resizeAnchor);
          } else {
            var delta = p - _dragStart!;
            if (_gridSnap) {
              final start = candidate.corners[wall.start]!;
              delta = precisionPoint(candidate, start + delta,
                      grid: true, tolerance: 6 / _scale) -
                  start;
            }
            final unsnapped = delta;
            if (_snapping && delta.length > .001) {
              final snapped =
                  candidate.snapWallTranslation(wall.id, delta, 10 / _scale);
              delta = snapped.delta;
              _connection = snapped.connection;
            }
            try {
              candidate.moveWall(wall.id, delta);
            } on DrawingConflict {
              if (_connection == null) rethrow;
              candidate.moveWall(wall.id, unsnapped);
              _connection = null;
            }
          }
        }
        final changed = <int>{
          for (final id in candidate.corners.keys)
            if (_before!.corners[id] != candidate.corners[id]) id
        };
        DrawingPoint? focus;
        DrawingPoint? guideAnchor =
            _selectedCorner == null ? null : _before!.corners[_selectedCorner!];
        if (_selectedCorner != null) {
          focus = candidate.corners[_selectedCorner!];
          final linked = candidate.walls.values.firstWhere(
              (w) => w.start == _selectedCorner || w.end == _selectedCorner);
          guideAnchor = candidate.corners[
              linked.start == _selectedCorner ? linked.end : linked.start];
        }
        if (_selectedWall != null) {
          final w = candidate.walls[_selectedWall!];
          if (w != null) {
            final midpoint =
                (candidate.corners[w.start]! + candidate.corners[w.end]!) * .5;
            final original =
                (_before!.corners[w.start]! + _before!.corners[w.end]!) * .5;
            _moveOffset = (midpoint - original).length;
            focus = candidate.corners[w.end];
            guideAnchor = candidate.corners[w.start];
          }
        }
        _guides = focus == null
            ? []
            : drawingGuides(_before!, focus, 6 / _scale,
                exclude: changed, anchor: guideAnchor, previous: _guides);
        _model = candidate;
        _editConflict = false;
        _error = null;
      } on DrawingConflict catch (e) {
        _model = _before!.copy();
        _editConflict = true;
        _connection = null;
        _moveOffset = null;
        _guides = [];
        _error = e.message;
      }
    });
  }

  void _end(ScaleEndDetails details) {
    if (_before == null) return;
    if (_gestureTool == _Tool.tape) {
      setState(() {
        _before = null;
        _beforeAnnotations = null;
        _pointerDown = null;
        _finger = null;
        _connection = null;
        _guides = [];
      });
      return;
    }
    if (_suggestion != null || _preset != null || _polygon) {
      setState(() {
        _before = null;
        _beforeAnnotations = null;
        _finger = null;
        _guides = [];
        _pointerDown = null;
        _preview = _suggestion != null
            ? List.of(_refinementPreview ? _suggestion!.points : _originalShape)
            : _preset?.points(_presetAnchor) ?? List.of(_polygonPoints);
      });
      return;
    }
    setState(() {
      try {
        if (_editConflict) {
          _model = _before!.copy();
        } else if (!_multiTouch &&
            _gestureTool == _Tool.draw &&
            _dragIntent &&
            _preview.length > 1 &&
            List.generate(_preview.length - 1,
                        (i) => (_preview[i + 1] - _preview[i]).length * _scale)
                    .fold(0.0, (a, b) => a + b) >=
                widget.drawingMovementThreshold) {
          if (_outline && (_preview.length > 2 || _stroke.length > 3)) {
            final raw = List<DrawingPoint>.of(_stroke);
            raw[raw.length - 1] = _preview.last;
            final cleanup = SketchRefinement.fromStroke(raw,
                tolerance: 3 / _scale,
                align: _alignment,
                existing: _before,
                // Attached geometry is authoritative; don't reshape its anchors.
                recognize: _recognition &&
                    !_preview.any((p) => _model.nearestWall(p, .001) != null));
            if (cleanup.original.length == 2 && cleanup.refined.length == 2) {
              _model.addPolyline(cleanup.refined, dashed: _drawDashed);
            } else {
              _suggestion = ShapeSuggestion(
                  cleanup.shape ?? ShapePreset.polygon, cleanup.refined);
              _suggestionBase = _before!.copy();
              _originalShape = cleanup.original;
              _refinementPreview = false;
            }
          } else {
            _model.addPolyline(_preview, dashed: _drawDashed);
          }
        } else if (!_multiTouch &&
            (_gestureTool == _Tool.wall ||
                _gestureTool == _Tool.corner ||
                (_gestureTool == _Tool.group && _roomSelection.isEmpty))) {
          _model.moveCorners({}, join: true);
        }
        if (_gestureTool == _Tool.group &&
            !_editConflict &&
            !_multiTouch &&
            _duplicateGroup &&
            _groupPreviewWalls.isNotEmpty) {
          _pickedWalls
            ..clear()
            ..addAll(_groupPreviewWalls);
          _pickedCorners.clear();
          _duplicateGroup = false;
        }
        if (!_multiTouch && _gestureTool != _Tool.pan) {
          _history.commit(_model, annotations: _annotations);
        }
      } on DrawingConflict catch (e) {
        _model = _before ?? _model;
        _error = e.message;
      }
      _before = null;
      _resizingText = null;
      _endpointResizeWall = null;
      _beforeAnnotations = null;
      _groupPreviewWalls = {};
      if (!_pickedWalls.every(_model.walls.containsKey) ||
          !_pickedCorners.every(_model.corners.containsKey)) {
        _pickedWalls.clear();
        _pickedCorners.clear();
        _allSelected = false;
        _duplicateGroup = false;
        _error =
            'Connections changed. Select the walls again to continue editing.';
      }
      _hold?.cancel();
      _continueDrawing = false;
      _connection = null;
      _guides = [];
      _finger = null;
      _moveOffset = null;
      _pointerDown = null;
      _stroke = [];
      _preview = _suggestion != null ? List.of(_originalShape) : [];
      if (_selectedWall != null && !_model.walls.containsKey(_selectedWall))
        _selectedWall = null;
      if (_selectedCorner != null &&
          !_model.corners.containsKey(_selectedCorner)) _selectedCorner = null;
    });
  }

  void _select(TapUpDetails details) {
    if (_tool == _Tool.tape) {
      _pointerDown = null;
      return;
    }
    if (_textEditing ||
        _navigationLocked ||
        (_multiTouch && _pointerDown == null)) {
      return;
    }
    final tapPosition = _pointerDown ?? details.localPosition;
    final labelAtDown =
        _pointerDown == null ? _labelAt(tapPosition) : _pressedLabel;
    if (_suggestion != null) return;
    final point = world(tapPosition);
    final empty = _preset == null &&
        !_polygon &&
        !_multiSelect &&
        _tool != _Tool.text &&
        _annotationAt(tapPosition) == null &&
        _model.nearestCorner(point, 22 / _scale) == null &&
        _model.nearestWall(point, 16 / _scale) == null &&
        labelAtDown == null;
    if (empty && _tool == _Tool.smart) {
      final room = _model.enclosedComponentAt(point);
      if (room.isNotEmpty) {
        _resetFitTap();
        setState(() {
          _roomSelection = room;
          _selectedWall = null;
          _selectedCorner = null;
          _pointerDown = null;
        });
        return;
      }
    }
    if (empty) {
      if (_fitTapTimer?.isActive == true &&
          (tapPosition - _emptyTapPosition!).distance <= 24) {
        _resetFitTap();
        _pointerDown = null;
        _fit();
        return;
      }
      _resetFitTap();
      _emptyTapPosition = tapPosition;
      _fitTapTimer = Timer(
          const Duration(milliseconds: 300), () => _emptyTapPosition = null);
    } else {
      _resetFitTap();
    }
    if (_textResizeAt(tapPosition) != null) {
      _pointerDown = null;
      return;
    }
    if (_preset != null || _polygon) {
      setState(() {
        final p = _snap(world(tapPosition));
        if (_preset != null) {
          _presetAnchor = p;
          _preview = _preset!.points(p);
        } else {
          if (_polygonPoints.isEmpty || (p - _polygonPoints.last).length >= 10)
            _polygonPoints.add(p);
          _preview = List.of(_polygonPoints);
        }
      });
      return;
    }
    final note = _annotationAt(tapPosition);
    if (!_multiSelect &&
        (_tool == _Tool.smart || _tool == _Tool.text) &&
        (note != null || _tool == _Tool.text)) {
      _hold?.cancel();
      _pointerDown = null;
      setState(() {
        _selectedWall = null;
        _selectedCorner = null;
        _roomSelection = {};
        if (_multiText) {
          if (note == null) {
            _selectedAnnotations.clear();
          } else if (!_selectedAnnotations.add(note)) {
            _selectedAnnotations.remove(note);
          }
        } else {
          _selectedAnnotations.clear();
          if (note != null) _selectedAnnotations.add(note);
        }
      });
      if (!_multiText) _editAnnotation(id: note, position: world(tapPosition));
      return;
    }
    _selectedAnnotations.clear();
    if (_multiSelect) {
      _hold?.cancel();
      setState(() {
        final p = world(tapPosition);
        final corner = _model.nearestCorner(p, 22 / _scale);
        final wall = _model.nearestWall(p, 16 / _scale) ?? labelAtDown;
        if (corner != null) {
          if (!_pickedCorners.add(corner)) _pickedCorners.remove(corner);
        } else if (wall != null) {
          if (!_pickedWalls.add(wall)) _pickedWalls.remove(wall);
        }
        _allSelected = false;
      });
      return;
    }
    _allSelected = false;
    _hold?.cancel();
    _continueDrawing = false;
    _connection = null;
    _pointerDown = null;
    if (_tool == _Tool.draw || _tool == _Tool.pan) return;
    final p = world(tapPosition);
    final target = labelAtDown == null
        ? _touchTarget(p)
        : (corner: null, wall: labelAtDown);
    final corner = _tool == _Tool.smart
        ? target.corner
        : _model.nearestCorner(p, 22 / _scale);
    final wall =
        _tool == _Tool.smart ? target.wall : _model.nearestWall(p, 16 / _scale);
    final label = labelAtDown;
    setState(() {
      _roomSelection = {};
      _selectedCorner = _tool == _Tool.wall ? null : corner;
      _selectedWall = _selectedCorner != null ? null : (wall ?? label);
      _error = null;
    });
    if (label != null) _dimensions();
  }

  void _cancelGesture() {
    if (_tool == _Tool.tape && _before != null) {
      setState(() {
        _tape = _tapeBefore;
        _before = null;
        _beforeAnnotations = null;
        _pointerDown = null;
        _finger = null;
        _connection = null;
        _guides = [];
        _origin = _startOrigin;
        _scale = _startScale;
      });
      return;
    }
    if (_before != null && _suggestion != null) {
      setState(() {
        _origin = _startOrigin;
        _scale = _startScale;
        _model = _before!;
        _annotations = _beforeAnnotations!;
        _before = null;
        _beforeAnnotations = null;
        _pointerDown = null;
        _hold?.cancel();
        _guides = [];
      });
      return;
    }
    if (_before == null) {
      setState(() {
        _hold?.cancel();
        _continueDrawing = false;
        _connection = null;
        _pointerDown = null;
      });
      return;
    }
    final draft = _draftBefore,
        anchor = _draftAnchorBefore,
        polygon = _polygon,
        points = _polygonBefore;
    final multi = _multiSelect,
        pickedWalls = Set<int>.of(_pickedWalls),
        pickedCorners = Set<int>.of(_pickedCorners);
    final duplicate = _duplicateGroup, stretch = _stretchAttached;
    final textSelection = Set<int>.of(_selectedAnnotations),
        multiText = _multiText,
        textTool = _tool == _Tool.text;
    _cancel();
    setState(() {
      _preset = draft;
      if (anchor != null) _presetAnchor = anchor;
      _polygon = polygon;
      _polygonPoints = List.of(points ?? []);
      _preview = _preset?.points(_presetAnchor) ??
          (_polygon ? List.of(_polygonPoints) : []);
      _multiSelect = multi;
      _pickedWalls.addAll(pickedWalls);
      _pickedCorners.addAll(pickedCorners);
      _duplicateGroup = duplicate;
      _stretchAttached = stretch;
      _selectedAnnotations.addAll(textSelection);
      _multiText = multiText;
      if (textTool) _tool = _Tool.text;
    });
  }

  void _cancel() {
    _resetFitTap();
    _endpointResizeWall = null;
    setState(() {
      _hold?.cancel();
      _continueDrawing = false;
      _dragIntent = false;
      _editConflict = false;
      _connection = null;
      _guides = [];
      _finger = null;
      _moveOffset = null;
      if (_before != null) {
        _origin = _startOrigin;
        _scale = _startScale;
      }
      _model = _before ?? _model;
      _annotations = _beforeAnnotations ?? _annotations;
      _beforeAnnotations = null;
      _selectedAnnotations.clear();
      _multiText = false;
      _before = null;
      _resizingText = null;
      _stroke = [];
      _preview = [];
      _tool = _Tool.smart;
      _tape = null;
      _pointerDown = null;
      _suggestion = null;
      _refinementPreview = false;
      _suggestionBase = null;
      _originalShape = [];
      _preset = null;
      _polygon = false;
      _polygonPoints = [];
      _allSelected = false;
      _multiSelect = false;
      _pickedWalls.clear();
      _pickedCorners.clear();
      _roomSelection = {};
      _groupPreviewWalls = {};
      _duplicateGroup = false;
      _stretchAttached = false;
      _error = null;
    });
  }

  void _toggleWallLock() {
    final id = _selectedWall;
    if (id == null || _enteringWallLength || !_canDeleteGeometry) return;
    setState(() {
      try {
        if (_model.isFixed(id)) {
          _model.unlock(id);
        } else {
          _model.lockLength(id);
        }
        _history.commit(_model);
        _error = null;
      } on DrawingConflict catch (e) {
        _error = e.message;
      }
    });
  }

  bool get _roomLengthsLocked =>
      _roomSelection.isNotEmpty && _roomSelection.every(_model.isFixed);

  void _toggleRoomLengthLocks() {
    if (_selectionBusy || _roomSelection.isEmpty) return;
    setState(() {
      try {
        _model.setGroupLengthLocks(_roomSelection, locked: !_roomLengthsLocked);
        _history.commit(_model);
        _error = null;
      } on DrawingConflict catch (e) {
        _error = e.message;
      }
    });
  }

  String? _geometryError(void Function(WallNetwork) edit) {
    try {
      edit(_model.copy());
      return null;
    } on DrawingConflict catch (e) {
      return e.message;
    }
  }

  Future<void> _dimensions(
      {bool rectangle = false, bool advanced = false}) async {
    if (_before != null) _cancel();
    final id = _selectedWall;
    if (id == null) return;
    final nodes = rectangle ? _model.rectangle(id) : null;
    final second = nodes == null
        ? null
        : (_model.corners[nodes[2]]! - _model.corners[nodes[1]]!).length;
    void resize(WallNetwork model, (double, double?, bool) values) {
      if (rectangle) {
        model.resizeRectangle(id, values.$1, values.$2!);
      } else if (advanced) {
        model.setLength(id, values.$1, lock: values.$3, anchor: _resizeAnchor);
      } else {
        model.setRoomWallLength(id, values.$1);
      }
    }

    setState(() => _enteringWallLength = !rectangle);
    final result = await showDialog<(double, double?, bool)>(
        context: context,
        builder: (_) => DimensionDialog(
            valueMm: _model.length(id),
            secondMm: second,
            validateEdit: (values) =>
                _geometryError((next) => resize(next, values)),
            unit: _unit,
            onUnitChanged: (unit) => setState(() => _unit = unit),
            resizeAnchor: _resizeAnchor,
            showLock: advanced,
            onResizeChanged: rectangle || !advanced
                ? null
                : (mode) => setState(() => _resizeAnchor = mode),
            fixed: _model.isFixed(id)));
    if (mounted) setState(() => _enteringWallLength = false);
    if (!mounted || result == null) return;
    setState(() {
      try {
        resize(_model, result);
        _history.commit(_model);
        _error = null;
        if (!_model.walls.containsKey(id)) _selectedWall = null;
      } on DrawingConflict catch (e) {
        _guides = [];
        _error = e.message;
      }
    });
  }

  void _restore(bool undo) {
    _cancel();
    setState(() {
      _model = undo ? _history.undo() : _history.redo();
      _annotations = _history.annotations;
      final sketch = _history.sketch;
      if (sketch != null) {
        _drawDashed = sketch.dashed;
        _suggestionBase = _model.copy();
        _suggestion = ShapeSuggestion(
            sketch.shape ?? ShapePreset.polygon, List.of(sketch.refined));
        _originalShape = List.of(sketch.original);
        _preview = List.of(sketch.original);
      }
      _selectedAnnotations.clear();
      _selectedWall = null;
      _selectedCorner = null;
      _allSelected = false;
      _multiSelect = false;
      _pickedWalls.clear();
      _pickedCorners.clear();
      _groupPreviewWalls = {};
      _duplicateGroup = false;
      _error = null;
    });
  }

  void _fit() {
    _resetFitTap();
    if (_before != null) _cancel();
    final points = [..._model.corners.values];
    for (final note in _annotations.items.values) {
      final size = annotationWorldSize(note);
      points.addAll([
        note.position,
        note.position + DrawingPoint(size.width, size.height)
      ]);
    }
    final panel = !_hideUi && _tool == _Tool.text
        ? _textControlsKey.currentContext?.findRenderObject() as RenderBox?
        : null;
    final viewport = Offset.zero & _viewport;
    var available = [viewport];
    final obstacles = [
      if (!_hideUi && !_toolBounds.isEmpty) _toolBounds.inflate(8),
      if (panel != null)
        Rect.fromLTWH(8, _viewport.height - _contextBottom - panel.size.height,
                _viewport.width - 16, panel.size.height)
            .inflate(8),
    ];
    for (final obstacle in obstacles) {
      available = [
        for (final area in available)
          if (!area.overlaps(obstacle))
            area
          else ...[
            Rect.fromLTRB(area.left, area.top, area.right,
                obstacle.top.clamp(area.top, area.bottom)),
            Rect.fromLTRB(
                area.left,
                obstacle.bottom.clamp(area.top, area.bottom),
                area.right,
                area.bottom),
            Rect.fromLTRB(area.left, area.top,
                obstacle.left.clamp(area.left, area.right), area.bottom),
            Rect.fromLTRB(obstacle.right.clamp(area.left, area.right), area.top,
                area.right, area.bottom),
          ],
      ].where((r) => r.width >= 48 && r.height >= 48).toList();
    }
    (double, DrawingPoint)? camera;
    for (final area in available) {
      final fit = fitDrawingCamera(points, area.width, area.height);
      if (fit != null && (camera == null || fit.$1 > camera.$1)) {
        camera = (fit.$1, fit.$2 + DrawingPoint(area.left, area.top));
      }
    }
    if (camera == null) return;
    final fitted = camera;
    setState(() {
      _scale = fitted.$1;
      _origin = Offset(fitted.$2.x, fitted.$2.y);
      _selectedWall = null;
      _selectedCorner = null;
      _roomSelection = {};
      _selectedAnnotations.clear();
    });
  }

  Future<void> _chooseShape(ShapePreset kind) async {
    _cancel();
    if (kind == ShapePreset.polygon) {
      setState(() => _polygon = true);
      return;
    }
    final spec = await showDialog<ShapeSpec>(
        context: context,
        builder: (_) =>
            ShapeDialog(spec: ShapeSpec(kind, 2000, 1500, 0), unit: _unit));
    if (!mounted || spec == null) return;
    setState(() {
      _preset = spec;
      _presetAnchor =
          world(Offset(_viewport.width * .2, _viewport.height * .2));
      _preview = spec.points(_presetAnchor);
    });
  }

  Future<void> _editPreset() async {
    final spec = await showDialog<ShapeSpec>(
        context: context,
        builder: (_) => ShapeDialog(spec: _preset!, unit: _unit));
    if (!mounted || spec == null) return;
    setState(() {
      _preset = spec;
      _preview = spec.points(_presetAnchor);
    });
  }

  void _placeShape({bool original = false}) {
    final points = _suggestion != null
        ? (original ? _originalShape : _suggestion!.points)
        : _preset != null
            ? _preview
            : [..._polygonPoints, _polygonPoints.first];
    try {
      final next = (_suggestionBase ?? _model).copy();
      next.addPolyline(points, dashed: _drawDashed);
      if (_suggestion != null && !original) {
        _history.commit(_suggestionBase ?? _model,
            annotations: _annotations,
            sketch: SketchRefinement(List.of(_originalShape),
                List.of(_suggestion!.points), _suggestion!.kind,
                dashed: _drawDashed));
      }
      _cancel();
      setState(() {
        _model = next;
        _history.commit(_model);
      });
    } on DrawingConflict catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _straightenChain() async {
    final id = _selectedWall;
    if (id == null || _before != null) return;
    try {
      final (candidate, points) =
          SketchRefinement.straightenChain(_model, id, tolerance: 3 / _scale);
      final accepted = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
                  scrollable: true,
                  title: const Text('Straighten wall chain'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Preview only. Connected endpoints stay fixed.'),
                    SizedBox(
                        height: 200,
                        width: 300,
                        child: LayoutBuilder(builder: (_, bounds) {
                          final fit = fitDrawingCamera(
                              candidate.corners.values.toList(),
                              bounds.maxWidth,
                              bounds.maxHeight)!;
                          return CustomPaint(
                              painter: DrawingPainter(
                                  model: candidate,
                                  origin: Offset(fit.$2.x, fit.$2.y),
                                  scale: fit.$1,
                                  unit: _unit,
                                  preview: points,
                                  previewDashed: _model.walls[id]!.dashed,
                                  showAllMeasurements: true));
                        })),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Apply')),
                  ]));
      if (!mounted || accepted != true) return;
      setState(() {
        _model = candidate;
        _selectedWall = null;
        _selectedCorner = null;
        _history.commit(_model);
        _error = null;
      });
    } on DrawingConflict catch (e) {
      setState(() => _error = e.message);
    }
  }

  void _addRelation(WallRelationKind kind) => setState(() {
        try {
          final pair = _pickedWalls.toList();
          _model.constrain(kind, pair[0], pair[1]);
          _history.commit(_model);
          _error = null;
        } on DrawingConflict catch (e) {
          _error = e.message;
        }
      });

  Future<void> _calibrate() async {
    if (_before != null) _cancel();
    final id = _selectedWall;
    if (id == null) return;
    final value = await showDialog<(double, double?, bool)>(
        context: context,
        builder: (_) => DimensionDialog(
            valueMm: _model.length(id),
            unit: _unit,
            title: 'Known wall length — scale entire plan',
            validateEdit: (values) =>
                _geometryError((next) => next.calibrateFromWall(id, values.$1)),
            showLock: false,
            onUnitChanged: (unit) => setState(() => _unit = unit)));
    if (!mounted || value == null) return;
    setState(() {
      try {
        _model.calibrateFromWall(id, value.$1);
        _history.commit(_model);
        _error = null;
      } on DrawingConflict catch (e) {
        _error = e.message;
      }
    });
  }

  Widget _groupControls() => Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(_allSelected
                ? 'Entire drawing selected'
                : '${_pickedWalls.length} walls · ${_pickedCorners.length} corners selected'),
            const Text('Tap to toggle; drag selected geometry to move.'),
            ChoiceChip(
                label: const Text('Stretch attached walls'),
                selected: _stretchAttached,
                onSelected: _before != null
                    ? null
                    : (v) => setState(() => _stretchAttached = v)),
            ChoiceChip(
                label: const Text('Duplicate selection'),
                selected: _duplicateGroup,
                onSelected: _before != null || _pickedWalls.isEmpty
                    ? null
                    : (v) => setState(() => _duplicateGroup = v)),
            if (_duplicateGroup)
              const Text(
                  'Drag to a clear location. Copies never auto-connect.'),
            PopupMenuButton<WallRelationKind>(
                tooltip: 'Add constraint',
                enabled: _before == null &&
                    _pickedWalls.length == 2 &&
                    _pickedCorners.isEmpty,
                onSelected: _addRelation,
                itemBuilder: (_) => [
                      for (final kind in WallRelationKind.values)
                        PopupMenuItem(value: kind, child: Text(kind.label))
                    ],
                child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Add constraint (2 walls)'))),
            for (final r
                in _model.relations.where((r) => r.touches(_pickedWalls)))
              Text('${r.kind.label} locked'),
            if (_model.relations.any((r) => r.touches(_pickedWalls)))
              TextButton(
                  onPressed: _before != null
                      ? null
                      : () => setState(() {
                            _model.removeRelations(_pickedWalls);
                            _history.commit(_model);
                            _error = null;
                          }),
                  child: const Text('Remove selected relationships')),
            TextButton(
                onPressed: _before != null
                    ? null
                    : () => setState(() {
                          _multiSelect = false;
                          _allSelected = false;
                          _pickedWalls.clear();
                          _pickedCorners.clear();
                          _duplicateGroup = false;
                        }),
                child: const Text('Done selecting')),
          ]);

  bool get _selectionBusy =>
      _before != null ||
      _pointers.isNotEmpty ||
      _navigationLocked ||
      _textEditing ||
      _enteringWallLength ||
      _documents.busy ||
      _suggestion != null ||
      _preset != null ||
      _polygon;

  bool get _canDeleteGeometry {
    if (_selectionBusy) return false;
    if (_allSelected) {
      return _model.walls.isNotEmpty || _annotations.items.isNotEmpty;
    }
    if (_multiSelect) {
      return (_pickedWalls.isNotEmpty || _pickedCorners.isNotEmpty) &&
          _pickedWalls.every(_model.walls.containsKey) &&
          _pickedCorners.every(_model.corners.containsKey);
    }
    if (_roomSelection.isNotEmpty) {
      return _roomSelection.every(_model.walls.containsKey);
    }
    return _model.walls.containsKey(_selectedWall) ||
        _model.corners.containsKey(_selectedCorner);
  }

  Widget _contextDelete() => Tooltip(
      message: 'Delete selected geometry',
      child: TextButton.icon(
          onPressed: _requestDelete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete')));

  Future<void> _requestDelete() async {
    if (!_canDeleteGeometry) return;
    if (!_multiSelect && _roomSelection.isNotEmpty) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text(
                      'Delete connected shape · ${_roomSelection.length} walls?'),
                  content: const Text(
                      'Shared rooms and attached partitions are included. Undo restores the complete shape.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete shape')),
                  ]));
      if (!mounted || confirmed != true) return;
    }
    if (_multiSelect && _pickedCorners.isNotEmpty) {
      final affected = {
        ..._pickedWalls,
        for (final w in _model.walls.values)
          if (_pickedCorners.contains(w.start) ||
              _pickedCorners.contains(w.end))
            w.id
      };
      final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
                  title: Text(
                      'Delete ${affected.length} selected and attached walls?'),
                  content: const Text(
                      'Selected corners also remove attached walls. Undo restores the entire operation.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete group'))
                  ]));
      if (!mounted || ok != true) return;
    }
    if (!_multiSelect && !_allSelected && _selectedCorner != null) {
      final count = _model.walls.values
          .where((w) => w.start == _selectedCorner || w.end == _selectedCorner)
          .length;
      if (count > 1) {
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
                    title: Text('Delete $count connected walls?'),
                    content: const Text(
                        'Deleting this corner removes all attached wall segments. Undo restores them.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete walls'))
                    ]));
        if (!mounted || confirmed != true) return;
      }
    }
    if (_canDeleteGeometry) _deleteSelection();
  }

  Future<void> _splitSelected() async {
    if (_before != null) _cancel();
    final id = _selectedWall;
    if (id == null) return;
    final value = await showDialog<(double, double?, bool)>(
        context: context,
        builder: (_) => DimensionDialog(
            valueMm: _model.length(id) / 2,
            unit: _unit,
            title: 'Split distance from wall start',
            validateEdit: (values) =>
                _geometryError((next) => next.splitWall(id, values.$1)),
            showLock: false,
            onUnitChanged: (unit) => setState(() => _unit = unit)));
    if (!mounted || value == null) return;
    setState(() {
      try {
        final wall = _model.walls[id]!, a = _model.corners[wall.start]!;
        final d = _model.corners[wall.end]! - a;
        _model.splitWall(id, value.$1);
        _selectedCorner =
            _model.nearestCorner(a + d * (value.$1 / d.length), .001);
        _selectedWall = null;
        _history.commit(_model);
        _error = null;
      } on DrawingConflict catch (e) {
        _error = e.message;
      }
    });
  }

  void _joinSelected() => setState(() {
        try {
          _selectedWall = _model.joinAtCorner(_selectedCorner!);
          _selectedCorner = null;
          _history.commit(_model);
          _error = null;
        } on DrawingConflict catch (e) {
          _error = e.message;
        }
      });

  void _deleteSelection() {
    if (!_canDeleteGeometry) return;
    setState(() {
      if (_allSelected) {
        _model = WallNetwork();
        _annotations = DrawingAnnotations();
        _selectedAnnotations.clear();
        _pickedWalls.clear();
        _pickedCorners.clear();
        _multiSelect = false;
      } else if (_multiSelect) {
        _model.deleteGroup(_pickedWalls, _pickedCorners);
        _pickedWalls.clear();
        _pickedCorners.clear();
        _groupPreviewWalls = {};
        _duplicateGroup = false;
      } else if (_roomSelection.isNotEmpty) {
        _model.deleteGroup(_roomSelection, {});
      } else if (_selectedWall != null) {
        _model.deleteWall(_selectedWall!);
      } else if (_selectedCorner != null) {
        _model.deleteCorner(_selectedCorner!);
      }
      _allSelected = false;
      _roomSelection = {};
      _selectedWall = null;
      _selectedCorner = null;
      _error = null;
      _history.commit(_model, annotations: _annotations);
    });
  }

  Future<void> _clearPlan() async {
    if (_before != null) _cancelGesture();
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Clear entire plan?'),
                content: const Text(
                    'All walls and text will be removed. You can restore them with Undo.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear plan'))
                ]));
    if (!mounted || confirmed != true) return;
    _cancel();
    setState(() {
      _model = WallNetwork();
      _annotations = DrawingAnnotations();
      _selectedWall = null;
      _selectedCorner = null;
      _history.commit(_model, annotations: _annotations);
    });
  }

  Widget _pendingControls() => Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(_suggestion != null
                ? !_refinementPreview
                    ? 'Straighten and refine this sketch?'
                    : _suggestion!.kind == ShapePreset.polygon
                        ? 'Refined sketch preview'
                        : 'Suggested ${_suggestion!.kind.label}'
                : _preset != null
                    ? 'Tap to position; drag to resize'
                    : 'Tap polygon corners'),
            if (_suggestion != null) ...[
              if (_originalShape.length > 1 &&
                  (_originalShape.first - _originalShape.last).length > .001 &&
                  (_suggestion!.points.first - _suggestion!.points.last)
                          .length <
                      .001)
                const Text('Preview will join the nearby endpoints.'),
              if (_history.hasSketch) ...[
                IconButton(
                    tooltip: 'Undo',
                    onPressed: _history.canUndo ? () => _restore(true) : null,
                    icon: const Icon(Icons.undo)),
                IconButton(
                    tooltip: 'Redo',
                    onPressed: _history.canRedo ? () => _restore(false) : null,
                    icon: const Icon(Icons.redo)),
              ],
              if (!_refinementPreview)
                FilledButton(
                    onPressed: () => setState(() {
                          _refinementPreview = true;
                          _preview = List.of(_suggestion!.points);
                        }),
                    child: const Text('Yes, Straighten'))
              else
                FilledButton(
                    onPressed: _before != null ? null : _placeShape,
                    child: const Text('Accept refinement')),
              TextButton(
                  onPressed: _before != null
                      ? null
                      : () => _placeShape(original: true),
                  child: Text(_refinementPreview
                      ? 'Cancel refinement'
                      : 'Keep Original')),
            ] else if (_preset != null) ...[
              Text(
                  '${_unit.format(_preset!.width)} × ${_unit.format(_preset!.kind == ShapePreset.square ? _preset!.width : _preset!.height)} · ${_preset!.rotation.toStringAsFixed(1)}°'),
              TextButton(
                  onPressed: _before != null ? null : _editPreset,
                  child: const Text('Dimensions / rotation')),
              FilledButton(
                  onPressed: _before != null ? null : _placeShape,
                  child: const Text('Place shape')),
            ] else
              FilledButton(
                  onPressed: _before == null && _polygonPoints.length >= 3
                      ? _placeShape
                      : null,
                  child: const Text('Finish polygon')),
            TextButton(
                onPressed: _suggestion != null && _history.hasSketch
                    ? () => _restore(true)
                    : _cancel,
                child: Text(
                    _suggestion != null ? 'Discard sketch' : 'Cancel shape')),
          ]);

  Widget _textControls() => AnnotationControls(
      count: _selectedAnnotations.length,
      multi: _multiText,
      onMulti: (value) {
        if (_before != null) return;
        setState(() {
          _multiText = value;
          _tool = _Tool.text;
          _selectedAnnotations.clear();
          _selectedWall = null;
          _selectedCorner = null;
        });
      },
      onEdit: _before == null && _selectedAnnotations.length == 1
          ? () => _editAnnotation(id: _selectedAnnotations.single)
          : null,
      onDuplicate: _before == null && _selectedAnnotations.isNotEmpty
          ? () => _changeAnnotations(duplicate: true)
          : null,
      onDelete: _before == null && _selectedAnnotations.isNotEmpty
          ? _changeAnnotations
          : null);

  Widget _assistanceMenu() => PopupMenuButton<String>(
        tooltip: 'Drawing assistance',
        child: const Tooltip(
            message: 'More drawing tools',
            child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.tune, size: 22),
                      SizedBox(height: 2),
                      Text('More', style: AppTypography.drawingToolLabel)
                    ]))),
        onSelected: (value) {
          if (value == 'normalWall' || value == 'dashedWall') {
            _chooseStroke(false);
            setState(() {
              _drawDashed = value == 'dashedWall';
              _selectedWall = null;
              _selectedCorner = null;
            });
            return;
          }
          if (value == 'help') {
            _showDrawingHelp();
            return;
          }
          if (value == 'tolerance') {
            _chooseAngleTolerance();
            return;
          }
          setState(() {
            if (value == 'align') _alignment = !_alignment;
            if (value == 'recognize') _recognition = !_recognition;
            if (value == 'grid') _gridSnap = !_gridSnap;
            if (value == 'parallel') _parallelSnap = !_parallelSnap;
            if (value == 'angle15') _angleStep = _angleStep == 15 ? null : 15;
          });
        },
        itemBuilder: (_) => [
          CheckedPopupMenuItem(
              value: 'normalWall',
              checked: !_drawDashed,
              child: const Text('Normal wall')),
          CheckedPopupMenuItem(
              value: 'dashedWall',
              checked: _drawDashed,
              child: const Text('Dashed wall')),
          const PopupMenuItem(value: 'help', child: Text('Drawing help')),
          CheckedPopupMenuItem(
              value: 'grid',
              checked: _gridSnap,
              child: Text('Grid snap (${_unit.format(100)})')),
          CheckedPopupMenuItem(
              value: 'angle15',
              checked: _angleStep == 15,
              child: const Text('15° angle increments')),
          CheckedPopupMenuItem(
              value: 'parallel',
              checked: _parallelSnap,
              child: const Text('Parallel / perpendicular')),
          PopupMenuItem(
              value: 'tolerance',
              child: Text('Angle tolerance: $_angleToleranceDegrees°')),
          CheckedPopupMenuItem(
              value: 'recognize',
              checked: _recognition,
              child: const Text('Suggest shape cleanup')),
          CheckedPopupMenuItem(
              value: 'align',
              checked: _alignment,
              child:
                  Text(_alignment ? '90° assistance (on)' : 'Free Angle (on)')),
        ],
      );

  void _chooseTool(_Tool tool) {
    _resetFitTap();
    if (_before != null) _cancel();
    setState(() {
      _roomSelection = {};
      _stroke = [];
      _preview = [];
      _tool = tool;
      _tape = null;
      _selectedAnnotations.clear();
      _multiText = false;
      if (tool == _Tool.text || tool == _Tool.pan || tool == _Tool.tape) {
        _multiSelect = false;
        _pickedWalls.clear();
        _pickedCorners.clear();
        _selectedWall = null;
        _selectedCorner = null;
      }
      _resizeWall = false;
      _error = null;
    });
  }

  void _chooseStroke(bool outline) {
    _chooseTool(_Tool.smart);
    setState(() => _outline = outline);
  }

  void _convertWallType() {
    final id = _selectedWall;
    if (id == null || _before != null || _pointers.isNotEmpty) return;
    setState(() {
      _model.setDashed(id, !_model.walls[id]!.dashed);
      _history.commit(_model);
      _error = null;
    });
  }

  Future<void> _showDrawingHelp() async {
    if (_before != null) _cancelGesture();
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
            child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .8),
                child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Drawing help',
                              style: AppTypography.text14W600Text),
                          for (final tip in const [
                            (
                              'Draw a room',
                              'Drag outside existing rooms to draw. Use Draw for a freehand layout, or Wall for one straight wall. Drag inside a closed room to move its connected walls together.'
                            ),
                            (
                              'Resize and reshape',
                              'Drag the middle of a wall to move it. Drag a corner to reshape it. Connected walls follow.'
                            ),
                            (
                              'Enter an exact size',
                              'Tap a wall measurement, enter the length and tap Apply. Change the unit in the same dialog.'
                            ),
                            (
                              'Add a connected wall',
                              'In Wall, drag from an open endpoint to continue drawing. Tap the endpoint first to move it instead. Hold on a wall or shared corner to add a branch. Drawing assistance switches between 90° help and Free Angle.'
                            ),
                            (
                              'Review a rough sketch',
                              'Straighten previews the cleanup before you accept it. Keep Original leaves your sketch unchanged. A proposed endpoint closure is shown in the preview.'
                            ),
                            (
                              'Move around the plan',
                              'Use two fingers to pan and zoom. Double-tap empty space to fit the plan on screen.'
                            ),
                            (
                              'Correct a mistake',
                              'Use Cancel action during an edit, or Undo after it. Select a wall to delete only that wall.'
                            ),
                            (
                              'Make more space',
                              'Hide UI clears the controls. Show Tools restores them. You can also drag or collapse the existing palette.'
                            ),
                          ]) ...[
                            const SizedBox(height: 16),
                            Text(tip.$1, style: AppTypography.text14W600Text),
                            Text(tip.$2, style: AppTypography.text14),
                          ],
                          const SizedBox(height: 16),
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Back to drawing')),
                        ])))));
  }

  Future<void> _shapes() async {
    if (_before != null) _cancelGesture();
    final value = await showDrawingShapes(context);
    if (!mounted || value == null) return;
    _chooseShape(ShapePreset.values.byName(value));
  }

  Widget _primaryControls() => DrawingToolbarRow(children: [
        drawingTool(
            label: 'Tape',
            tooltip: 'Tape Measure',
            icon: Icons.straighten,
            selected: _tool == _Tool.tape,
            onPressed: () =>
                _chooseTool(_tool == _Tool.tape ? _Tool.smart : _Tool.tape)),
        drawingTool(
            label: 'Undo',
            icon: Icons.undo,
            onPressed: _history.canUndo ? () => _restore(true) : null),
        drawingTool(
            label: 'Redo',
            icon: Icons.redo,
            onPressed: _history.canRedo ? () => _restore(false) : null),
        drawingTool(
            label: 'Fit',
            tooltip: 'Fit to Screen',
            icon: Icons.fit_screen,
            onPressed: _model.walls.isEmpty && _annotations.items.isEmpty
                ? null
                : _fit),
        if (_before != null)
          drawingTool(
              label: 'Cancel',
              tooltip: 'Cancel action',
              icon: Icons.close,
              onPressed: _cancel)
        else
          _assistanceMenu(),
      ]);

  Widget _controls() => _tool == _Tool.tape
      ? DrawingToolbarRow(children: [
          drawingTool(
              label: 'Clear',
              icon: Icons.clear,
              onPressed: _tape == null || _before != null
                  ? null
                  : () => setState(() => _tape = null)),
          drawingTool(
              label: 'Snap',
              tooltip: 'Snap tape endpoints',
              icon: Icons.ads_click,
              selected: _tapeSnap,
              onPressed: _before != null
                  ? null
                  : () => setState(() => _tapeSnap = !_tapeSnap)),
        ])
      : (_suggestion != null || _preset != null || _polygon)
          ? _pendingControls()
          : _multiSelect
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  _groupControls(),
                  DrawingToolbarRow(children: [
                    drawingTool(
                        label: 'Undo',
                        icon: Icons.undo,
                        onPressed:
                            _history.canUndo ? () => _restore(true) : null),
                    drawingTool(
                        label: 'Redo',
                        icon: Icons.redo,
                        onPressed:
                            _history.canRedo ? () => _restore(false) : null),
                    if (_canDeleteGeometry)
                      drawingTool(
                          label: 'Delete',
                          tooltip: 'Delete selected geometry',
                          icon: Icons.delete_outline,
                          onPressed: _requestDelete),
                  ])
                ])
              : DrawingToolbarRow(children: [
                  drawingTool(
                      label: 'Draw',
                      tooltip: 'Freehand drawing',
                      icon: Icons.gesture_outlined,
                      selected: _tool == _Tool.smart && _outline,
                      onPressed: () => _chooseStroke(true)),
                  drawingTool(
                      label: _drawDashed ? 'Dashed' : 'Wall',
                      tooltip: _drawDashed
                          ? 'Single dashed wall'
                          : 'Single straight wall',
                      icon: _drawDashed
                          ? Icons.border_style
                          : Icons.horizontal_rule,
                      selected: _tool == _Tool.smart && !_outline,
                      onPressed: () => _chooseStroke(false)),
                  drawingTool(
                      label: 'Shapes',
                      icon: Icons.category_outlined,
                      onPressed: _shapes),
                  drawingTool(
                      label: 'Pan',
                      tooltip: 'Pan / Zoom',
                      icon: Icons.pan_tool_outlined,
                      selected: _tool == _Tool.pan,
                      onPressed: () => _chooseTool(
                          _tool == _Tool.pan ? _Tool.smart : _Tool.pan)),
                  drawingTool(
                      label: 'Text',
                      icon: Icons.text_fields,
                      selected: _tool == _Tool.text,
                      onPressed: () => _chooseTool(
                          _tool == _Tool.text ? _Tool.smart : _Tool.text)),
                  drawingTool(
                      label: 'Labels',
                      tooltip:
                          _showAllMeasurements ? 'Hide labels' : 'Show labels',
                      icon: _showAllMeasurements
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      selected: _showAllMeasurements,
                      onPressed: _before == null ? _toggleMeasurements : null),
                ]);

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: _allowClose || (!_documents.dirty && !_documents.busy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeWorkspace();
      },
      child: AbsorbPointer(
          absorbing: _documents.busy,
          child: Scaffold(
            appBar: _hideUi
                ? null
                : AppBar(
                    title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('EasyFloor',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                              '${_documents.name}${_documents.dirty ? ' *' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.text12Muted)
                        ]),
                    actions: [
                        IconButton(
                          tooltip: 'Hide UI',
                          onPressed: () => _setUiHidden(true),
                          icon: const Icon(Icons.visibility_off_outlined),
                        ),
                        PopupMenuButton<String>(
                            tooltip: 'Documents',
                            icon: const Icon(Icons.folder_open_outlined),
                            onSelected: (value) {
                              if (value == 'close') {
                                _closeWorkspace();
                              } else {
                                _documents.action(value);
                              }
                            },
                            itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'save', child: Text('Save')),
                                  PopupMenuItem(
                                      value: 'saveAs', child: Text('Save As')),
                                  PopupMenuItem(
                                      value: 'new',
                                      child: Text('New Document')),
                                  PopupMenuItem(
                                      value: 'open',
                                      child: Text('Open Document')),
                                  PopupMenuItem(
                                      value: 'close',
                                      child: Text('Close Document')),
                                ]),
                        PopupMenuButton<String>(
                            tooltip: 'Plan actions',
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) {
                              if (value == 'clear') _clearPlan();
                              if (value == 'multi') {
                                _cancel();
                                setState(() {
                                  _multiSelect = true;
                                  _selectedWall = null;
                                  _selectedCorner = null;
                                });
                              }
                              if (value == 'all') {
                                _cancel();
                                setState(() {
                                  _allSelected = _model.walls.isNotEmpty ||
                                      _annotations.items.isNotEmpty;
                                  _multiSelect = true;
                                  _selectedWall = null;
                                  _selectedCorner = null;
                                  _pickedWalls.addAll(_model.walls.keys);
                                });
                              }
                            },
                            itemBuilder: (_) => [
                                  const PopupMenuItem(
                                      value: 'multi',
                                      child: Text('Multi-select')),
                                  const PopupMenuItem(
                                      value: 'all', child: Text('Select all')),
                                  const PopupMenuItem(
                                      value: 'clear',
                                      child: Text('Clear plan')),
                                ]),
                        PopupMenuButton<DrawingUnit>(
                            tooltip: 'Measurement unit',
                            initialValue: _unit,
                            onSelected: (unit) => setState(() => _unit = unit),
                            itemBuilder: (_) => [
                                  for (final unit in DrawingUnit.values)
                                    PopupMenuItem(
                                        value: unit, child: Text(unit.name))
                                ],
                            child: SizedBox(
                                width: 48,
                                height: 48,
                                child: Center(
                                    child: Text(_unit.symbol,
                                        maxLines: 1,
                                        style: AppTypography.text12)))),
                      ]),
            body: SafeArea(
                child: Column(children: [
              if (_documents.writing) const LinearProgressIndicator(),
              Expanded(child: LayoutBuilder(builder: (context, constraints) {
                _viewport = constraints.biggest;
                return Stack(key: _boardBoundsKey, children: [
                  Positioned.fill(
                    child: ClipRect(
                        child: Listener(
                            onPointerCancel: (event) {
                              _pointers.remove(event.pointer);
                              _pointerPositions.remove(event.pointer);
                              if (_pointers.isEmpty) _navigationLocked = false;
                              if (_navigationLocked &&
                                  _pointerPositions.length > 1) {
                                // A removed touch must not leave a stale pinch span.
                                _captureNavigation();
                              } else {
                                _cancelGesture();
                              }
                              _finishUiToggle();
                            },
                            onPointerMove: (event) {
                              if (_pointerDown != null &&
                                  (event.localPosition - _pointerDown!)
                                          .distance >
                                      6) {
                                _hold?.cancel();
                              }
                              _pointerPositions[event.pointer] =
                                  event.localPosition;
                              if (_navigationLocked &&
                                  _pointerPositions.length > 1) {
                                _update(ScaleUpdateDetails(
                                    pointerCount: _pointerPositions.length,
                                    localFocalPoint: _pointerMidpoint));
                              }
                            },
                            onPointerUp: (event) {
                              _pointers.remove(event.pointer);
                              _pointerPositions.remove(event.pointer);
                              if (_pointers.isEmpty) {
                                if (_navigationLocked && _multiTouch) {
                                  _end(ScaleEndDetails());
                                }
                                _navigationLocked = false;
                              }
                              if (_pointerPositions.length > 1) {
                                _captureNavigation();
                              }
                              _hold?.cancel();
                              _finishUiToggle();
                            },
                            onPointerDown: (event) {
                              _pointers.add(event.pointer);
                              _pointerPositions[event.pointer] =
                                  event.localPosition;
                              if (_pointers.length > 1) {
                                _navigationLocked = true;
                                _captureNavigation();
                                _hold?.cancel();
                                _continueDrawing = false;
                                if (_before == null) {
                                  _start(ScaleStartDetails(
                                      pointerCount: _pointers.length,
                                      localFocalPoint: _pointerMidpoint));
                                }
                                _update(ScaleUpdateDetails(
                                    pointerCount: _pointers.length,
                                    localFocalPoint: _pointerMidpoint));
                                return;
                              }
                              if (_before == null) {
                                _pointerDown = event.localPosition;
                                _pressedSelectedCorner =
                                    _selectedCorner != null &&
                                        _touchTarget(world(event.localPosition))
                                                .corner ==
                                            _selectedCorner;
                                _endpointResizeWall = null;
                                if (_resizeWall &&
                                    _selectedWall != null &&
                                    (_tool == _Tool.smart ||
                                        _tool == _Tool.wall)) {
                                  final wall = _model.walls[_selectedWall];
                                  final corner =
                                      _touchTarget(world(event.localPosition))
                                          .corner;
                                  if (wall != null &&
                                      (corner == wall.start ||
                                          corner == wall.end)) {
                                    _endpointResizeWall = wall.id;
                                  }
                                }
                                _pressedLabel = _labelAt(event.localPosition);
                                if (_tool == _Tool.smart &&
                                    _annotationAt(event.localPosition) !=
                                        null &&
                                    _preset == null &&
                                    !_polygon &&
                                    !_multiSelect) {
                                  _hold?.cancel();
                                  setState(() {
                                    _selectedWall = null;
                                    _selectedCorner = null;
                                  });
                                  return;
                                }
                                if (_tool == _Tool.smart &&
                                    _preset == null &&
                                    !_polygon &&
                                    _suggestion == null &&
                                    !_multiSelect) {
                                  setState(() {
                                    final p = world(event.localPosition);
                                    final target = _pressedLabel == null
                                        ? _touchTarget(p)
                                        : (corner: null, wall: _pressedLabel);
                                    if (target.corner != null ||
                                        target.wall != null) {
                                      _roomSelection = {};
                                    }
                                    _selectedCorner = target.corner;
                                    final previousWall = _selectedWall;
                                    _selectedWall = _endpointResizeWall ??
                                        (_selectedCorner == null
                                            ? target.wall ??
                                                _labelAt(event.localPosition)
                                            : null);
                                    if (_pressedLabel == null &&
                                        (_selectedWall != null ||
                                            _selectedCorner != null)) {
                                      _hold?.cancel();
                                      _hold = Timer(
                                          const Duration(milliseconds: 450),
                                          () {
                                        if (!mounted ||
                                            _before != null ||
                                            _pointers.length != 1) {
                                          return;
                                        }
                                        setState(() {
                                          _continueDrawing = true;
                                          _connection =
                                              _snap(world(event.localPosition));
                                        });
                                      });
                                    }
                                    if (previousWall != _selectedWall) {
                                      _resizeWall = false;
                                      _resizeAnchor = WallResizeAnchor.start;
                                    }
                                  });
                                }
                              }
                            },
                            child: RawGestureDetector(
                                key: const ValueKey('drawingCanvas'),
                                behavior: HitTestBehavior.opaque,
                                gestures: {
                                  TapGestureRecognizer:
                                      GestureRecognizerFactoryWithHandlers<
                                              TapGestureRecognizer>(
                                          () => TapGestureRecognizer(),
                                          (recognizer) => recognizer
                                            ..gestureSettings =
                                                DeviceGestureSettings(
                                                    touchSlop: widget
                                                        .drawingMovementThreshold)
                                            ..onTapUp = _select),
                                  ScaleGestureRecognizer:
                                      GestureRecognizerFactoryWithHandlers<
                                              ScaleGestureRecognizer>(
                                          () => ScaleGestureRecognizer(),
                                          (recognizer) => recognizer
                                            ..dragStartBehavior =
                                                DragStartBehavior.start
                                            ..gestureSettings =
                                                DeviceGestureSettings(
                                                    touchSlop: widget
                                                            .drawingMovementThreshold /
                                                        2)
                                            ..onStart = _start
                                            ..onUpdate = _update
                                            ..onEnd = _end),
                                },
                                child: CustomPaint(
                                    size: constraints.biggest,
                                    foregroundPainter: AnnotationPainter(
                                        annotations: _annotations,
                                        origin: _origin,
                                        scale: _scale,
                                        bounds: _annotationBounds,
                                        onEdit: _tool == _Tool.tape
                                            ? null
                                            : (id) => _editAnnotation(id: id),
                                        selected: _allSelected
                                            ? _annotations.items.keys.toSet()
                                            : _selectedAnnotations),
                                    painter: DrawingPainter(
                                        previewDashed: _drawDashed,
                                        tape: _tape,
                                        model: _model,
                                        allSelected: _allSelected,
                                        highlightedCorners: _pickedCorners,
                                        contextWalls: _before != null &&
                                                _gestureTool == _Tool.group
                                            ? {
                                                ..._roomSelection,
                                                ...(_groupPreviewWalls.isEmpty
                                                    ? _pickedWalls
                                                    : _groupPreviewWalls),
                                                for (final w
                                                    in _model.walls.values)
                                                  if (_pickedCorners
                                                          .contains(w.start) ||
                                                      _pickedCorners
                                                          .contains(w.end))
                                                    w.id
                                              }
                                            : _before != null &&
                                                    _gestureTool == _Tool.wall
                                                ? {
                                                    if (_selectedWall != null &&
                                                        _model.walls
                                                            .containsKey(
                                                                _selectedWall))
                                                      ..._model.straightRun(
                                                          _selectedWall!),
                                                    for (final w
                                                        in _model.walls.values)
                                                      if (_before!.walls
                                                              .containsKey(
                                                                  w.id) &&
                                                          (_model.length(w.id) -
                                                                      _before!.length(
                                                                          w.id))
                                                                  .abs() >
                                                              .001)
                                                        w.id
                                                  }
                                                : const {},
                                        highlightedWalls:
                                            _roomSelection.isNotEmpty
                                                ? _roomSelection
                                                : _multiSelect
                                                    ? {
                                                        ..._pickedWalls,
                                                        ..._groupPreviewWalls
                                                      }
                                                    : _selectedWall != null &&
                                                            _model.walls.containsKey(
                                                                _selectedWall)
                                                        ? _before != null &&
                                                                _gestureTool ==
                                                                    _Tool.wall
                                                            ? _model.straightRun(
                                                                _selectedWall!)
                                                            : {_selectedWall!}
                                                        : const {},
                                        rawStroke: _suggestion != null
                                            ? _originalShape
                                            : _stroke,
                                        presetDimensions: _preset == null
                                            ? null
                                            : '${_unit.format(_preset!.width)} × ${_unit.format(_preset!.kind == ShapePreset.square ? _preset!.width : _preset!.height)}',
                                        presetHandle: _presetHandle,
                                        showResizeAnchors:
                                            _resizeWall || _enteringWallLength,
                                        anglesEnabled: !_allSelected &&
                                            _tool != _Tool.tape,
                                        labelBounds: _labels,
                                        // Panels finish layout after this painter is constructed.
                                        interfaceObstacles:
                                            _measurementInterfaceObstacles,
                                        labelObstacles: [
                                          if (!_hideUi && !_toolBounds.isEmpty)
                                            _toolBounds,
                                          for (final note
                                              in _annotations.items.values)
                                            (_origin +
                                                    Offset(
                                                        note.position.x *
                                                            _scale,
                                                        note.position.y *
                                                            _scale)) &
                                                (annotationWorldSize(note) *
                                                    _scale)
                                        ],
                                        editingActive:
                                            _before != null && !_multiTouch,
                                        connection: _connection,
                                        guides: _guides,
                                        editingCorner: _before != null &&
                                            (_gestureTool == _Tool.corner ||
                                                (_gestureTool == _Tool.group &&
                                                    _pickedCorners
                                                        .isNotEmpty)) &&
                                            !_multiTouch,
                                        navigationActive: _before != null &&
                                            (_multiTouch ||
                                                _gestureTool == _Tool.pan),
                                        guideOpacity: widget.guideOpacity,
                                        showAllMeasurements:
                                            _showAllMeasurements,
                                        labelOffsets: _labelOffsets,
                                        finger: _finger,
                                        moveOffset: _moveOffset,
                                        origin: _origin,
                                        scale: _scale,
                                        unit: _unit,
                                        preview: _preview,
                                        selectedWall:
                                            _multiSelect ? null : _selectedWall,
                                        selectedCorner:
                                            _multiSelect ? null : _selectedCorner))))),
                  ),
                  Positioned.fill(
                    child: Offstage(
                      offstage: _hideUi,
                      child: Stack(children: [
                        if (_model.walls.isEmpty &&
                            _annotations.items.isEmpty &&
                            _before == null &&
                            _pointers.isEmpty &&
                            _suggestion == null &&
                            _preset == null &&
                            !_polygon &&
                            !_multiSelect &&
                            _tool == _Tool.smart)
                          Positioned(
                            top: constraints.maxHeight * .18,
                            left: 24,
                            right: 24,
                            child: const IgnorePointer(
                              child: Column(children: [
                                Text('Sketch your first room',
                                    style: AppTypography.text14W600Text),
                                SizedBox(height: 8),
                                Text(
                                    'Drag to draw. Touch a wall or corner to edit.\nTwo fingers to pan and zoom.',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.text12Muted),
                              ]),
                            ),
                          ),
                        if ((_tool == _Tool.text ||
                                _selectedAnnotations.isNotEmpty) &&
                            _before == null &&
                            _preset == null &&
                            !_polygon &&
                            _suggestion == null)
                          Positioned(
                              left: 8,
                              right: 8,
                              bottom: _contextBottom,
                              child: _contextPanel(_textControlsKey,
                                  child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                          maxHeight:
                                              constraints.maxHeight * .4),
                                      child: SingleChildScrollView(
                                          child: _textControls())))),
                        if (!_multiSelect &&
                            _selectedWall != null &&
                            _model.walls.containsKey(_selectedWall) &&
                            _before == null)
                          Positioned(
                              left: 8,
                              right: 8,
                              bottom: _contextBottom,
                              child: _contextPanel(_wallControlsKey,
                                  child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                          maxHeight:
                                              constraints.maxHeight * .45),
                                      child: SingleChildScrollView(
                                          child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12),
                                              child: Wrap(
                                                  spacing: 8,
                                                  crossAxisAlignment:
                                                      WrapCrossAlignment.center,
                                                  children: [
                                                    Text(
                                                        'Selected wall · ${_unit.format(_model.length(_selectedWall!))}',
                                                        style: AppTypography
                                                            .text14W600Text),
                                                    if (_canDeleteGeometry)
                                                      _contextDelete(),
                                                    TextButton.icon(
                                                        onPressed:
                                                            _canDeleteGeometry
                                                                ? _toggleWallLock
                                                                : null,
                                                        icon: Icon(_model.isFixed(
                                                                _selectedWall!)
                                                            ? Icons.lock
                                                            : Icons.lock_open),
                                                        label: Text(_model.isFixed(
                                                                _selectedWall!)
                                                            ? 'Unlock length'
                                                            : 'Lock length')),
                                                    TextButton(
                                                        onPressed: _dimensions,
                                                        child: const Text(
                                                            'Enter length')),
                                                    SizedBox(
                                                      width: double.infinity,
                                                      child: ExpansionTile(
                                                        title: const Text(
                                                            'More wall options'),
                                                        children: [
                                                          Wrap(
                                                            spacing: 8,
                                                            crossAxisAlignment:
                                                                WrapCrossAlignment
                                                                    .center,
                                                            children: [
                                                              TextButton.icon(
                                                                  onPressed:
                                                                      _convertWallType,
                                                                  icon: Icon(_model
                                                                          .walls[
                                                                              _selectedWall!]!
                                                                          .dashed
                                                                      ? Icons
                                                                          .horizontal_rule
                                                                      : Icons
                                                                          .border_style),
                                                                  label: Text(_model
                                                                          .walls[
                                                                              _selectedWall!]!
                                                                          .dashed
                                                                      ? 'Make normal'
                                                                      : 'Make dashed')),
                                                              TextButton(
                                                                  onPressed: () =>
                                                                      _dimensions(
                                                                          advanced:
                                                                              true),
                                                                  child: const Text(
                                                                      'Resize options')),
                                                              if (_model.rectangle(
                                                                      _selectedWall!) !=
                                                                  null)
                                                                TextButton(
                                                                    onPressed: () =>
                                                                        _dimensions(
                                                                            rectangle:
                                                                                true),
                                                                    child: const Text(
                                                                        'Room width / length')),
                                                              TextButton(
                                                                  onPressed:
                                                                      _splitSelected,
                                                                  child: const Text(
                                                                      'Split wall')),
                                                              TextButton(
                                                                  onPressed:
                                                                      _straightenChain,
                                                                  child: const Text(
                                                                      'Straighten wall chain')),
                                                              for (final span
                                                                  in _model
                                                                      .fixedSpans(
                                                                          _selectedWall!))
                                                                Text(
                                                                    'Fixed measured span: ${_unit.format(span)}',
                                                                    style: AppTypography
                                                                        .text12Muted),
                                                              ChoiceChip(
                                                                  label: const Text(
                                                                      'Drag length'),
                                                                  selected:
                                                                      _resizeWall,
                                                                  onSelected: (value) =>
                                                                      setState(() =>
                                                                          _resizeWall =
                                                                              value)),
                                                              if (_resizeWall)
                                                                WallResizeOptions(
                                                                    value:
                                                                        _resizeAnchor,
                                                                    onChanged: (mode) =>
                                                                        setState(() =>
                                                                            _resizeAnchor =
                                                                                mode)),
                                                              Text(_model
                                                                      .calibrated
                                                                  ? 'Plan scale calibrated'
                                                                  : 'Sketch scale — set a known dimension'),
                                                              TextButton(
                                                                  onPressed:
                                                                      _calibrate,
                                                                  child: const Text(
                                                                      'Calibrate plan')),
                                                              for (final r in _model
                                                                  .relations
                                                                  .where((r) =>
                                                                      r.touches({
                                                                        _selectedWall!
                                                                      })))
                                                                Text(
                                                                    '${r.kind.label} locked'),
                                                              if (_model
                                                                  .relations
                                                                  .any((r) =>
                                                                      r.touches({
                                                                        _selectedWall!
                                                                      })))
                                                                TextButton(
                                                                    onPressed: () =>
                                                                        setState(
                                                                            () {
                                                                          _model
                                                                              .removeRelations({
                                                                            _selectedWall!
                                                                          });
                                                                          _history
                                                                              .commit(_model);
                                                                        }),
                                                                    child: const Text(
                                                                        'Remove relationships')),
                                                            ],
                                                          )
                                                        ],
                                                      ),
                                                    ),
                                                  ])))))),
                        if (!_multiSelect &&
                            _selectedCorner != null &&
                            _model.corners.containsKey(_selectedCorner) &&
                            _before == null)
                          Positioned(
                              left: 8,
                              right: 8,
                              bottom: _contextBottom,
                              child: _contextPanel(_cornerControlsKey,
                                  child: Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        const Text('Selected corner'),
                                        if (_canDeleteGeometry)
                                          _contextDelete(),
                                        if (_model
                                            .isStraightCorner(_selectedCorner!))
                                          TextButton(
                                              onPressed: _joinSelected,
                                              child: const Text(
                                                  'Join straight segments')),
                                      ]))),
                        if (_roomSelection.isNotEmpty &&
                            !_multiSelect &&
                            _before == null)
                          Positioned(
                              left: 8,
                              right: 8,
                              bottom: _contextBottom,
                              child: _contextPanel(_roomControlsKey,
                                  child: Wrap(
                                      spacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                            'Connected shape · ${_roomSelection.length} walls',
                                            style:
                                                AppTypography.text14W600Text),
                                        if (_canDeleteGeometry)
                                          _contextDelete(),
                                        TextButton.icon(
                                            onPressed: _selectionBusy
                                                ? null
                                                : _toggleRoomLengthLocks,
                                            icon: Icon(_roomLengthsLocked
                                                ? Icons.lock
                                                : Icons.lock_open),
                                            label: Text(_roomLengthsLocked
                                                ? 'Unlock lengths'
                                                : 'Lock lengths')),
                                      ]))),
                        if (!_toolsExpanded &&
                            (_suggestion != null ||
                                _preset != null ||
                                _polygon))
                          Positioned(
                              left: 8,
                              right: 8,
                              bottom: _contextBottom,
                              child: _contextPanel(_sketchControlsKey,
                                  child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                          maxHeight:
                                              constraints.maxHeight * .45),
                                      child: SingleChildScrollView(
                                          child: Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: _pendingControls()))))),
                        DrawingToolPalette(
                            primaryControls: (_suggestion == null &&
                                    _preset == null &&
                                    !_polygon &&
                                    !_multiSelect)
                                ? _primaryControls()
                                : null,
                            viewport: constraints.biggest,
                            onBoundsChanged: (bounds) {
                              if (_toolBounds != bounds) {
                                setState(() => _toolBounds = bounds);
                              }
                            },
                            onExpandedChanged: (expanded) =>
                                setState(() => _toolsExpanded = expanded),
                            onInteract: () {
                              if (_before != null) _cancelGesture();
                            },
                            child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: _controls())),
                      ]),
                    ),
                  ),
                  if (_hideUi)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filledTonal(
                        tooltip: 'Show Tools',
                        constraints:
                            const BoxConstraints(minWidth: 48, minHeight: 48),
                        visualDensity: VisualDensity.standard,
                        onPressed: () => _setUiHidden(false),
                        icon: const Icon(Icons.handyman_outlined),
                      ),
                    ),
                  if (_error != null)
                    Positioned(
                        left: 8,
                        right: _hideUi ? 64 : 8,
                        top: (_hideUi ? kToolbarHeight : 0) +
                            20 +
                            MediaQuery.textScalerOf(context).scale(12) * 5.2,
                        child: IgnorePointer(
                            child: Material(
                                color: AppColors.white,
                                child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(_error!,
                                        style: AppTypography.text14Secondarytext
                                            .copyWith(
                                                color: AppColors.error)))))),
                  Positioned(
                      top: _hideUi ? kToolbarHeight + 8 : 8,
                      left: 8,
                      child: const BoardDirections()),
                ]);
              })),
            ])),
          )));
}
