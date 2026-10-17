import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';
import 'package:grid_ceiling_calculator/ui/app_styles.dart';
import 'package:grid_ceiling_calculator/ui/app_typography.dart';
import 'drawing_toolbar_row.dart';

class DrawingToolPalette extends StatefulWidget {
  const DrawingToolPalette(
      {super.key,
      required this.viewport,
      required this.child,
      required this.onInteract,
      this.onExpandedChanged,
      this.onBoundsChanged,
      this.primaryControls});
  final Size viewport;
  final Widget child;
  final Widget? primaryControls;
  final VoidCallback onInteract;
  final ValueChanged<bool>? onExpandedChanged;
  final ValueChanged<Rect>? onBoundsChanged;

  @override
  State<DrawingToolPalette> createState() => _DrawingToolPaletteState();
}

class _DrawingToolPaletteState extends State<DrawingToolPalette> {
  bool _expanded = true;
  Offset? _position;
  Offset? _dragOrigin;
  Rect? _reportedBounds;

  @override
  Widget build(BuildContext context) {
    final modern = widget.primaryControls != null;
    final width = math.min(
        _expanded
            ? modern
                ? math.min(760.0, widget.viewport.width - 16)
                : 216.0
            : 96.0,
        widget.viewport.width);
    final primaryCount = switch (widget.primaryControls) {
      DrawingToolbarRow(:final children) => children.length,
      _ => 5,
    };
    final primaryHeight =
        DrawingToolbarRow.heightFor(context, width - 56, primaryCount) + 8;
    final secondCount = switch (widget.child) {
      DrawingToolbarRow(:final children) => children.length,
      Padding(child: DrawingToolbarRow(:final children)) => children.length,
      _ => 6,
    };
    final secondHeight =
        DrawingToolbarRow.heightFor(context, width - 8, secondCount);
    final height = math.min(
        _expanded
            ? modern
                ? primaryHeight + secondHeight + 9
                : 240.0
            : 48.0,
        math.max(0.0, widget.viewport.height * (_expanded ? .5 : 1)));
    final maxX = math.max(0.0, widget.viewport.width - width);
    final maxY = math.max(0.0, widget.viewport.height - height);
    // Keep the initial position clear of transient save notifications.
    final reserved =
        modern ? 16.0 : MediaQuery.textScalerOf(context).scale(16) * 4;
    _position ??= Offset(maxX - 8, maxY - reserved - 8);
    final desired = _position!;
    final position =
        Offset(desired.dx.clamp(0, maxX), desired.dy.clamp(0, maxY));
    final bounds = position & Size(width, height);
    if (widget.onBoundsChanged != null && _reportedBounds != bounds) {
      _reportedBounds = bounds;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _reportedBounds == bounds) {
          widget.onBoundsChanged?.call(bounds);
        }
      });
    }
    void startMove(DragStartDetails _) {
      widget.onInteract();
      _dragOrigin = position;
      _position = position;
    }

    void updateMove(DragUpdateDetails details) => setState(() {
          final next = _position! + details.delta;
          _position = Offset(next.dx.clamp(0, maxX), next.dy.clamp(0, maxY));
        });

    void cancelMove() {
      if (_dragOrigin == null) return;
      setState(() {
        _position = _dragOrigin;
        _dragOrigin = null;
      });
    }

    return Positioned(
        left: position.dx,
        top: position.dy,
        width: width,
        height: height,
        child: Listener(
            onPointerCancel: (_) => cancelMove(),
            child: Material(
                key: const ValueKey('drawingToolPalette'),
                color: AppColors.white,
                shape: const RoundedRectangleBorder(
                    borderRadius: AppRadii.r8,
                    side: BorderSide(color: AppColors.border)),
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  SizedBox(
                      height: math.min(
                          _expanded && modern ? primaryHeight : 48,
                          modern && _expanded
                              ? math.max(
                                  0, height - 1 - math.min(48, secondHeight))
                              : height),
                      child: Row(children: [
                        if (_expanded && modern)
                          Expanded(
                              child: SingleChildScrollView(
                                  child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: widget.primaryControls!))),
                        if (!_expanded || !modern)
                          Expanded(
                              child: GestureDetector(
                                  key: const ValueKey('moveDrawingTools'),
                                  behavior: HitTestBehavior.opaque,
                                  dragStartBehavior: DragStartBehavior.down,
                                  onPanStart: startMove,
                                  onPanUpdate: updateMove,
                                  onPanEnd: (_) => _dragOrigin = null,
                                  onPanCancel: cancelMove,
                                  child: Tooltip(
                                      message: 'Drag drawing tools',
                                      child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.drag_indicator,
                                                size: 20),
                                            if (_expanded)
                                              const Text('Tools',
                                                  style: AppTypography.text12),
                                          ])))),
                        GestureDetector(
                            key: _expanded && modern
                                ? const ValueKey('moveDrawingTools')
                                : null,
                            dragStartBehavior: DragStartBehavior.down,
                            onPanStart: _expanded && modern ? startMove : null,
                            onPanUpdate:
                                _expanded && modern ? updateMove : null,
                            onPanEnd: _expanded && modern
                                ? (_) => _dragOrigin = null
                                : null,
                            onPanCancel:
                                _expanded && modern ? cancelMove : null,
                            child: IconButton(
                                tooltip: _expanded
                                    ? 'Collapse drawing tools'
                                    : 'Expand drawing tools',
                                onPressed: () {
                                  widget.onInteract();
                                  setState(() => _expanded = !_expanded);
                                  widget.onExpandedChanged?.call(_expanded);
                                },
                                icon: Icon(_expanded
                                    ? Icons.close_fullscreen
                                    : Icons.handyman_outlined))),
                      ])),
                  if (_expanded && modern)
                    const Divider(
                        height: 1, thickness: 1, color: AppColors.border),
                  if (_expanded)
                    Expanded(child: SingleChildScrollView(child: widget.child)),
                ]))));
  }
}
