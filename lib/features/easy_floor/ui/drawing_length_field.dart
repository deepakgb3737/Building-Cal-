import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/ui/app_widgets.dart';
import 'package:grid_ceiling_calculator/ui/app_typography.dart';
import '../logic/drawing_point.dart';

class DrawingLengthField extends StatelessWidget {
  const DrawingLengthField(
      {super.key,
      required this.label,
      required this.controller,
      required this.unit,
      this.onFieldSubmitted,
      this.focusNode,
      this.textInputAction,
      this.originalMm,
      this.validationError,
      this.labelAbove = false});
  final String label;
  final TextEditingController controller;
  final DrawingUnit unit;
  final ValueChanged<String>? onFieldSubmitted;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final bool labelAbove;
  final double? originalMm;
  final String? validationError;
  String? validate(String? text) {
    final mm =
        originalMm != null && text == unit.input(originalMm!, decimalPlaces: 2)
            ? originalMm
            : unit.readMm(text ?? '');
    if (mm == null || !mm.isFinite || mm < 10 || mm > 10000000) {
      return unit == DrawingUnit.feetInches
          ? 'Enter feet and inches, e.g. 11 5.8 (inches < 12)'
          : 'Enter a size from 10 mm to 10,000 m';
    }
    return validationError;
  }

  @override
  Widget build(BuildContext context) {
    final title =
        '$label (${unit == DrawingUnit.feetInches ? 'feet inches' : unit.symbol})';
    if (unit != DrawingUnit.feetInches) {
      return AppNumberField(
          label: title,
          controller: controller,
          onFieldSubmitted: onFieldSubmitted,
          focusNode: focusNode,
          textInputAction: textInputAction,
          labelAbove: labelAbove,
          validator: validate);
    }
    final field = TextFormField(
        scrollPadding: labelAbove ? EdgeInsets.zero : const EdgeInsets.all(20),
        controller: controller,
        focusNode: focusNode,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        validator: validate,
        keyboardType: TextInputType.text,
        decoration: InputDecoration(
            labelText: labelAbove ? null : title,
            helperMaxLines: 2,
            errorMaxLines: 3,
            helperText: labelAbove ? null : 'Example: 11 5.8 = 11 ft 5.8 in'));
    return !labelAbove
        ? field
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppTypography.label),
              const SizedBox(height: 4),
              Semantics(label: title, child: field)
            ],
          );
  }
}
