import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../ui/app_colors.dart';
import '../../../ui/app_typography.dart';
import '../../../ui/app_widgets.dart';
import '../logic/pvc_ceiling_calculator.dart';
import 'pvc_ceiling_painter.dart';
import 'pvc_section.dart';
import 'pvc_ceiling_results.dart';

class PvcCeilingScreen extends StatefulWidget {
  const PvcCeilingScreen({super.key});
  @override
  State<PvcCeilingScreen> createState() => _PvcCeilingScreenState();
}

class _PvcCeilingScreenState extends State<PvcCeilingScreen>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  final _controllers = {
    for (final key in ['A', 'B', 'C', 'D', 'E']) key: TextEditingController()
  };
  final _focus = {
    for (final key in ['A', 'B', 'C', 'D', 'E']) key: FocusNode()
  };
  final _anchors = {
    for (final key in ['A', 'B', 'C', 'D', 'E']) key: GlobalKey()
  };
  bool _revealQueued = false;
  final _saved = {
    for (final shape in PvcShape.values) shape: pvcDefaults(shape)
  };
  PvcShape _shape = PvcShape.rectangle;
  String _mode = 'mix', _corner = 'tr';
  Layout? _layout;
  bool _calculated = false, _busy = false;
  int _token = 0;
  String? _error;
  PvcInputError? _inputError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    for (final c in _controllers.values) {
      c.addListener(_invalidate);
    }
    for (final f in _focus.values) {
      f.addListener(_focusChanged);
    }
  }

  void _focusChanged() {
    if (mounted) {
      setState(() {});
      _revealFocused();
    }
  }

  @override
  void didChangeMetrics() => _revealFocused();

  void _revealFocused() {
    if (_revealQueued) return;
    _revealQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealQueued = false;
      if (!mounted) return;
      final active =
          _focus.entries.where((e) => e.value.hasFocus).firstOrNull?.key;
      final target = _anchors[active]?.currentContext;
      if (target != null) Scrollable.ensureVisible(target, alignment: .2);
    });
  }

  void _load() {
    for (final key in _controllers.keys) {
      _controllers[key]!.text = _saved[_shape]![key] ?? '';
    }
  }

  Map<String, String> get _values =>
      {for (final f in pvcDimensions(_shape)) f.key: _controllers[f.key]!.text};
  void _invalidate() => setState(() {
        ++_token;
        _layout = null;
        _calculated = _busy = false;
        _error = null;
        _inputError = null;
      });
  void _selectShape(PvcShape? shape) {
    if (shape == null || shape == _shape) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _saved[_shape] = _values;
    for (final c in _controllers.values) {
      c.removeListener(_invalidate);
    }
    _shape = shape;
    _load();
    for (final c in _controllers.values) {
      c.addListener(_invalidate);
    }
    _invalidate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final c in _controllers.values) {
      c.removeListener(_invalidate);
      c.dispose();
    }
    for (final f in _focus.values) {
      f.removeListener(_focusChanged);
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _calculate() async {
    if (_busy) return;
    _inputError = null;
    if (!_form.currentState!.validate()) return;
    PvcRoom room;
    try {
      room = buildPvcRoom(_shape, _values, corner: _corner);
    } on PvcInputError catch (e) {
      setState(() => _inputError = e);
      _form.currentState!.validate();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final token = ++_token;
    setState(() {
      _busy = true;
      _calculated = false;
      _error = null;
    });
    try {
      final result =
          await compute(runPvcCalculation, PvcCalculation(room, _mode));
      if (!mounted || token != _token) return;
      setState(() {
        _layout = result;
        _calculated = true;
      });
    } catch (_) {
      if (mounted && token == _token) {
        setState(() =>
            _error = 'Unable to calculate this layout. Please try again.');
      }
    } finally {
      if (mounted && token == _token) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    PvcRoom? room;
    String? previewError;
    try {
      room = buildPvcRoom(_shape, _values, corner: _corner);
    } on PvcInputError {
      previewError = 'Preview unavailable. Check the entered dimensions.';
    }
    final active =
        _focus.entries.where((e) => e.value.hasFocus).firstOrNull?.key;
    return Scaffold(
        appBar: AppBar(title: const Text('PVC Ceiling')),
        body: SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1040),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<PvcShape>(
                                  key: const ValueKey('pvcShape'),
                                  initialValue: _shape,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: 'Room shape'),
                                  items: [
                                    for (final shape in PvcShape.values)
                                      DropdownMenuItem(
                                          value: shape,
                                          child: Text(shape.label))
                                  ],
                                  onChanged: _selectShape),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                  key: const ValueKey('pvcStock'),
                                  initialValue: _mode,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: 'Planks to use'),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'mix',
                                        child: Text('Mix 10 ft + 12 ft')),
                                    DropdownMenuItem(
                                        value: '10', child: Text('Only 10 ft')),
                                    DropdownMenuItem(
                                        value: '12', child: Text('Only 12 ft'))
                                  ],
                                  onChanged: (value) {
                                    if (value == null || value == _mode) return;
                                    _invalidate();
                                    setState(() => _mode = value);
                                  }),
                              PvcSection(
                                  title: 'Measure the lettered walls',
                                  first: true,
                                  child: Form(
                                      key: _form,
                                      child: LayoutBuilder(
                                          builder: (context, box) {
                                        final preview = room == null
                                            ? Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 20),
                                                child: Text(
                                                    previewError ??
                                                        'Enter dimensions to preview.',
                                                    style: AppTypography
                                                        .text13W600Error))
                                            : PvcShapePreview(
                                                room: room, active: active);
                                        final fields = _fields(
                                            box.maxWidth >= 800
                                                ? (box.maxWidth - 24) / 2
                                                : box.maxWidth);
                                        return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              if (box.maxWidth >= 800)
                                                Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Expanded(child: preview),
                                                      const SizedBox(width: 24),
                                                      Expanded(child: fields)
                                                    ])
                                              else ...[preview, fields],
                                              const SizedBox(height: 16),
                                              FilledButton(
                                                  onPressed:
                                                      _busy ? null : _calculate,
                                                  child: _busy
                                                      ? const SizedBox(
                                                          width: 22,
                                                          height: 22,
                                                          child:
                                                              CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2.5,
                                                                  color: AppColors
                                                                      .white))
                                                      : const Text(
                                                          'Calculate')),
                                            ]);
                                      }))),
                              if (_error != null)
                                Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(_error!,
                                        style: AppTypography.text13W600Error)),
                              if (_calculated)
                                PvcCeilingResults(layout: _layout),
                            ]))))));
  }

  Widget _fields(double width) {
    final fields = pvcDimensions(_shape);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_shape == PvcShape.t || _shape == PvcShape.u)
        const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Leave E empty to center the stem or opening.',
                style: AppTypography.text14Greymuted)),
      Wrap(spacing: 14, runSpacing: 12, children: [
        for (var i = 0; i < fields.length; i++)
          SizedBox(
              key: _anchors[fields[i].key],
              width: width >= 460 ? (width - 14) / 2 : width,
              child: AppNumberField(
                  key: ValueKey('pvcField${_shape.name}${fields[i].key}'),
                  label: '${fields[i].key} · ${fields[i].label} (ft)',
                  controller: _controllers[fields[i].key]!,
                  focusNode: _focus[fields[i].key],
                  labelAbove: true,
                  textInputAction: i == fields.length - 1
                      ? TextInputAction.done
                      : TextInputAction.next,
                  onFieldSubmitted: (_) {
                    if (i == fields.length - 1) {
                      _calculate();
                    } else {
                      _focus[fields[i + 1].key]!.requestFocus();
                    }
                  },
                  validator: (text) =>
                      pvcFieldError(_shape, fields[i], text ?? '') ??
                      (_inputError?.field == fields[i].key
                          ? _inputError?.message
                          : null)))
      ]),
      if (_shape == PvcShape.l)
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DropdownButtonFormField<String>(
                initialValue: _corner,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Room steps in at'),
                items: const [
                  DropdownMenuItem(value: 'tr', child: Text('Top right')),
                  DropdownMenuItem(value: 'tl', child: Text('Top left')),
                  DropdownMenuItem(value: 'br', child: Text('Bottom right')),
                  DropdownMenuItem(value: 'bl', child: Text('Bottom left'))
                ],
                onChanged: (value) {
                  if (value == null) return;
                  _invalidate();
                  setState(() => _corner = value);
                })),
    ]);
  }
}
