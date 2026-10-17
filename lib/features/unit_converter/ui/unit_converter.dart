import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/ui/app_widgets.dart';
import 'package:grid_ceiling_calculator/features/unit_converter/logic/unit_conversion_service.dart';

class UnitConverterScreen extends StatefulWidget {
  const UnitConverterScreen({super.key});

  @override
  State<UnitConverterScreen> createState() => _UnitConverterScreenState();
}

class _UnitConverterScreenState extends State<UnitConverterScreen> {
  late final List<String> _units;
  late final Map<String, TextEditingController> _controllers;
  bool _isInternalUpdate = false;

  @override
  void initState() {
    super.initState();
    _units = UnitConversionService.units;
    _controllers = {
      for (final unit in _units) unit: TextEditingController(),
    };

    for (final unit in _units) {
      _controllers[unit]!.addListener(() => _onUnitValueChanged(unit));
    }
  }

  @override
  void dispose() {
    for (final unit in _units) {
      _controllers[unit]!.dispose();
    }
    super.dispose();
  }

  void _onUnitValueChanged(String sourceUnit) {
    if (_isInternalUpdate) {
      return;
    }

    final sourceText = _controllers[sourceUnit]!.text.trim();
    if (sourceText.isEmpty) {
      _clearAll();
      return;
    }

    final sourceValue = _tryParseNumericInput(sourceText);
    if (sourceValue == null) {
      return;
    }

    _isInternalUpdate = true;
    for (final targetUnit in _units) {
      if (targetUnit == sourceUnit) {
        continue;
      }
      final converted = UnitConversionService.convert(
        value: sourceValue,
        fromUnit: sourceUnit,
        toUnit: targetUnit,
      );
      _controllers[targetUnit]!.text = _formatResult(converted);
    }
    _isInternalUpdate = false;
  }

  double? _tryParseNumericInput(String text) {
    if (text == '-' || text == '.' || text == '-.') {
      return null;
    }
    return double.tryParse(text);
  }

  String _formatResult(double value) {
    if (value.isNaN || value.isInfinite) {
      return '';
    }
    final absoluteValue = value.abs();
    final raw = (absoluteValue > 0 && absoluteValue < 0.0001) ||
            absoluteValue >= 1000000000
        ? value.toStringAsExponential(4)
        : value.toStringAsFixed(4);
    final text =
        raw.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return text == '-0' ? '0' : text;
  }

  void _clearAll() {
    _isInternalUpdate = true;
    for (final unit in _units) {
      _controllers[unit]!.clear();
    }
    _isInternalUpdate = false;
    setState(() {});
  }

  String _unitShort(String unit) {
    switch (unit) {
      case UnitConversionService.kilometre:
        return 'km';
      case UnitConversionService.metre:
        return 'm';
      case UnitConversionService.centimetre:
        return 'cm';
      case UnitConversionService.millimetre:
        return 'mm';
      case UnitConversionService.mile:
        return 'mi';
      case UnitConversionService.foot:
        return 'ft';
      case UnitConversionService.inch:
        return 'in';
      case UnitConversionService.nauticalMile:
        return 'nmi';
      default:
        return unit;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _units.map(_buildUnitRow).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unit Converter'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                itemBuilder: (context, index) => rows[index],
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: rows.length,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: _clearAll,
                  child: const Text(
                    'Reset',
                    style: AppTypography.textW600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitRow(String unit) => AppConversionField(
        label: '$unit (${_unitShort(unit)})',
        controller: _controllers[unit]!,
        allowNegative: true,
      );
}
