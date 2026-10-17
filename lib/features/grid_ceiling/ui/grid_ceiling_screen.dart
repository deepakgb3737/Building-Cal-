import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/core/input_validation.dart';
import 'package:grid_ceiling_calculator/ui/app_widgets.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/grid_ceiling_calculator.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/enhanced_room_layout.dart';

class GridCeilingCalculatorScreen extends StatefulWidget {
  const GridCeilingCalculatorScreen({super.key});

  @override
  State<GridCeilingCalculatorScreen> createState() =>
      _GridCeilingCalculatorScreenState();
}

class _GridCeilingCalculatorScreenState
    extends State<GridCeilingCalculatorScreen> {
  final _widthController = TextEditingController();
  final _lengthController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  GridCeilingResult? _result;
  double _calculatedWidth = 0;
  double _calculatedLength = 0;
  bool _interactingWithDrawing = false;
  PlacementMode _placementMode = PlacementMode.centerBased;

  @override
  void initState() {
    super.initState();
    _widthController.addListener(_invalidateResult);
    _lengthController.addListener(_invalidateResult);
  }

  void _invalidateResult() {
    if (_result == null) return;
    setState(() {
      _result = null;
      _interactingWithDrawing = false;
    });
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final width = double.parse(_widthController.text);
    final length = double.parse(_lengthController.text);
    final result =
        GridCeilingCalculator.calculate(width, length, mode: _placementMode);
    setState(() {
      _result = result;
      _calculatedWidth = width;
      _calculatedLength = length;
    });
  }

  void _reset() {
    _widthController.clear();
    _lengthController.clear();
    _formKey.currentState?.reset();
    setState(() {
      _result = null;
      _placementMode = PlacementMode.centerBased;
      _interactingWithDrawing = false;
    });
  }

  @override
  void dispose() {
    _widthController.dispose();
    _lengthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Grid Ceiling'), actions: [
          TextButton(onPressed: _reset, child: const Text('Reset')),
        ]),
        body: SafeArea(
            child: SingleChildScrollView(
          physics: _interactingWithDrawing
              ? const NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Form(
                      key: _formKey,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Room measurements',
                                style: AppTypography.text20BoldInk),
                            const SizedBox(height: 6),
                            const Text('Enter width and length in millimetres.',
                                style: AppTypography.text14Secondarytext),
                            const SizedBox(height: 20),
                            LayoutBuilder(builder: (context, constraints) {
                              final widthField = AppNumberField(
                                  label: 'Width (mm)',
                                  controller: _widthController,
                                  integerOnly: true,
                                  validator: (value) =>
                                      InputValidation.roomDimension(
                                          value, 'Width'));
                              final lengthField = AppNumberField(
                                  label: 'Length (mm)',
                                  controller: _lengthController,
                                  integerOnly: true,
                                  validator: (value) =>
                                      InputValidation.roomDimension(
                                          value, 'Length'));
                              return constraints.maxWidth >= 520
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                          Expanded(child: widthField),
                                          const SizedBox(width: 16),
                                          Expanded(child: lengthField)
                                        ])
                                  : Column(children: [
                                      widthField,
                                      const SizedBox(height: 16),
                                      lengthField
                                    ]);
                            }),
                            const SizedBox(height: 24),
                            const Text('Grid placement',
                                style: AppTypography.text16W700Text),
                            const SizedBox(height: 8),
                            RadioGroup<PlacementMode>(
                                groupValue: _placementMode,
                                onChanged: (mode) {
                                  if (mode == null) return;
                                  setState(() {
                                    _placementMode = mode;
                                    _result = null;
                                    _interactingWithDrawing = false;
                                  });
                                },
                                child: const Column(children: [
                                  RadioListTile<PlacementMode>(
                                      value: PlacementMode.centerBased,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text('Centered'),
                                      subtitle: Text('Default placement')),
                                  RadioListTile<PlacementMode>(
                                      value: PlacementMode.oneSide,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text('From one wall'),
                                      subtitle:
                                          Text('Start the grid from one side')),
                                ])),
                            const SizedBox(height: 16),
                            ElevatedButton(
                                onPressed: _calculate,
                                child: const Text('Calculate layout')),
                          ])),
                  if (_result != null) ...[
                    const SizedBox(height: 28),
                    const Divider(),
                    const SizedBox(height: 16),
                    EnhancedRoomLayoutScreen(
                        key: ValueKey(_result),
                        result: _result!,
                        width: _calculatedWidth,
                        length: _calculatedLength,
                        embedded: true,
                        onInteractionChanged: (active) {
                          if (_interactingWithDrawing == active) return;
                          setState(() => _interactingWithDrawing = active);
                        }),
                  ],
                ]),
          )),
        )),
      );
}
