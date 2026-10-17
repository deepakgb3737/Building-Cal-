import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grid_ceiling_calculator/core/input_validation.dart';
import 'app_theme.dart';
import 'app_colors.dart';
import 'app_widgets.dart';

class EstimateInput {
  const EstimateInput(
    this.id,
    this.label, {
    this.initial = '',
    this.zeroAllowed = false,
    this.whole = false,
    this.max = 1000000,
  });
  final String id;
  final String label;
  final String initial;
  final bool zeroAllowed;
  final bool whole;
  final double max;
}

class EstimateValue {
  const EstimateValue(this.label, this.value);
  final String label;
  final String value;
}

class MaterialEstimateScreen extends StatefulWidget {
  const MaterialEstimateScreen(
      {super.key,
      required this.title,
      required this.description,
      required this.inputs,
      required this.calculate,
      required this.notes});
  final String title;
  final String description;
  final List<EstimateInput> inputs;
  final List<EstimateValue> Function(Map<String, double>) calculate;
  final String notes;

  @override
  State<MaterialEstimateScreen> createState() => _MaterialEstimateScreenState();
}

class _MaterialEstimateScreenState extends State<MaterialEstimateScreen> {
  final _form = GlobalKey<FormState>();
  final _resultKey = GlobalKey();
  late final Map<String, TextEditingController> _controllers = {
    for (final field in widget.inputs)
      field.id: TextEditingController(text: field.initial)..addListener(_clear),
  };
  List<EstimateValue>? _result;
  String? _error;

  void _clear() {
    if (_result != null || _error != null) {
      setState(() {
        _result = null;
        _error = null;
      });
    }
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    try {
      final values = {
        for (final entry in _controllers.entries)
          entry.key: double.parse(entry.value.text.trim())
      };
      final result = widget.calculate(values);
      setState(() {
        _result = result;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _resultKey.currentContext == null) return;
        Scrollable.ensureVisible(_resultKey.currentContext!,
            duration: const Duration(milliseconds: 250));
      });
    } on ArgumentError catch (error) {
      setState(() {
        _result = null;
        _error = error.message.toString();
      });
    }
  }

  Future<void> _copy() async {
    final text = StringBuffer(widget.title)..writeln();
    for (final field in widget.inputs) {
      text.writeln('${field.label}: ${_controllers[field.id]!.text}');
    }
    for (final row in _result!) {
      text.writeln('${row.label}: ${row.value}');
    }
    text.writeln(widget.notes);
    await Clipboard.setData(ClipboardData(text: text.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Estimate copied')));
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(widget.description,
                        style: AppTypography.text14Secondarytext),
                    const SizedBox(height: 20),
                    for (final field in widget.inputs) ...[
                      AppNumberField(
                          key: ValueKey(field.id),
                          label: field.label,
                          controller: _controllers[field.id]!,
                          integerOnly: field.whole,
                          validator: (value) {
                            final error = field.whole
                                ? InputValidation.positiveCount(value)
                                : field.zeroAllowed
                                    ? InputValidation.nonNegativeNumber(value)
                                    : InputValidation.positiveNumber(value);
                            if (error != null) return error;
                            return double.parse(value!) > field.max
                                ? 'Maximum allowed: ${field.max}'
                                : null;
                          }),
                      const SizedBox(height: 14),
                    ],
                    ElevatedButton(
                        onPressed: _calculate, child: const Text('Calculate')),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!,
                              style: AppTypography.text14Secondarytext
                                  .copyWith(color: AppColors.error))),
                    if (_result != null) ...[
                      const SizedBox(height: 24),
                      Text('Your estimate',
                          key: _resultKey, style: AppTypography.text20BoldInk),
                      const SizedBox(height: 12),
                      for (final row in _result!)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Wrap(spacing: 12, runSpacing: 4, children: [
                              Text('${row.label}:',
                                  style: AppTypography.text14Secondarytext),
                              SelectableText(row.value,
                                  style: AppTypography.text14W600Text),
                            ])),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                          onPressed: _copy,
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('Copy estimate')),
                    ],
                    const SizedBox(height: 20),
                    Text(widget.notes, style: AppTypography.text12Muted),
                  ],
                )),
          )),
        )),
      );
}
