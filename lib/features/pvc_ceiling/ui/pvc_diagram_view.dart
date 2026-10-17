import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../ui/app_typography.dart';

/// A bounded viewport; scaling changes the view, never the calculated geometry.
class PvcDiagramView extends StatefulWidget {
  const PvcDiagramView(
      {super.key,
      required this.size,
      required this.painter,
      required this.label});
  final Size size;
  final CustomPainter painter;
  final String label;
  @override
  State<PvcDiagramView> createState() => _PvcDiagramViewState();
}

class _PvcDiagramViewState extends State<PvcDiagramView> {
  final _transform = TransformationController();
  Size? _viewport;
  double _fit = 1;
  bool _panning = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_changed);
  }

  void _changed() {
    final enabled = _transform.value.getMaxScaleOnAxis() > _fit * 1.01;
    if (mounted && enabled != _panning) setState(() => _panning = enabled);
  }

  @override
  void dispose() {
    _transform.removeListener(_changed);
    _transform.dispose();
    super.dispose();
  }

  Matrix4 _matrix(double scale, double x, double y) => Matrix4.identity()
    ..setEntry(0, 0, scale)
    ..setEntry(1, 1, scale)
    ..setEntry(2, 2, scale)
    ..setTranslationRaw(x, y, 0);
  void _reset() {
    final view = _viewport!;
    _transform.value = _matrix(
        _fit,
        (view.width - widget.size.width * _fit) / 2,
        (view.height - widget.size.height * _fit) / 2);
  }

  void _zoom(double factor) {
    final old = _transform.value, scale = old.getMaxScaleOnAxis();
    final next =
        (scale * factor).clamp(_fit, math.max(4.0, _fit * 8)).toDouble();
    final ratio = next / scale, center = _viewport!.center(Offset.zero);
    _transform.value = _matrix(
        next,
        center.dx - (center.dx - old.entry(0, 3)) * ratio,
        center.dy - (center.dy - old.entry(1, 3)) * ratio);
  }

  void _configure(Size view) {
    if (_viewport == view) return;
    final first = _viewport == null;
    _viewport = view;
    _fit = math.min(
        view.width / widget.size.width, view.height / widget.size.height);
    if (first) {
      _reset();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reset();
      });
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        if (box.maxWidth <= 0) return const SizedBox.shrink();
        final available = MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).bottom;
        final maxHeight = (available * .55).clamp(140.0, 420.0);
        final height = (box.maxWidth * widget.size.height / widget.size.width)
            .clamp(120.0, maxHeight);
        _configure(Size(box.maxWidth, height));
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                  label: widget.label,
                  child: SizedBox(
                      height: height,
                      child: InteractiveViewer(
                          transformationController: _transform,
                          constrained: false,
                          minScale: _fit,
                          maxScale: math.max(4.0, _fit * 8),
                          panEnabled: _panning,
                          child: SizedBox(
                              width: widget.size.width,
                              height: widget.size.height,
                              child: CustomPaint(painter: widget.painter))))),
              Row(children: [
                Expanded(
                    child: Text(_panning ? 'Drag to explore' : 'Pinch to zoom',
                        style: AppTypography.text12Muted)),
                IconButton(
                    tooltip: 'Zoom out',
                    onPressed: () => _zoom(1 / 1.5),
                    icon: const Icon(Icons.remove)),
                IconButton(
                    tooltip: 'Zoom in',
                    onPressed: () => _zoom(1.5),
                    icon: const Icon(Icons.add)),
                IconButton(
                    tooltip: 'Fit diagram',
                    onPressed: _reset,
                    icon: const Icon(Icons.fit_screen)),
              ]),
            ]);
      });
}
