import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import '../models/room.dart';
import '../models/door.dart';
import '../models/resize_handle.dart';
import '../utils/path_utils.dart';
import '../utils/wall_outline.dart';
import '../utils/room_dimensions.dart';
import '../utils/plan_snapshot.dart';
import '../utils/wall_dimensions.dart';
import 'wall_size_dialog.dart';
import '../utils/svg_parser.dart';
import '../utils/web_download_helper.dart';
import 'floor_painter.dart';

/// Main floor plan editor widget
class FloorPlanEditor extends StatefulWidget {
  /// Optional callback when rooms or doors change
  final Function(List<Room> rooms, List<Door> doors)? onChanged;

  /// Optional callback when save is triggered
  final Function(String svgContent)? onSave;

  /// Initial rooms to load
  final List<Room>? initialRooms;

  /// Initial doors to load
  final List<Door>? initialDoors;

  /// Canvas background color
  final Color? canvasColor;

  /// Show top toolbar
  final bool showToolbar;

  /// Show sidebars
  final bool showSidebars;

  const FloorPlanEditor({
    super.key,
    this.onChanged,
    this.onSave,
    this.initialRooms,
    this.initialDoors,
    this.canvasColor,
    this.showToolbar = true,
    this.showSidebars = true,
  });

  @override
  State<FloorPlanEditor> createState() => _FloorPlanEditorState();
}

class _FloorPlanEditorState extends State<FloorPlanEditor> {
  late List<Room> rooms;
  late List<Door> doors;
  Room? selectedRoom;
  Door? selectedDoor;

  Path? drawingPath;
  final List<Offset> _drawingPoints = [];
  bool pencilMode = false;
  bool doorPlacementMode = false;

  Offset? lastPanPosition;
  ResizeHandle? activeHandle;
  int? _outlinePointer;
  bool _outlineMultiTouch = false;
  Offset? _outlinePosition;
  int? _wallHandle;
  int? _cornerHandle;
  String? _dragError;
  bool _editingGesture = false;
  final List<PlanSnapshot> _history = [];
  int _historyIndex = 0;
  Rect? startBounds;

  Color? selectedColor;
  int _roomCounter = 1;

  // Color palette
  static const List<Color> colorPalette = [
    Color(0xFF2196F3), // Blue
    Color(0xFF4CAF50), // Green
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFFF44336), // Red
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFFEB3B), // Yellow
    Color(0xFF795548), // Brown
    Color(0xFF9E9E9E), // Grey
    Color(0xFFF5F5DC), // Beige (default)
  ];

  @override
  void initState() {
    super.initState();
    rooms = widget.initialRooms ?? [];
    doors = widget.initialDoors ?? [];
    _roomCounter = rooms.length + 1;
    _history.add(PlanSnapshot(rooms, doors, _roomCounter));
  }

  void _finishOutline() {
    try {
      final points = WallOutline.straighten(_drawingPoints);
      if (points.isEmpty)
        throw ArgumentError(
            'Draw at least three clear walls to create a room.');
      WallDimensions.validate(points);
      final room = Room(
          id: UniqueKey().toString(),
          path: Path()..addPolygon(points, true),
          wallPoints: points,
          fillColor: selectedColor,
          name: 'Room $_roomCounter');
      setState(() {
        rooms.add(room);
        selectedRoom = room;
        selectedDoor = null;
        pencilMode = false;
        drawingPath = null;
        _drawingPoints.clear();
        _roomCounter++;
        _notifyChanged();
      });
    } on ArgumentError catch (error) {
      setState(() {
        drawingPath = null;
        _drawingPoints.clear();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${error.message}')));
    }
  }

  void _notifyChanged() {
    if (!_editingGesture) _checkpoint();
    widget.onChanged?.call(rooms, doors);
  }

  void _checkpoint() {
    final next = PlanSnapshot(rooms, doors, _roomCounter);
    if (next.signature == _history[_historyIndex].signature) return;
    _history.removeRange(_historyIndex + 1, _history.length);
    _history.add(next);
    if (_history.length > 31) _history.removeAt(0);
    _historyIndex = _history.length - 1;
    if (mounted) setState(() {});
  }

  void _restoreHistory(int index) {
    setState(() {
      _historyIndex = index;
      final snapshot = _history[index];
      rooms = snapshot.rooms.map(PlanSnapshot.copyRoom).toList();
      doors = snapshot.doors.map(PlanSnapshot.copyDoor).toList();
      _roomCounter = snapshot.counter;
      selectedRoom = null;
      selectedDoor = null;
      drawingPath = null;
      _drawingPoints.clear();
      pencilMode = false;
      _editingGesture = false;
      _outlinePointer = null;
      widget.onChanged?.call(rooms, doors);
    });
  }

  String? _findNearestEdge(Offset pos, Room room) {
    final bounds = room.path.getBounds();
    const threshold = 15.0;

    final distToTop = (pos.dy - bounds.top).abs();
    final distToBottom = (pos.dy - bounds.bottom).abs();
    final distToLeft = (pos.dx - bounds.left).abs();
    final distToRight = (pos.dx - bounds.right).abs();

    final onTopEdge = distToTop < threshold &&
        pos.dx >= bounds.left &&
        pos.dx <= bounds.right;
    final onBottomEdge = distToBottom < threshold &&
        pos.dx >= bounds.left &&
        pos.dx <= bounds.right;
    final onLeftEdge = distToLeft < threshold &&
        pos.dy >= bounds.top &&
        pos.dy <= bounds.bottom;
    final onRightEdge = distToRight < threshold &&
        pos.dy >= bounds.top &&
        pos.dy <= bounds.bottom;

    if (onTopEdge &&
        distToTop <= distToBottom &&
        distToTop <= distToLeft &&
        distToTop <= distToRight) {
      return 'top';
    }
    if (onBottomEdge &&
        distToBottom <= distToTop &&
        distToBottom <= distToLeft &&
        distToBottom <= distToRight) {
      return 'bottom';
    }
    if (onLeftEdge &&
        distToLeft <= distToTop &&
        distToLeft <= distToBottom &&
        distToLeft <= distToRight) {
      return 'left';
    }
    if (onRightEdge &&
        distToRight <= distToTop &&
        distToRight <= distToBottom &&
        distToRight <= distToLeft) {
      return 'right';
    }

    return null;
  }

  void selectRoom(Offset pos) {
    if (_outlinePointer != null) return;
    _wallHandle = null;
    _cornerHandle = null;
    if (doorPlacementMode && selectedRoom != null) {
      final edge = _findNearestEdge(pos, selectedRoom!);
      if (edge != null) {
        addDoorToRoomAtEdge(selectedRoom!, edge, pos);
        setState(() {
          doorPlacementMode = false;
        });
        return;
      }
    }

    for (final d in doors.reversed) {
      if (d.path.contains(pos)) {
        setState(() {
          selectedDoor = d;
          selectedRoom = null;
          activeHandle = null;
          doorPlacementMode = false;
        });
        return;
      }
    }

    for (final r in rooms.reversed) {
      final points = r.wallPoints;
      if (points != null && r == selectedRoom) {
        for (var i = 0; i < points.length; i++) {
          if ((pos - points[i]).distance <= 22) {
            _cornerHandle = i;
            break;
          }
        }
        if (_cornerHandle == null) {
          for (var i = 0; i < points.length; i++) {
            if ((pos - (points[i] + points[(i + 1) % points.length]) / 2)
                    .distance <=
                22) {
              _wallHandle = i;
              break;
            }
          }
        }
        if (_wallHandle != null || _cornerHandle != null) {
          activeHandle = null;
          selectedDoor = null;
          return;
        }
      }
      final bounds = r.path.getBounds();
      final handle =
          points == null ? PathUtils.hitTestHandle(pos, bounds) : null;
      if (handle != null) {
        selectedRoom = r;
        selectedDoor = null;
        activeHandle = handle;
        startBounds = bounds;
        doorPlacementMode = false;
        setState(() {});
        return;
      }
      if (r.path.contains(pos)) {
        selectedRoom = r;
        selectedDoor = null;
        activeHandle = null;
        doorPlacementMode = false;
        setState(() {});
        return;
      }
    }
    setState(() {
      selectedRoom = null;
      selectedDoor = null;
      activeHandle = null;
      doorPlacementMode = false;
    });
  }

  void _dragOutline(Offset delta) {
    try {
      setState(() {
        if (_cornerHandle != null) {
          WallDimensions.moveCorner(
              selectedRoom!, doors, _cornerHandle!, delta);
        } else {
          final points = selectedRoom!.wallPoints!;
          final direction =
              points[(_wallHandle! + 1) % points.length] - points[_wallHandle!];
          final along = (delta.dx * direction.dx + delta.dy * direction.dy) /
              direction.distance;
          WallDimensions.resize(selectedRoom!, doors, _wallHandle!,
              (direction.distance + along) * 10);
        }
        _dragError = null;
        _notifyChanged();
      });
    } on ArgumentError catch (error) {
      _dragError = '${error.message}';
    }
  }

  void resizeRoom(Offset delta) {
    if (selectedRoom == null || activeHandle == null || startBounds == null) {
      return;
    }

    final bounds = selectedRoom!.path.getBounds();
    double sx = 1, sy = 1;
    Offset anchor = bounds.center;

    if (activeHandle == ResizeHandle.bottomRight) {
      sx = (bounds.width + delta.dx) / bounds.width;
      sy = (bounds.height + delta.dy) / bounds.height;
      anchor = bounds.topLeft;
    } else if (activeHandle == ResizeHandle.topLeft) {
      sx = (bounds.width - delta.dx) / bounds.width;
      sy = (bounds.height - delta.dy) / bounds.height;
      anchor = bounds.bottomRight;
    } else if (activeHandle == ResizeHandle.topRight) {
      sx = (bounds.width + delta.dx) / bounds.width;
      sy = (bounds.height - delta.dy) / bounds.height;
      anchor = bounds.bottomLeft;
    } else if (activeHandle == ResizeHandle.bottomLeft) {
      sx = (bounds.width - delta.dx) / bounds.width;
      sy = (bounds.height + delta.dy) / bounds.height;
      anchor = bounds.topRight;
    } else if (activeHandle == ResizeHandle.right) {
      sx = (bounds.width + delta.dx) / bounds.width;
      anchor = bounds.centerLeft;
    } else if (activeHandle == ResizeHandle.left) {
      sx = (bounds.width - delta.dx) / bounds.width;
      anchor = bounds.centerRight;
    } else if (activeHandle == ResizeHandle.top) {
      sy = (bounds.height - delta.dy) / bounds.height;
      anchor = bounds.bottomCenter;
    } else if (activeHandle == ResizeHandle.bottom) {
      sy = (bounds.height + delta.dy) / bounds.height;
      anchor = bounds.topCenter;
    }

    if (sx > 0.2 && sy > 0.2) {
      RoomDimensions.scale(selectedRoom!, doors, sx, sy, anchor);
    }

    setState(() {
      _notifyChanged();
    });
  }

  void moveSelected(Offset delta) {
    if (selectedRoom != null) {
      setState(() {
        RoomDimensions.move(selectedRoom!, doors, delta);
        _notifyChanged();
      });
    } else if (selectedDoor != null) {
      setState(() {
        selectedDoor!.path = selectedDoor!.path.shift(delta);
        _notifyChanged();
      });
    }
  }

  void rotateSelected() {
    if (selectedRoom != null) {
      final bounds = selectedRoom!.path.getBounds();
      setState(() {
        selectedRoom!.path =
            PathUtils.rotatePath(selectedRoom!.path, 90, bounds.center);
        selectedRoom!.wallPoints = selectedRoom!.wallPoints
            ?.map((p) => Offset(bounds.center.dx - (p.dy - bounds.center.dy),
                bounds.center.dy + (p.dx - bounds.center.dx)))
            .toList();
        for (var i = 0; i < selectedRoom!.doorOpenings.length; i++) {
          selectedRoom!.doorOpenings[i] = PathUtils.rotatePath(
            selectedRoom!.doorOpenings[i],
            90,
            bounds.center,
          );
        }
        for (final door in doors) {
          if (selectedRoom!.doorOpenings.any(
            (opening) =>
                (opening.getBounds().center - door.path.getBounds().center)
                    .distance <
                5,
          )) {
            door.path = PathUtils.rotatePath(door.path, 90, bounds.center);
            door.rotation = (door.rotation + 90) % 360;
          }
        }
        _notifyChanged();
      });
    } else if (selectedDoor != null) {
      final bounds = selectedDoor!.path.getBounds();
      setState(() {
        selectedDoor!.path =
            PathUtils.rotatePath(selectedDoor!.path, 90, bounds.center);
        selectedDoor!.rotation = (selectedDoor!.rotation + 90) % 360;
        _notifyChanged();
      });
    }
  }

  void addDoorToRoom(Room room) {
    setState(() {
      doorPlacementMode = true;
      selectedRoom = room;
    });
  }

  void addDoorToRoomAtEdge(Room room, String edge, Offset clickPos) {
    final bounds = room.path.getBounds();
    Offset doorCenter;
    Path doorPath;

    switch (edge) {
      case 'top':
        doorCenter = Offset(
          clickPos.dx.clamp(bounds.left + 25, bounds.right - 25),
          bounds.top,
        );
        doorPath = PathUtils.createDoor(doorCenter, width: 50, height: 12);
        break;
      case 'bottom':
        doorCenter = Offset(
          clickPos.dx.clamp(bounds.left + 25, bounds.right - 25),
          bounds.bottom,
        );
        doorPath = PathUtils.createDoor(doorCenter, width: 50, height: 12);
        break;
      case 'left':
        doorCenter = Offset(
          bounds.left,
          clickPos.dy.clamp(bounds.top + 25, bounds.bottom - 25),
        );
        doorPath = PathUtils.createDoor(doorCenter, width: 12, height: 50);
        break;
      case 'right':
        doorCenter = Offset(
          bounds.right,
          clickPos.dy.clamp(bounds.top + 25, bounds.bottom - 25),
        );
        doorPath = PathUtils.createDoor(doorCenter, width: 12, height: 50);
        break;
      default:
        return;
    }

    setState(() {
      room.path = PathUtils.cutDoorFromRoom(room.path, doorPath);
      room.doorOpenings.add(doorPath);
      doors.add(
        Door(
          id: UniqueKey().toString(),
          path: doorPath,
          roomId: room.id,
          edge: edge,
        ),
      );
      _notifyChanged();
    });
  }

  Future<void> _openSVG() async {
    try {
      FilePickerResult? result;

      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['svg'],
        withData: true,
      );
      if (!mounted) return;
      if (result != null && result.files.isNotEmpty) {
        final bytes = result.files.single.bytes;
        if (bytes == null) {
          throw const FormatException('Could not read SVG file');
        }
        final svgContent = utf8.decode(bytes);
        final parseResult = SvgParser.loadFromSVG(svgContent);
        setState(() {
          rooms.clear();
          doors.clear();
          rooms.addAll(parseResult['rooms'] as List<Room>);
          doors.addAll(parseResult['doors'] as List<Door>);
          selectedRoom = null;
          selectedDoor = null;
          _roomCounter = parseResult['roomCounter'] as int;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Floor plan loaded successfully'),
            duration: Duration(seconds: 2),
          ),
        );
        _notifyChanged();
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error opening file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _downloadSVG() async {
    if (rooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No rooms to export'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      final svgContent = SvgParser.generateSVG(rooms, doors);
      widget.onSave?.call(svgContent);

      await WebDownloadHelper().downloadSVG(svgContent, 'floor_plan.svg');
      if (!mounted) return;
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Floor plan downloaded as SVG')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error generating SVG: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting SVG: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 760;
    return Scaffold(
      appBar: AppBar(
        title: const Text('EasyFloor'),
        leading:
            ModalRoute.of(context)?.canPop == true ? const BackButton() : null,
        actions: [
          if (narrow && widget.showSidebars) ...[
            Builder(
                builder: (context) => IconButton(
                      tooltip: 'Tools',
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    )),
            Builder(
                builder: (context) => IconButton(
                      tooltip: 'Room shapes',
                      icon: const Icon(Icons.add_box_outlined),
                      onPressed: () => Scaffold.of(context).openEndDrawer(),
                    )),
          ],
        ],
      ),
      drawer: narrow && widget.showSidebars
          ? Drawer(
              child:
                  SafeArea(child: SingleChildScrollView(child: _leftSidebar())))
          : null,
      endDrawer: narrow && widget.showSidebars
          ? Drawer(child: SafeArea(child: _rightSidebar()))
          : null,
      backgroundColor: Colors.grey.shade100,
      body: Row(
        children: [
          if (widget.showSidebars && !narrow) _leftSidebar(),
          Expanded(
            child: Column(
              children: [
                if (widget.showToolbar) _topBar(),
                if (selectedRoom != null || selectedDoor != null)
                  _contextualBar(),
                if (doorPlacementMode && selectedRoom != null)
                  Container(
                    constraints: const BoxConstraints(minHeight: 40),
                    color: Colors.orange.shade100,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Expanded(
                            child: Text(
                          "Click on a border edge to place the door",
                          style: TextStyle(color: Colors.orange),
                        )),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              doorPlacementMode = false;
                            });
                          },
                          child: const Text("Cancel"),
                        ),
                      ],
                    ),
                  ),
                if (pencilMode)
                  Container(
                    constraints: const BoxConstraints(minHeight: 40),
                    color: Colors.blue.shade100,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.edit, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Expanded(
                            child: Text(
                          "Draw an outline. Walls straighten when you release.",
                          style: TextStyle(color: Colors.blue),
                        )),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              pencilMode = false;
                              drawingPath = null;
                            });
                          },
                          child: const Text("Cancel"),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Container(
                    color: widget.canvasColor ?? const Color(0xFFE3F2FD),
                    child: InteractiveViewer(
                      panEnabled: selectedRoom == null && !pencilMode,
                      minScale: 0.5,
                      maxScale: 4,
                      child: Listener(
                        onPointerDown: (event) {
                          if (pencilMode) return;
                          if (_outlinePointer != null) {
                            _outlineMultiTouch = true;
                            return;
                          }
                          selectRoom(event.localPosition);
                          if (_wallHandle != null || _cornerHandle != null) {
                            _editingGesture = true;
                            _outlinePointer = event.pointer;
                            _outlineMultiTouch = false;
                            _outlinePosition = event.localPosition;
                            _dragError = null;
                          }
                        },
                        onPointerMove: (event) {
                          if (event.pointer != _outlinePointer ||
                              _outlineMultiTouch) return;
                          final delta = event.localPosition - _outlinePosition!;
                          _outlinePosition = event.localPosition;
                          _dragOutline(delta);
                        },
                        onPointerUp: (event) {
                          if (event.pointer != _outlinePointer) return;
                          _outlinePointer = null;
                          _editingGesture = false;
                          _checkpoint();
                          _wallHandle = null;
                          _cornerHandle = null;
                          if (_dragError != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(_dragError!)));
                            _dragError = null;
                          }
                        },
                        onPointerCancel: (_) {
                          _editingGesture = false;
                          _checkpoint();
                          _outlinePointer = null;
                          _wallHandle = null;
                          _cornerHandle = null;
                        },
                        child: GestureDetector(
                          dragStartBehavior: DragStartBehavior.down,
                          onTapDown: (d) {
                            if (!pencilMode) {
                              selectRoom(d.localPosition);
                            } else {
                              if (doorPlacementMode) {
                                setState(() {
                                  doorPlacementMode = false;
                                });
                              }
                            }
                          },
                          onPanStart: (d) {
                            _editingGesture = true;
                            _dragError = null;
                            lastPanPosition = d.localPosition;
                            if (!pencilMode && _outlinePointer == null)
                              selectRoom(d.localPosition);
                            if (pencilMode) {
                              _drawingPoints
                                ..clear()
                                ..add(d.localPosition);
                              drawingPath = Path()
                                ..moveTo(
                                    d.localPosition.dx, d.localPosition.dy);
                            }
                          },
                          onPanUpdate: (d) {
                            if (_outlinePointer != null) return;
                            if (pencilMode) {
                              setState(() {
                                _drawingPoints.add(d.localPosition);
                                drawingPath!.lineTo(
                                  d.localPosition.dx,
                                  d.localPosition.dy,
                                );
                              });
                            } else if (_wallHandle != null ||
                                _cornerHandle != null) {
                              // Outline handles use direct pointer events.
                            } else if (activeHandle != null) {
                              resizeRoom(d.delta);
                            } else if (selectedRoom != null ||
                                selectedDoor != null) {
                              moveSelected(d.delta);
                            }
                          },
                          onPanCancel: () {
                            _editingGesture = false;
                            _checkpoint();
                            _wallHandle = null;
                            _cornerHandle = null;
                            setState(() {
                              drawingPath = null;
                              _drawingPoints.clear();
                              activeHandle = null;
                              startBounds = null;
                            });
                          },
                          onPanEnd: (d) {
                            _editingGesture = false;
                            _checkpoint();
                            _wallHandle = null;
                            _cornerHandle = null;
                            if (_dragError != null)
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(_dragError!)));
                            activeHandle = null;
                            startBounds = null;
                            if (pencilMode && drawingPath != null) {
                              _finishOutline();
                            }
                          },
                          child: CustomPaint(
                            size: const Size(2000, 2000),
                            painter: FloorPainter(
                              rooms: rooms,
                              doors: doors,
                              selectedRoom: selectedRoom,
                              selectedDoor: selectedDoor,
                              previewPath: drawingPath,
                              wallLabelStyle: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.showSidebars && !narrow) _rightSidebar(),
        ],
      ),
    );
  }

  Widget _topBar() => Material(
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => setState(() {
                  pencilMode = !pencilMode;
                  selectedRoom = null;
                  selectedDoor = null;
                  drawingPath = null;
                  _drawingPoints.clear();
                }),
                icon: Icon(pencilMode ? Icons.close : Icons.edit_outlined),
                label: Text(pencilMode ? 'Cancel drawing' : 'Draw room'),
              ),
              IconButton(
                  tooltip: 'Undo',
                  onPressed: _historyIndex > 0
                      ? () => _restoreHistory(_historyIndex - 1)
                      : null,
                  icon: const Icon(Icons.undo)),
              IconButton(
                  tooltip: 'Redo',
                  onPressed: _historyIndex < _history.length - 1
                      ? () => _restoreHistory(_historyIndex + 1)
                      : null,
                  icon: const Icon(Icons.redo)),
              TextButton.icon(
                  onPressed: _openSVG,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Open')),
              TextButton.icon(
                  onPressed: rooms.isEmpty ? null : _downloadSVG,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save')),
            ]),
      ));

  Widget _contextualBar() {
    final room = selectedRoom;
    final bounds = (room?.path ?? selectedDoor!.path).getBounds();
    return Material(
        child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: TextButton(
            onPressed: room == null ? null : () => _showNameEditor(context),
            child: Text(room?.name ?? 'Door', maxLines: 2),
          )),
          if (room != null)
            IconButton(
                tooltip: 'Room color',
                icon: const Icon(Icons.palette_outlined),
                onPressed: () => _showColorPicker(context)),
          IconButton(
              tooltip: 'Close selection',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                    selectedRoom = null;
                    selectedDoor = null;
                  })),
        ]),
        if (room != null) ...[
          Text(
              room.wallPoints == null
                  ? 'Drag sides or corners to resize.'
                  : 'Drag a wall dot along its wall to change length. Drag a corner square to reshape.',
              style: Theme.of(context).textTheme.bodySmall),
          TextButton.icon(
              onPressed: _editDimensions,
              icon: const Icon(Icons.straighten),
              label: Text(
                  'Width ${(bounds.width * 10).toStringAsFixed(0)} mm · Length ${(bounds.height * 10).toStringAsFixed(0)} mm')),
          if (room.wallPoints != null)
            OutlinedButton(
                onPressed: _editWall, child: const Text('Edit wall lengths')),
        ] else
          Text(
              'Width ${(bounds.width * 10).toStringAsFixed(0)} mm · Length ${(bounds.height * 10).toStringAsFixed(0)} mm'),
      ]),
    ));
  }

  Future<void> _editWall() async {
    final room = selectedRoom;
    if (room?.wallPoints == null) return;
    final size = await showDialog<(int, double)>(
        context: context, builder: (_) => WallSizeDialog(room: room!));
    if (!mounted || size == null) return;
    try {
      setState(() {
        WallDimensions.resize(room!, doors, size.$1, size.$2);
        _notifyChanged();
      });
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${error.message}')));
    }
  }

  Future<void> _editDimensions() async {
    final room = selectedRoom;
    if (room == null) return;
    final bounds = room.path.getBounds();
    final width =
        TextEditingController(text: (bounds.width * 10).toStringAsFixed(1));
    final length =
        TextEditingController(text: (bounds.height * 10).toStringAsFixed(1));
    final form = GlobalKey<FormState>();
    var unit = DimensionUnit.millimetres;
    String? validate(String? value) {
      final number = double.tryParse(value ?? '');
      return number == null ||
              !number.isFinite ||
              unit.toMm(number) < 100 ||
              unit.toMm(number) > 1000000
          ? 'Enter ${unit.fromMm(100).toStringAsPrecision(4)} to ${unit.fromMm(1000000).toStringAsPrecision(4)} ${unit.symbol}'
          : null;
    }

    final route = DialogRoute<List<double>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, updateDialog) => AlertDialog(
                title: const Text('Room dimensions'),
                content: SingleChildScrollView(
                    child: Form(
                        key: form,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                                'Set the overall size of this outline. Placed doors resize with it.'),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<DimensionUnit>(
                              isExpanded: true,
                              initialValue: unit,
                              decoration: const InputDecoration(
                                  labelText: 'Measurement unit'),
                              items: [
                                for (final choice in DimensionUnit.values)
                                  DropdownMenuItem(
                                      value: choice, child: Text(choice.label))
                              ],
                              onChanged: (next) {
                                if (next == null || next == unit) return;
                                updateDialog(() {
                                  for (final controller in [width, length]) {
                                    final value =
                                        double.tryParse(controller.text);
                                    if (value != null && value.isFinite) {
                                      controller.text = next
                                          .fromMm(unit.toMm(value))
                                          .toString();
                                    }
                                  }
                                  unit = next;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            for (final field in [
                              (width, 'Width (${unit.symbol})'),
                              (length, 'Length (${unit.symbol})')
                            ]) ...[
                              TextFormField(
                                  controller: field.$1,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d*'))
                                  ],
                                  decoration:
                                      InputDecoration(labelText: field.$2),
                                  validator: validate),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        if (form.currentState!.validate()) {
                          Navigator.pop(dialogContext, [
                            unit.toMm(double.parse(width.text)),
                            unit.toMm(double.parse(length.text))
                          ]);
                        }
                      },
                      child: const Text('Apply')),
                ],
              )),
    );
    final size = await Navigator.of(context).push(route);
    if (mounted && size != null) {
      try {
        setState(() {
          RoomDimensions.resize(room, doors, size[0], size[1]);
          _notifyChanged();
        });
      } on ArgumentError catch (error) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${error.message}')));
      }
    }
    // Dialog fields remain mounted until the closing animation finishes.
    await route.completed;
    width.dispose();
    length.dispose();
  }

  void _showNameEditor(BuildContext context) {
    if (selectedRoom == null) return;

    final controller = TextEditingController(text: selectedRoom!.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Room Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter room name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              setState(() {
                selectedRoom!.name = value.trim();
                _notifyChanged();
              });
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  selectedRoom!.name = controller.text.trim();
                  _notifyChanged();
                });
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _leftSidebar() {
    return Container(
      width: 64,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 24),
          const SizedBox(height: 20),
          _sidebarButton(Icons.add, "New", () {
            setState(() {
              rooms.clear();
              doors.clear();
              selectedRoom = null;
              selectedDoor = null;
              _roomCounter = 1;
              _notifyChanged();
            });
          }),
          _sidebarButton(Icons.folder_open, "Open", () => _openSVG()),
          _sidebarButton(Icons.clear_all_outlined, "Clear All", () {
            setState(() {
              rooms.clear();
              doors.clear();
              selectedRoom = null;
              selectedDoor = null;
              drawingPath = null;
              pencilMode = false;
              doorPlacementMode = false;
              lastPanPosition = null;
              activeHandle = null;
              startBounds = null;
              selectedColor = null;
              _roomCounter = 1;
              _notifyChanged();
            });
          }),
          _sidebarButton(Icons.save, "Save", () => _downloadSVG()),
          const Divider(),
          _sidebarButton(Icons.delete, "Delete", () {
            if (selectedRoom != null) {
              setState(() {
                rooms.remove(selectedRoom);
                selectedRoom = null;
                _notifyChanged();
              });
            } else if (selectedDoor != null) {
              setState(() {
                doors.remove(selectedDoor);
                selectedDoor = null;
                _notifyChanged();
              });
            }
          }),
          _sidebarButton(Icons.rotate_right, "Rotation", rotateSelected),
          _sidebarButton(Icons.palette, "Color", () {
            if (selectedRoom != null) {
              _showColorPicker(context);
            }
          }),
        ],
      ),
    );
  }

  Widget _sidebarButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  Widget _rightSidebar() {
    return Container(
      width: 200,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text(
              "Colors",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: colorPalette.map((color) {
                final isSelected = selectedColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedColor = color;
                      if (selectedRoom != null) {
                        selectedRoom!.fillColor = color;
                        _notifyChanged();
                      }
                    });
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(),
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text(
              "Structure",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(8),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _structureButton(Icons.crop_square, "Square room", () {
                  setState(() {
                    rooms.add(
                      Room(
                        id: UniqueKey().toString(),
                        path: PathUtils.createRectangle(const Offset(200, 200)),
                        fillColor: selectedColor ?? const Color(0xFFF5F5DC),
                        name: 'Room $_roomCounter',
                      ),
                    );
                    _roomCounter++;
                    _notifyChanged();
                  });
                }),
                _structureButton(Icons.crop_square, "L-shape room", () {
                  setState(() {
                    rooms.add(
                      Room(
                        id: UniqueKey().toString(),
                        path: PathUtils.createLShape(const Offset(200, 200)),
                        fillColor: selectedColor ?? const Color(0xFFF5F5DC),
                        name: 'Room $_roomCounter',
                      ),
                    );
                    _roomCounter++;
                    _notifyChanged();
                  });
                }),
                _structureButton(Icons.account_tree, "U-shape room", () {
                  setState(() {
                    rooms.add(
                      Room(
                        id: UniqueKey().toString(),
                        path: PathUtils.createUShape(const Offset(200, 200)),
                        fillColor: selectedColor ?? const Color(0xFFF5F5DC),
                        name: 'Room $_roomCounter',
                      ),
                    );
                    _roomCounter++;
                    _notifyChanged();
                  });
                }),
                _structureButton(Icons.call_split, "T-shape room", () {
                  setState(() {
                    rooms.add(
                      Room(
                        id: UniqueKey().toString(),
                        path: PathUtils.createTShape(const Offset(200, 200)),
                        fillColor: selectedColor ?? const Color(0xFFF5F5DC),
                        name: 'Room $_roomCounter',
                      ),
                    );
                    _roomCounter++;
                    _notifyChanged();
                  });
                }),
                _structureButton(Icons.circle, "Circular room", () {
                  setState(() {
                    rooms.add(
                      Room(
                        id: UniqueKey().toString(),
                        path: PathUtils.createCircle(const Offset(200, 200),
                            radius: 100),
                        fillColor: selectedColor ?? const Color(0xFFF5F5DC),
                        name: 'Room $_roomCounter',
                      ),
                    );
                    _roomCounter++;
                    _notifyChanged();
                  });
                }),
                _structureButton(Icons.edit, "Walls", () {
                  setState(() {
                    pencilMode = !pencilMode;
                    if (!pencilMode) {
                      drawingPath = null;
                      doorPlacementMode = false;
                    }
                  });
                }, isSelected: pencilMode),
                _structureButton(Icons.meeting_room, "Add Door", () {
                  if (selectedRoom != null) {
                    addDoorToRoom(selectedRoom!);
                  }
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Room Color'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colorPalette.map((color) {
            final isSelected = selectedRoom?.fillColor == color;
            return GestureDetector(
              onTap: () {
                if (selectedRoom != null) {
                  setState(() {
                    selectedRoom!.fillColor = color;
                    selectedColor = color;
                    _notifyChanged();
                  });
                }
                Navigator.of(context).pop();
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.grey,
                    width: isSelected ? 3 : 1,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _structureButton(
    IconData icon,
    String label,
    VoidCallback onPressed, {
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: isSelected ? Colors.blue : null),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.blue : null,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
