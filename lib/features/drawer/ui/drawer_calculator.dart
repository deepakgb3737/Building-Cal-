import 'package:grid_ceiling_calculator/ui/app_styles.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:grid_ceiling_calculator/features/drawer/logic/drawer_calculation_service.dart';
import 'package:grid_ceiling_calculator/core/input_validation.dart';
import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/ui/app_widgets.dart';

class DrawerCalculatorScreen extends StatefulWidget {
  const DrawerCalculatorScreen({super.key});

  @override
  State<DrawerCalculatorScreen> createState() => _DrawerCalculatorScreenState();
}

class _DrawerCalculatorScreenState extends State<DrawerCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();

  final _totalHeightController = TextEditingController();
  final _drawerCountController = TextEditingController(text: '2');
  final _topEmptyController = TextEditingController(text: '9');
  final _bottomEmptyController = TextEditingController(text: '9');
  final _gapController = TextEditingController(text: '3');
  final _oneCustomHeightController = TextEditingController();
  final _multipleCustomHeightsController = TextEditingController();

  DrawerCalcMode _mode = DrawerCalcMode.equal;
  DrawerCalcResult? _result;
  String? _errorMessage;

  @override
  void dispose() {
    _totalHeightController.dispose();
    _drawerCountController.dispose();
    _topEmptyController.dispose();
    _bottomEmptyController.dispose();
    _gapController.dispose();
    _oneCustomHeightController.dispose();
    _multipleCustomHeightsController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) {
      setState(() => _result = null);
      return;
    }
    try {
      final result = DrawerCalculationService.calculate(
        height: double.parse(_totalHeightController.text.trim()),
        count: int.parse(_drawerCountController.text.trim()),
        top: double.parse(_topEmptyController.text.trim()),
        bottom: double.parse(_bottomEmptyController.text.trim()),
        gap: double.parse(_gapController.text.trim()),
        mode: _mode,
        customHeight: double.tryParse(_oneCustomHeightController.text.trim()),
        customHeights: DrawerCalculationService.parseCustomHeights(
                _multipleCustomHeightsController.text) ??
            [],
      );
      setState(() {
        _result = result;
        _errorMessage = null;
      });
    } on FormatException catch (error) {
      setState(() {
        _result = null;
        _errorMessage = error.message;
      });
    }
  }

  void _reset() {
    _totalHeightController.clear();
    _drawerCountController.text = '2';
    _topEmptyController.text = '9';
    _bottomEmptyController.text = '9';
    _gapController.text = '3';
    _oneCustomHeightController.clear();
    _multipleCustomHeightsController.clear();
    setState(() {
      _mode = DrawerCalcMode.equal;
      _result = null;
      _errorMessage = null;
    });
  }

  String _fmt(double value) => value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drawer Calculator'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 390;
            final horizontalPadding = isNarrow ? 12.0 : 16.0;
            final cardPadding = isNarrow ? 12.0 : 16.0;
            return SingleChildScrollView(
              padding: EdgeInsets.all(horizontalPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(cardPadding),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: AppRadii.r12,
                          border: Border.all(color: AppColors.lightBorder),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Drawer Type',
                                style: AppTypography.text14W700Ink,
                              ),
                              const SizedBox(height: 6),
                              RadioGroup<DrawerCalcMode>(
                                groupValue: _mode,
                                onChanged: (value) =>
                                    setState(() => _mode = value!),
                                child: const Material(
                                  color: AppColors.white,
                                  child: Column(
                                    children: [
                                      RadioListTile<DrawerCalcMode>(
                                        value: DrawerCalcMode.equal,
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                        title: Text('Equal Drawers'),
                                      ),
                                      RadioListTile<DrawerCalcMode>(
                                        value: DrawerCalcMode.oneCustom,
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                        title: Text('ONE CUSTOM DRAWER'),
                                      ),
                                      RadioListTile<DrawerCalcMode>(
                                        value: DrawerCalcMode.multipleCustom,
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                        title: Text('MULTIPLE CUSTOM DRAWERS'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildInput(
                                label: 'H = Total Height (mm)',
                                controller: _totalHeightController,
                                validator: InputValidation.positiveNumber,
                              ),
                              const SizedBox(height: 10),
                              _buildInput(
                                label: 'N = Number of Drawers',
                                controller: _drawerCountController,
                                validator: InputValidation.positiveCount,
                                integerOnly: true,
                              ),
                              const SizedBox(height: 10),
                              if (isNarrow)
                                Column(
                                  children: [
                                    _buildInput(
                                      label: 'Top Empty (mm)',
                                      controller: _topEmptyController,
                                      validator:
                                          InputValidation.nonNegativeNumber,
                                    ),
                                    const SizedBox(height: 10),
                                    _buildInput(
                                      label: 'Bottom Empty (mm)',
                                      controller: _bottomEmptyController,
                                      validator:
                                          InputValidation.nonNegativeNumber,
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInput(
                                        label: 'Top Empty (mm)',
                                        controller: _topEmptyController,
                                        validator:
                                            InputValidation.nonNegativeNumber,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildInput(
                                        label: 'Bottom Empty (mm)',
                                        controller: _bottomEmptyController,
                                        validator:
                                            InputValidation.nonNegativeNumber,
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 10),
                              _buildInput(
                                label: 'G = Gap Between Drawers (mm)',
                                controller: _gapController,
                                validator: InputValidation.nonNegativeNumber,
                              ),
                              if (_mode == DrawerCalcMode.oneCustom) ...[
                                const SizedBox(height: 10),
                                _buildInput(
                                  label: 'C = Custom Drawer Height (mm)',
                                  controller: _oneCustomHeightController,
                                  validator: InputValidation.positiveNumber,
                                ),
                              ],
                              if (_mode == DrawerCalcMode.multipleCustom) ...[
                                const SizedBox(height: 10),
                                _buildInput(
                                  label:
                                      'Custom Drawer Heights (mm, comma separated)',
                                  controller: _multipleCustomHeightsController,
                                  allowCommaSeparated: true,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Required';
                                    }
                                    return DrawerCalculationService
                                                .parseCustomHeights(value) ==
                                            null
                                        ? 'Use comma-separated numbers'
                                        : null;
                                  },
                                ),
                              ],
                              const SizedBox(height: 14),
                              if (isNarrow)
                                Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _calculate,
                                        child: const Text('Calculate'),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        onPressed: _reset,
                                        child: const Text('Reset'),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _calculate,
                                        child: const Text('Calculate'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    OutlinedButton(
                                      onPressed: _reset,
                                      style: AppButtonStyles.secondaryCompact,
                                      child: const Text('Reset'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_errorMessage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorSurface,
                            borderRadius: AppRadii.r10,
                            border: Border.all(color: AppColors.errorBorder),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: AppTypography.text13W600Error,
                          ),
                        ),
                      if (_result != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.softSurface,
                            borderRadius: AppRadii.r12,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Result',
                                style: AppTypography.text16W700Text,
                              ),
                              const SizedBox(height: 10),
                              _row(
                                'Mode',
                                _result!.mode == DrawerCalcMode.equal
                                    ? 'Equal Drawers'
                                    : _result!.mode == DrawerCalcMode.oneCustom
                                        ? 'ONE CUSTOM DRAWER'
                                        : 'MULTIPLE CUSTOM DRAWERS',
                              ),
                              if (_result!.mode == DrawerCalcMode.equal)
                                _row('Drawer Height',
                                    '${_fmt(_result!.drawerHeightMm)} mm'),
                              if (_result!.mode ==
                                  DrawerCalcMode.oneCustom) ...[
                                _row('Custom Drawer (C)',
                                    '${_fmt(_result!.customDrawerHeightMm!)} mm'),
                                _row(
                                    'Other ${_result!.drawerCount - 1} Drawers',
                                    '${_fmt(_result!.remainingDrawerHeightMm!)} mm each'),
                              ],
                              if (_result!.mode ==
                                  DrawerCalcMode.multipleCustom) ...[
                                _row(
                                  'Custom Drawers',
                                  _result!.customDrawerHeightsMm
                                      .map(_fmt)
                                      .join(', '),
                                ),
                                _row(
                                  'Remaining ${_result!.remainingDrawerCount} Drawers',
                                  '${_fmt(_result!.remainingDrawerHeightMm!)} mm each',
                                ),
                              ],
                              _row('Top + Bottom Empty (E)',
                                  '${_fmt(_result!.totalEmptyMm)} mm'),
                              _row(
                                'Gap Space ((N-1)×G)',
                                '${_fmt(_result!.totalGapSpaceMm)} mm',
                              ),
                              _row(
                                'Total Non-Drawer Space',
                                '${_fmt(_result!.totalNonDrawerSpaceMm)} mm',
                              ),
                              _row('Total Height (H)',
                                  '${_fmt(_result!.totalHeightMm)} mm'),
                              _row('Drawer Count (N)',
                                  '${_result!.drawerCount}'),
                              _row('Gap (G)', '${_fmt(_result!.gapMm)} mm'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDrawerLayoutCard(_result!),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    bool integerOnly = false,
    bool allowCommaSeparated = false,
  }) {
    return AppNumberField(
        label: label,
        controller: controller,
        validator: validator,
        integerOnly: integerOnly,
        allowCommaSeparated: allowCommaSeparated);
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  AppTypography.text13.copyWith(color: AppColors.secondaryText),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: AppTypography.text13W700.copyWith(color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerLayoutCard(DrawerCalcResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadii.r12,
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = MediaQuery.sizeOf(context).height;
          final sectionCount = _visualSectionCount(result);
          final desiredHeight = 70.0 + (sectionCount * 28.0);
          final widthBasedHeight = constraints.maxWidth * 0.95;
          final boxHeight = desiredHeight
              .clamp(220.0, screenHeight * 0.62)
              .toDouble()
              .clamp(220.0, widthBasedHeight > 220 ? widthBasedHeight : 220.0);
          final sections = _buildDrawerSections(result, boxHeight);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '2D Drawer Layout',
                style: AppTypography.text16W700Text,
              ),
              const SizedBox(height: 4),
              const Text(
                'Front view (scaled from calculated measurements)',
                style: AppTypography.text12Muted,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      height: boxHeight,
                      decoration: BoxDecoration(
                        color: AppColors.softSurface,
                        borderRadius: AppRadii.r10,
                        border: Border.all(
                          color: AppColors.secondaryText,
                          width: 1.2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: AppRadii.r9,
                        child: Column(children: sections),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 58,
                    height: boxHeight,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: AppRadii.r10,
                      border: Border.all(color: AppColors.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'H\n${_fmt(result.totalHeightMm)} mm',
                      textAlign: TextAlign.center,
                      style: AppTypography.text12W700
                          .copyWith(color: AppColors.text),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  int _visualSectionCount(DrawerCalcResult result) {
    var count = result.drawerHeightsMm.length; // drawer rows
    if (result.gapMm > 0 && result.drawerHeightsMm.length > 1) {
      count += result.drawerHeightsMm.length - 1; // gap rows
    }
    if (result.topEmptyMm > 0) count += 1;
    if (result.bottomEmptyMm > 0) count += 1;
    return count;
  }

  List<Widget> _buildDrawerSections(DrawerCalcResult result, double boxHeight) {
    final parts = <_DrawerSection>[];
    if (result.topEmptyMm > 0) {
      parts.add(_DrawerSection(
        kind: _DrawerSectionKind.empty,
        sizeMm: result.topEmptyMm,
        label: 'Top Empty ${_fmt(result.topEmptyMm)} mm',
      ));
    }

    for (var i = 0; i < result.drawerHeightsMm.length; i++) {
      final drawerHeight = result.drawerHeightsMm[i];
      parts.add(_DrawerSection(
        kind: _DrawerSectionKind.drawer,
        sizeMm: drawerHeight,
        label: '${result.drawerLabels[i]}  ${_fmt(drawerHeight)} mm',
      ));
      if (i < result.drawerHeightsMm.length - 1 && result.gapMm > 0) {
        parts.add(_DrawerSection(
          kind: _DrawerSectionKind.gap,
          sizeMm: result.gapMm,
          label: 'Gap ${_fmt(result.gapMm)} mm',
        ));
      }
    }

    if (result.bottomEmptyMm > 0) {
      parts.add(_DrawerSection(
        kind: _DrawerSectionKind.empty,
        sizeMm: result.bottomEmptyMm,
        label: 'Bottom Empty ${_fmt(result.bottomEmptyMm)} mm',
      ));
    }

    final rawWeights = parts.map((part) {
      switch (part.kind) {
        case _DrawerSectionKind.drawer:
          return part.sizeMm + 120;
        case _DrawerSectionKind.gap:
          return part.sizeMm + 35;
        case _DrawerSectionKind.empty:
          return part.sizeMm + 50;
      }
    }).toList();

    final flexes = rawWeights
        .map((w) => w.isFinite && w > 0 ? w.round().clamp(1, 1000000) : 1)
        .toList();
    final totalFlex = flexes.fold<int>(0, (sum, f) => sum + f);

    return List.generate(parts.length, (index) {
      final section = parts[index];
      final height =
          totalFlex > 0 ? (boxHeight * flexes[index] / totalFlex) : 0.0;
      final showLabel = height >= 14;
      return Expanded(
        flex: flexes[index],
        child: Container(
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _sectionColor(section.kind),
            border: Border(
              bottom: BorderSide(
                color: index == parts.length - 1
                    ? AppColors.transparent
                    : AppColors.strongBorder,
              ),
            ),
          ),
          child: showLabel
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      section.label,
                      textAlign: TextAlign.center,
                      style: AppTypography.text12.copyWith(
                          fontWeight: section.kind == _DrawerSectionKind.drawer
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: AppColors.text),
                    ),
                  ),
                )
              : null,
        ),
      );
    });
  }

  Color _sectionColor(_DrawerSectionKind kind) {
    switch (kind) {
      case _DrawerSectionKind.drawer:
        return AppColors.border;
      case _DrawerSectionKind.gap:
        return AppColors.surfaceAlt;
      case _DrawerSectionKind.empty:
        return AppColors.softSurface;
    }
  }
}

enum _DrawerSectionKind {
  empty,
  drawer,
  gap,
}

class _DrawerSection {
  final _DrawerSectionKind kind;
  final double sizeMm;
  final String label;

  const _DrawerSection({
    required this.kind,
    required this.sizeMm,
    required this.label,
  });
}
