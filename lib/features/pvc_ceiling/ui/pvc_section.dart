import 'package:flutter/material.dart';
import '../../../ui/app_colors.dart';
import '../../../ui/app_typography.dart';

class PvcSection extends StatelessWidget {
  final String title;
  final Widget child;
  final bool first;
  const PvcSection(
      {super.key,
      required this.title,
      required this.child,
      this.first = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: first ? 0 : 22),
      padding: const EdgeInsets.only(top: 22),
      decoration: first
          ? null
          : const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.text20BoldInk),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
