import 'package:grid_ceiling_calculator/ui/app_styles.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grid_ceiling_calculator/features/area_calculator/logic/area_conversion_service.dart';

class AreaCalculatorScreen extends StatefulWidget {
  const AreaCalculatorScreen({super.key});

  @override
  State<AreaCalculatorScreen> createState() => _AreaCalculatorScreenState();
}

class _AreaCalculatorScreenState extends State<AreaCalculatorScreen> {
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();

  String _selectedUnit = AreaConversionService.meter;
  double _areaSqFt = 0.0;
  double _areaSqM = 0.0;
  double _areaSqIn = 0.0;
  double _areaSqCm = 0.0;
  bool _hasResult = false;

  @override
  void initState() {
    super.initState();
    _widthController.addListener(_calculateArea);
    _lengthController.addListener(_calculateArea);
  }

  @override
  void dispose() {
    _widthController.removeListener(_calculateArea);
    _lengthController.removeListener(_calculateArea);
    _widthController.dispose();
    _lengthController.dispose();
    super.dispose();
  }

  void _calculateArea() {
    final width = double.tryParse(_widthController.text.trim());
    final length = double.tryParse(_lengthController.text.trim());

    if (width == null || length == null || width <= 0 || length <= 0) {
      setState(() {
        _hasResult = false;
        _areaSqFt = 0.0;
        _areaSqM = 0.0;
        _areaSqIn = 0.0;
        _areaSqCm = 0.0;
      });
      return;
    }

    final sqFt = AreaConversionService.calculateSquareFeet(
      width: width,
      length: length,
      inputUnit: _selectedUnit,
    );
    final sqM = AreaConversionService.calculateSquareMetres(
      width: width,
      length: length,
      inputUnit: _selectedUnit,
    );
    final sqIn = AreaConversionService.calculateSquareInches(
      width: width,
      length: length,
      inputUnit: _selectedUnit,
    );
    final sqCm = AreaConversionService.calculateSquareCentimetres(
      width: width,
      length: length,
      inputUnit: _selectedUnit,
    );

    setState(() {
      _areaSqFt = sqFt;
      _areaSqM = sqM;
      _areaSqIn = sqIn;
      _areaSqCm = sqCm;
      _hasResult = true;
    });
  }

  String _formatNumber(double value) {
    if (value.isNaN || value.isInfinite) {
      return '0.00';
    }
    return value.toStringAsFixed(2);
  }

  String _dimensionUnitLabel() {
    return _selectedUnit == AreaConversionService.meter ? 'm' : 'ft';
  }

  void _reset() {
    _widthController.clear();
    _lengthController.clear();
    setState(() {
      _hasResult = false;
      _areaSqFt = 0.0;
      _areaSqM = 0.0;
      _areaSqIn = 0.0;
      _areaSqCm = 0.0;
      _selectedUnit = AreaConversionService.meter;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Area Calculator'),
        backgroundColor: AppColors.legacyBlue,
        foregroundColor: AppColors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadii.r12,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter Dimensions',
                      style: AppTypography.text18BoldLegacyblue,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _widthController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Width',
                              border: OutlineInputBorder(
                                borderRadius: AppRadii.r8,
                              ),
                              filled: true,
                              fillColor: AppColors.greyLight,
                              prefixIcon: Icon(Icons.straighten,
                                  color: AppColors.legacyBlue),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.greyBorder),
                              borderRadius: AppRadii.r8,
                              color: AppColors.white,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedUnit,
                                isExpanded: true,
                                items: AreaConversionService.supportedUnits
                                    .map((String unit) {
                                  return DropdownMenuItem<String>(
                                    value: unit,
                                    child:
                                        Text(unit, style: AppTypography.text14),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedUnit = newValue;
                                    });
                                    _calculateArea();
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _lengthController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Length',
                        border: OutlineInputBorder(
                          borderRadius: AppRadii.r8,
                        ),
                        filled: true,
                        fillColor: AppColors.greyLight,
                        prefixIcon:
                            Icon(Icons.straighten, color: AppColors.legacyBlue),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _reset,
                        style: AppButtonStyles.legacyReset,
                        child: const Text('Reset'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_hasResult)
              Card(
                elevation: 4,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadii.r12,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Area Result',
                        style: AppTypography.text20BoldSuccess,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAreaResultItem(
                              label: 'Square Centimetre (sq cm)',
                              value: '${_formatNumber(_areaSqCm)} sq cm',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildAreaResultItem(
                              label: 'Square Inch (sq in)',
                              value: '${_formatNumber(_areaSqIn)} sq in',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAreaResultItem(
                              label: 'Square Feet (sq ft)',
                              value: '${_formatNumber(_areaSqFt)} sq ft',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildAreaResultItem(
                              label: 'Square Metre (sq m)',
                              value: '${_formatNumber(_areaSqM)} sq m',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Width: ${_widthController.text} ${_dimensionUnitLabel()} × Length: ${_lengthController.text} ${_dimensionUnitLabel()}',
                        style: AppTypography.text14Greymuted,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaResultItem({
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blueTint,
        borderRadius: AppRadii.r10,
        border: Border.all(color: AppColors.blueBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.text13BoldDrawingink,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTypography.text16BoldDrawingink,
          ),
        ],
      ),
    );
  }
}
