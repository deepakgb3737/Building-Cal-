import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';
import 'package:grid_ceiling_calculator/ui/app_typography.dart';
import 'package:grid_ceiling_calculator/ui/app_widgets.dart';
import 'package:grid_ceiling_calculator/ui/app_styles.dart';
import '../logic/drawing_shapes.dart';
import '../logic/drawing_point.dart';
import '../logic/wall_network.dart';
import 'drawing_length_field.dart';
import 'shape_diagram.dart';

class ShapeDialog extends StatefulWidget {
  const ShapeDialog({super.key, required this.spec, required this.unit});
  final ShapeSpec spec;
  final DrawingUnit unit;
  @override
  State<ShapeDialog> createState() => _ShapeDialogState();
}

class _ShapeDialogState extends State<ShapeDialog> {
  final _form = GlobalKey<FormState>();
  final _errorAnchor = GlobalKey();
  late final _measurements = widget.spec.measurements;
  late final _controllers = {
    for (final m in _measurements)
      m.id: TextEditingController(
          text: widget.unit.input(m.value, decimalPlaces: 2))
        ..addListener(_update),
  };
  late final _angle =
      TextEditingController(text: widget.spec.rotation.toString())
        ..addListener(_update);
  late ShapeSpec? _preview = widget.spec;
  late LShapeOrientation _orientation = widget.spec.orientation;
  Map<ShapeDimension, String> _dimensionErrors = {};
  final _scrollKey = GlobalKey();
  late final _fieldKeys = {for (final m in _measurements) m.id: GlobalKey()};
  late final Map<ShapeDimension, FocusNode> _nodes = {
    for (final m in _measurements)
      m.id: FocusNode()
        ..addListener(() {
          if (_nodes[m.id]!.hasFocus) {
            setState(() => _active = m.id);
            _revealFocused();
          }
        })
  };
  late final _angleNode = FocusNode()..addListener(_revealFocused);
  final _angleKey = GlobalKey();
  bool _submitting = false;
  bool _revealQueued = false;
  bool _revealAgain = false;
  Size? _layoutSize;
  ShapeDimension? _active;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.of(context);
    _revealFocused();
  }

  BuildContext? get _focusedFieldContext {
    final key = _angleNode.hasFocus
        ? _angleKey
        : _nodes.entries
            .where((e) => e.value.hasFocus)
            .map((e) => _fieldKeys[e.key])
            .firstOrNull;
    return key?.currentContext;
  }

  void _revealFocused() {
    if (_revealQueued) {
      _revealAgain = true;
      return;
    }
    _revealQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _focusedFieldContext;
      if (target != null) Scrollable.ensureVisible(target, alignment: .25);
      // The editable's caret reveal can run after the surrounding field layout.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _revealQueued = false;
        if (mounted) {
          final current = _focusedFieldContext;
          if (current != null) {
            Scrollable.ensureVisible(current, alignment: .25);
          }
          if (_revealAgain) {
            _revealAgain = false;
            _revealFocused();
          }
        }
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  String? _error;

  ShapeSpec? _read() {
    final values = <ShapeDimension, double>{};
    for (final entry in _controllers.entries) {
      final original = _measurements.firstWhere((m) => m.id == entry.key).value;
      final value =
          entry.value.text == widget.unit.input(original, decimalPlaces: 2)
              ? original
              : widget.unit.readMm(entry.value.text);
      if (value == null || !value.isFinite || value < 10 || value > 10000000) {
        return null;
      }
      values[entry.key] = value;
    }
    final rotation = double.tryParse(_angle.text);
    if (rotation == null ||
        !rotation.isFinite ||
        rotation < 0 ||
        rotation > 360) {
      return null;
    }
    final width = values.remove(ShapeDimension.width)!;
    final height = values.remove(ShapeDimension.height) ?? width;
    return ShapeSpec(widget.spec.kind, width, height, rotation,
        details: Map.unmodifiable(values), orientation: _orientation);
  }

  void _update() {
    final spec = _read();
    String? error;
    if (spec != null) {
      try {
        spec.points(const DrawingPoint(0, 0));
      } on DrawingConflict catch (e) {
        error = e.message;
      }
    } else {
      error = 'Enter valid dimensions to update the preview.';
    }
    setState(() {
      _error = error;
      _dimensionErrors = spec?.dimensionErrors ?? {};
      _preview = error == null ? spec : null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _form.currentState?.validate();
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _nodes.values) {
      node.dispose();
    }
    _angleNode.dispose();
    _angle.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitting) return;
    if (!_form.currentState!.validate()) {
      for (final m in _measurements) {
        final value = widget.unit.readMm(_controllers[m.id]!.text);
        if (value == null ||
            !value.isFinite ||
            value < 10 ||
            value > 10000000 ||
            _dimensionErrors.containsKey(m.id)) {
          _nodes[m.id]!.requestFocus();
          _revealFocused();
          return;
        }
      }
      _angleNode.requestFocus();
      _revealFocused();
      return;
    }
    _update();
    if (_error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final anchor = _errorAnchor.currentContext;
        if (mounted && anchor != null) Scrollable.ensureVisible(anchor);
      });
      return;
    }
    _submitting = true;
    FocusScope.of(context).unfocus();
    Navigator.pop(context, _read());
  }

  Widget _diagram() => Semantics(
      label: '${widget.spec.kind.label} dimension diagram',
      child: _preview == null
          ? const Center(child: Text('Enter valid dimensions to preview'))
          : CustomPaint(
              key: const ValueKey('shapeDimensionDiagram'),
              size: const Size(double.infinity, double.infinity),
              painter: ShapeDiagram(_preview!, widget.unit, _active,
                  textScaler: MediaQuery.textScalerOf(context))));

  Widget _fields(bool compact, {bool includeActions = false}) =>
      NotificationListener<ScrollMetricsNotification>(
          onNotification: (_) {
            _revealFocused();
            return false;
          },
          child: SingleChildScrollView(
              key: _scrollKey,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: _formContents(compact,
                            singleColumn: includeActions)),
                    if (includeActions)
                      _actions(MediaQuery.textScalerOf(context).scale(1),
                          MediaQuery.sizeOf(context).width - 24),
                  ])));

  Widget _formContents(bool compact, {bool singleColumn = false}) => Form(
      key: _form,
      child: LayoutBuilder(builder: (context, constraints) {
        final twoColumns = !singleColumn &&
            constraints.maxWidth >=
                460 * MediaQuery.textScalerOf(context).scale(1);
        final width =
            twoColumns ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact)
                Text('${widget.spec.kind.label} dimensions',
                    style: AppTypography.input),
              if (compact) SizedBox(height: 180, child: _diagram()),
              Text('Measurements in ${widget.unit.name}',
                  style: AppTypography.text12Muted),
              if (widget.unit == DrawingUnit.feetInches)
                const Text('Example: 11 5.8 = 11 ft 5.8 in'),
              const SizedBox(height: 8),
              if (widget.spec.kind == ShapePreset.lShape) ...[
                const Text('Arms meet at', style: AppTypography.label),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final orientation in LShapeOrientation.values)
                    ChoiceChip(
                        key: ValueKey(orientation),
                        label: Text(orientation.label),
                        selected: _orientation == orientation,
                        onSelected: (_) {
                          _orientation = orientation;
                          _update();
                        }),
                ]),
                const SizedBox(height: 8),
              ],
              if (widget.spec.kind == ShapePreset.triangle)
                const Text('Right triangle: base and height meet at 90°.'),
              if (widget.spec.kind == ShapePreset.tShape)
                const Text('The stem stays centred below the top bar.'),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                        key: _errorAnchor,
                        liveRegion: true,
                        child: Text('$_error',
                            style: AppTypography.label
                                .copyWith(color: AppColors.error)))),
              Wrap(spacing: 12, runSpacing: 10, children: [
                for (var i = 0; i < _measurements.length; i++)
                  SizedBox(
                      key: _fieldKeys[_measurements[i].id],
                      width: width,
                      child: DrawingLengthField(
                          key: ValueKey(_measurements[i].id),
                          label:
                              '${_measurements[i].letter} · ${_measurements[i].name}',
                          controller: _controllers[_measurements[i].id]!,
                          unit: widget.unit,
                          originalMm: _measurements[i].value,
                          validationError:
                              _dimensionErrors[_measurements[i].id],
                          labelAbove: true,
                          focusNode: _nodes[_measurements[i].id],
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => i + 1 < _measurements.length
                              ? _nodes[_measurements[i + 1].id]!.requestFocus()
                              : _angleNode.requestFocus())),
                SizedBox(
                    key: _angleKey,
                    width: width,
                    child: AppNumberField(
                        label: 'Rotation (degrees clockwise)',
                        controller: _angle,
                        labelAbove: true,
                        focusNode: _angleNode,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (text) {
                          final v = double.tryParse(text ?? '');
                          return v == null || !v.isFinite || v < 0 || v > 360
                              ? 'Enter 0 to 360 degrees'
                              : null;
                        })),
              ]),
              const SizedBox(height: 10),
              for (final m
                  in _preview?.derivedMeasurements ?? <(String, double)>[])
                Text('${m.$1}: ${widget.unit.format(m.$2)} (calculated)',
                    style: AppTypography.label
                        .copyWith(color: AppColors.secondaryText)),
              const SizedBox(height: 6),
              const Text(
                  'Preview matches orientation and rotation on the canvas.'),
            ]);
      }));

  Widget _actions(double textScale, double width) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        if (textScale > 1.3 || width < 300)
          IconButton(
              tooltip: 'Cancel',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close))
        else
          TextButton(
              style: AppButtonStyles.drawingDialogAction,
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', textAlign: TextAlign.center)),
        const SizedBox(width: 8),
        Expanded(
            child: FilledButton(
                style: AppButtonStyles.drawingDialogAction,
                onPressed: _submit,
                child: const Text('Preview', textAlign: TextAlign.center))),
      ]));

  @override
  Widget build(BuildContext context) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: LayoutBuilder(builder: (context, outer) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final formWidth =
                outer.maxWidth - (outer.maxWidth >= 600 ? 220 : 0) - 24;
            final columns = formWidth >= 460 * textScale ? 2 : 1;
            final rows = ((_measurements.length + 1) / columns).ceil();
            final fieldHeight =
                widget.unit == DrawingUnit.feetInches ? 110 : 80;
            final height = (rows * fieldHeight * textScale +
                    (outer.maxWidth >= 600 ? 120 : 240))
                .clamp(300.0, outer.maxHeight.clamp(300.0, 720.0));
            return SizedBox(
                height: height,
                child: LayoutBuilder(builder: (context, constraints) {
                  if (_layoutSize != constraints.biggest) {
                    _layoutSize = constraints.biggest;
                    _revealFocused();
                  }
                  final compact = constraints.maxHeight <
                      360 * MediaQuery.textScalerOf(context).scale(1);
                  final wide = constraints.maxWidth >= 600;
                  if (constraints.maxHeight < 120 * textScale) {
                    return _fields(true, includeActions: true);
                  }
                  return Column(children: [
                    if (!compact)
                      Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  '${widget.spec.kind.label} dimensions',
                                  style: AppTypography.text17W700Text))),
                    Expanded(
                        child: wide && !compact
                            ? Row(children: [
                                SizedBox(width: 220, child: _diagram()),
                                Expanded(child: _fields(compact)),
                              ])
                            : Column(children: [
                                if (!compact)
                                  SizedBox(
                                      height: (constraints.maxHeight * .3)
                                          .clamp(150.0, 200.0),
                                      width: double.infinity,
                                      child: _diagram()),
                                Expanded(flex: 3, child: _fields(compact)),
                              ])),
                    _actions(textScale, constraints.maxWidth),
                  ]);
                }));
          })));
}
