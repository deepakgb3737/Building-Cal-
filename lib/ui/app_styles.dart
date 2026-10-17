import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppRadii {
  static const r14 = BorderRadius.all(Radius.circular(14));
  static const r16 = BorderRadius.all(Radius.circular(16));
  static const r8 = BorderRadius.all(Radius.circular(8));
  static const r4 = BorderRadius.all(Radius.circular(4));
  static const r6 = BorderRadius.all(Radius.circular(6));
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r10 = BorderRadius.all(Radius.circular(10));
  static const r9 = BorderRadius.all(Radius.circular(9));
  static const r999 = BorderRadius.all(Radius.circular(999));
}

abstract final class AppButtonStyles {
  static const drawingDialogAction = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(44, 44)),
    padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
  );
  static final primary = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: AppRadii.r10,
    ),
    padding: const EdgeInsets.symmetric(vertical: 14),
  );
  static final secondary = OutlinedButton.styleFrom(
    foregroundColor: AppColors.ink,
    side: const BorderSide(color: AppColors.fieldBorder),
    shape: const RoundedRectangleBorder(
      borderRadius: AppRadii.r10,
    ),
    padding: const EdgeInsets.symmetric(vertical: 14),
  );
  static final secondaryCompact = OutlinedButton.styleFrom(
    foregroundColor: AppColors.ink,
    side: const BorderSide(color: AppColors.fieldBorder),
    shape: const RoundedRectangleBorder(
      borderRadius: AppRadii.r10,
    ),
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
  );
  static final roomPrimary = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.white,
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: const RoundedRectangleBorder(
      borderRadius: AppRadii.r8,
    ),
  );
  static final roomReset = ElevatedButton.styleFrom(
    backgroundColor: AppColors.white,
    foregroundColor: AppColors.ink,
    elevation: 0,
    side: const BorderSide(color: AppColors.fieldBorder),
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    shape: const RoundedRectangleBorder(
      borderRadius: AppRadii.r8,
    ),
  );
  static final legacyReset = ElevatedButton.styleFrom(
    backgroundColor: AppColors.greyMuted,
    foregroundColor: AppColors.white,
    padding: const EdgeInsets.symmetric(vertical: 12),
  );
}
