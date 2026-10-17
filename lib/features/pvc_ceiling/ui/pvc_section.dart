import 'package:flutter/material.dart';
import '../../../ui/app_colors.dart';
import '../../../ui/app_typography.dart';

class PvcSection extends StatelessWidget {
  final String title;
  final Widget child;
  final bool first;
  final Widget? trailing;
  const PvcSection(
      {super.key,
      required this.title,
      required this.child,
      this.trailing,
      this.first = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: first ? 0 : 22),
      padding: EdgeInsets.only(top: first ? 12 : 18),
      decoration: first
          ? null
          : const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trailing == null)
            Text(title, style: AppTypography.text17W700Text)
          else
            Row(children: [
              Expanded(child: Text(title, style: AppTypography.text17W700Text)),
              const SizedBox(width: 8),
              trailing!,
            ]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
