import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/ui/app_widgets.dart';
import 'package:grid_ceiling_calculator/features/area_converter/logic/area_unit_conversion_service.dart';

class AreaConverterScreen extends StatefulWidget {
  const AreaConverterScreen({super.key});

  @override
  State<AreaConverterScreen> createState() => _AreaConverterScreenState();
}

class _AreaConverterScreenState extends State<AreaConverterScreen> {
  final TextEditingController _sqmmController = TextEditingController();
  final TextEditingController _sqcmController = TextEditingController();
  final TextEditingController _sqinchController = TextEditingController();
  final TextEditingController _sqftController = TextEditingController();
  final TextEditingController _sqmController = TextEditingController();
  bool _isInternalUpdate = false;

  @override
  void initState() {
    super.initState();
    _sqmmController.addListener(
      () =>
          _onValueChanged(AreaUnitConversionService.sqmm, _sqmmController.text),
    );
    _sqcmController.addListener(
      () =>
          _onValueChanged(AreaUnitConversionService.sqcm, _sqcmController.text),
    );
    _sqinchController.addListener(
      () => _onValueChanged(
          AreaUnitConversionService.sqinch, _sqinchController.text),
    );
    _sqftController.addListener(
      () =>
          _onValueChanged(AreaUnitConversionService.sqft, _sqftController.text),
    );
    _sqmController.addListener(
      () => _onValueChanged(AreaUnitConversionService.sqm, _sqmController.text),
    );
  }

  @override
  void dispose() {
    _sqmmController.dispose();
    _sqcmController.dispose();
    _sqinchController.dispose();
    _sqftController.dispose();
    _sqmController.dispose();
    super.dispose();
  }

  void _onValueChanged(String sourceUnit, String value) {
    if (_isInternalUpdate) {
      return;
    }

    final sourceValue = _tryParseInput(value);
    if (value.trim().isEmpty) {
      _clearAll();
      return;
    }
    if (sourceValue == null) {
      return;
    }

    final controllers = <String, TextEditingController>{
      AreaUnitConversionService.sqmm: _sqmmController,
      AreaUnitConversionService.sqcm: _sqcmController,
      AreaUnitConversionService.sqinch: _sqinchController,
      AreaUnitConversionService.sqft: _sqftController,
      AreaUnitConversionService.sqm: _sqmController,
    };

    _isInternalUpdate = true;
    for (final entry in controllers.entries) {
      if (entry.key == sourceUnit) {
        continue;
      }
      final converted = AreaUnitConversionService.convert(
        value: sourceValue,
        fromUnit: sourceUnit,
        toUnit: entry.key,
      );
      entry.value.text = _formatValue(converted);
    }
    _isInternalUpdate = false;
  }

  double? _tryParseInput(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed == '.' || trimmed == '-.') {
      return null;
    }
    return double.tryParse(trimmed);
  }

  String _formatValue(double value) {
    if (value.isNaN || value.isInfinite) {
      return '';
    }
    final absValue = value.abs();
    final raw = (absValue > 0 && absValue < 0.0001) || absValue >= 1e9
        ? value.toStringAsExponential(4)
        : value.toStringAsFixed(4);
    return raw.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  void _clearAll() {
    _isInternalUpdate = true;
    _sqmmController.clear();
    _sqcmController.clear();
    _sqinchController.clear();
    _sqftController.clear();
    _sqmController.clear();
    _isInternalUpdate = false;
  }

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      _buildField('Square Millimetre (mm²)', _sqmmController),
      _buildField('Square Centimetre (cm²)', _sqcmController),
      _buildField('Square Inch (in²)', _sqinchController),
      _buildField('Square Foot (ft²)', _sqftController),
      _buildField('Square Metre (m²)', _sqmController),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Area Converter'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                itemBuilder: (context, index) => fields[index],
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: fields.length,
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

  Widget _buildField(String label, TextEditingController controller) =>
      AppConversionField(
          label: label, controller: controller, labelWidth: 150, maxLines: 2);
}
