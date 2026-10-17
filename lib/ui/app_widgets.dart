import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_theme.dart';
import 'app_styles.dart';

class AppConversionField extends StatelessWidget {
  const AppConversionField(
      {super.key,
      required this.label,
      required this.controller,
      this.labelWidth = 118,
      this.maxLines = 1,
      this.allowNegative = false});

  final String label;
  final TextEditingController controller;
  final double labelWidth;
  final int maxLines;
  final bool allowNegative;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        decoration: const BoxDecoration(
            color: AppColors.softSurface, borderRadius: AppRadii.r10),
        child: LayoutBuilder(
            builder: (context, constraints) => Row(children: [
                  SizedBox(
                      width: labelWidth.clamp(0, constraints.maxWidth * .55),
                      child: Text(label,
                          style: AppTypography.label,
                          maxLines: maxLines,
                          overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Container(
                      width: 1, height: 24, color: AppColors.inputDivider),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.numberWithOptions(
                              decimal: true, signed: allowNegative),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(
                                allowNegative
                                    ? r'^-?\d*\.?\d*'
                                    : r'^\d*\.?\d*'))
                          ],
                          decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              hintText: '0',
                              hintStyle: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  color: AppColors.hint),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 7)),
                          style: AppTypography.input)),
                ])),
      );
}

class AppNumberField extends StatelessWidget {
  const AppNumberField(
      {super.key,
      required this.label,
      required this.controller,
      required this.validator,
      this.integerOnly = false,
      this.allowCommaSeparated = false,
      this.onFieldSubmitted,
      this.focusNode,
      this.textInputAction,
      this.labelAbove = false,
      this.hint,
      this.prefixIcon});

  final String label;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final bool integerOnly;
  final bool allowCommaSeparated;
  final ValueChanged<String>? onFieldSubmitted;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final bool labelAbove;
  final String? hint;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      // Above-label forms reveal the complete field, not just its caret.
      scrollPadding: labelAbove ? EdgeInsets.zero : const EdgeInsets.all(20),
      controller: controller,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      keyboardType: allowCommaSeparated
          ? TextInputType.text
          : TextInputType.numberWithOptions(decimal: !integerOnly),
      inputFormatters: allowCommaSeparated
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\s]'))]
          : integerOnly
              ? [FilteringTextInputFormatter.digitsOnly]
              : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
      decoration: InputDecoration(
          labelText: labelAbove ? null : label,
          errorMaxLines: labelAbove ? 3 : null,
          hintText: hint,
          prefixIcon: prefixIcon == null
              ? null
              : Icon(prefixIcon, color: AppColors.neutralMuted)),
      validator: validator,
    );
    return !labelAbove
        ? field
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: AppTypography.label),
              const SizedBox(height: 4),
              Semantics(label: label, child: field),
            ],
          );
  }
}

class AppMetric extends StatelessWidget {
  const AppMetric({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTypography.text20BoldInk),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.text14Secondarytext),
        ],
      );
}
