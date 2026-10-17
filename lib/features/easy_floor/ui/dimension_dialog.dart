import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/ui/app_typography.dart';
import 'drawing_length_field.dart';
import '../logic/drawing_point.dart';
import '../logic/wall_resize.dart';
import 'wall_resize_options.dart';

class DimensionDialog extends StatefulWidget {
  const DimensionDialog(
      {super.key,
      required this.valueMm,
      required this.unit,
      this.secondMm,
      this.fixed = false,
      this.onUnitChanged,
      this.title,
      this.showLock = true,
      this.resizeAnchor = WallResizeAnchor.start,
      this.validateEdit,
      this.onResizeChanged});
  final String? Function((double, double?, bool))? validateEdit;
  final WallResizeAnchor resizeAnchor;
  final ValueChanged<WallResizeAnchor>? onResizeChanged;
  final String? title;
  final bool showLock;
  final ValueChanged<DrawingUnit>? onUnitChanged;
  final double valueMm;
  final double? secondMm;
  final DrawingUnit unit;
  final bool fixed;
  @override
  State<DimensionDialog> createState() => _DimensionDialogState();
}

class _DimensionDialogState extends State<DimensionDialog> {
  final _form = GlobalKey<FormState>();
  final _firstFocus = FocusNode();
  final _secondFocus = FocusNode();
  bool _revealQueued = false;
  String? _error;
  late DrawingUnit _unit = widget.unit;
  late bool _fixed = widget.fixed;
  late WallResizeAnchor _anchor = widget.resizeAnchor;
  late final _first = TextEditingController(
      text: _unit.input(widget.valueMm, decimalPlaces: 2));
  late final _second = TextEditingController(
      text: widget.secondMm == null
          ? ''
          : _unit.input(widget.secondMm!, decimalPlaces: 2));
  late final _retained = <TextEditingController, double>{
    _first: widget.valueMm,
    if (widget.secondMm != null) _second: widget.secondMm!,
  };

  double? _value(TextEditingController controller) {
    final original = _retained[controller];
    return original != null &&
            controller.text == _unit.input(original, decimalPlaces: 2)
        ? original
        : _unit.readMm(controller.text);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _firstFocus.requestFocus();
      _first.selection =
          TextSelection(baseOffset: 0, extentOffset: _first.text.length);
    });
  }

  void _apply() {
    if (!_form.currentState!.validate()) return;
    final result = (
      _value(_first)!,
      widget.secondMm == null ? null : _value(_second)!,
      _fixed
    );
    final error = widget.validateEdit?.call(result);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, result);
  }

  void _revealFocusedField() {
    if (_revealQueued) return;
    _revealQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealQueued = false;
      if (!mounted) return;
      final focus = _firstFocus.hasFocus
          ? _firstFocus
          : _secondFocus.hasFocus
              ? _secondFocus
              : null;
      if (focus?.context != null) {
        Scrollable.ensureVisible(focus!.context!, alignment: .5);
      }
    });
  }

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    _firstFocus.dispose();
    _secondFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NotificationListener<
          ScrollMetricsNotification>(
      onNotification: (_) {
        _revealFocusedField();
        return false;
      },
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        scrollable: true,
        title: Text(widget.title ??
            (widget.secondMm == null ? 'Wall length' : 'Rectangle dimensions')),
        content: Form(
            key: _form,
            onChanged: () {
              if (_error != null) setState(() => _error = null);
            },
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<DrawingUnit>(
                  initialValue: _unit,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: [
                    for (final unit in DrawingUnit.values)
                      DropdownMenuItem(value: unit, child: Text(unit.name))
                  ],
                  onChanged: (unit) {
                    if (unit == null) return;
                    setState(() {
                      for (final controller in [_first, _second]) {
                        final value = _value(controller);
                        if (value != null && value.isFinite) {
                          _retained[controller] = value;
                          controller.text = unit.input(value, decimalPlaces: 2);
                        }
                      }
                      _unit = unit;
                      widget.onUnitChanged?.call(unit);
                    });
                  }),
              const SizedBox(height: 16),
              DrawingLengthField(
                  originalMm: _retained[_first],
                  focusNode: _firstFocus,
                  unit: _unit,
                  label: widget.secondMm == null ? 'Length' : 'Width',
                  onFieldSubmitted: (_) => _apply(),
                  controller: _first),
              if (widget.onResizeChanged != null) ...[
                const SizedBox(height: 12),
                const Text('How would you like to resize this wall?'),
                WallResizeOptions(
                    value: _anchor,
                    onChanged: (mode) {
                      setState(() => _anchor = mode);
                      widget.onResizeChanged!(mode);
                    }),
              ],
              if (widget.secondMm != null) ...[
                const SizedBox(height: 16),
                DrawingLengthField(
                    originalMm: _retained[_second],
                    focusNode: _secondFocus,
                    unit: _unit,
                    label: 'Length',
                    controller: _second,
                    onFieldSubmitted: (_) => _apply()),
              ] else if (widget.showLock)
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Keep this length fixed'),
                    value: _fixed,
                    onChanged: (v) => setState(() => _fixed = v!)),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                    liveRegion: true,
                    child: Text(_error!, style: AppTypography.text13W600Error)),
              ],
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(onPressed: _apply, child: const Text('Apply'))
        ],
      ));
}
