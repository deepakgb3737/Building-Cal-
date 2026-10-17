import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTypography {
  static const fontFamily = 'Roboto';
  static const label = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.label,
      fontSize: 12,
      fontWeight: FontWeight.w600);
  static const input = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.text,
      fontSize: 14,
      fontWeight: FontWeight.w600);
  static const text12W600Label = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.label,
      fontSize: 12,
      fontWeight: FontWeight.w600);
  static const text14W600Text = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.text,
      fontSize: 14,
      fontWeight: FontWeight.w600);
  static const text15W600Muted = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.muted,
      fontSize: 15,
      fontWeight: FontWeight.w600);
  static const text17W700Text = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.text,
      fontSize: 17,
      fontWeight: FontWeight.w700);
  static const text14Secondarytext = TextStyle(
      fontFamily: fontFamily, color: AppColors.secondaryText, fontSize: 14);
  static const text11 = TextStyle(fontFamily: fontFamily, fontSize: 11);
  static const drawingToolLabel =
      TextStyle(fontFamily: fontFamily, fontSize: 11, height: 1.2);
  static const text15W700Primary = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.primary,
      fontSize: 15,
      fontWeight: FontWeight.w700);
  static const textW600Text = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.text,
      fontWeight: FontWeight.w600);
  static const textW700Primary = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.primary,
      fontWeight: FontWeight.w700);
  static const textW700 =
      TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700);
  static const text24BoldDrawingink = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.drawingInk,
      fontSize: 24,
      fontWeight: FontWeight.bold);
  static const text20BoldDrawingink = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.drawingInk,
      fontSize: 20,
      fontWeight: FontWeight.bold);
  static const text14BoldDrawingink = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.drawingInk,
      fontSize: 14,
      fontWeight: FontWeight.bold);
  static const text18BoldDrawingink = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.drawingInk,
      fontSize: 18,
      fontWeight: FontWeight.bold);
  static const text14 = TextStyle(fontFamily: fontFamily, fontSize: 14);
  static const text16 = TextStyle(fontFamily: fontFamily, fontSize: 16);
  static const text14W500 = TextStyle(
      fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w500);
  static const text16BoldDrawingink = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.drawingInk,
      fontSize: 16,
      fontWeight: FontWeight.bold);
  static const text16Mainrunner = TextStyle(
      fontFamily: fontFamily, color: AppColors.mainRunner, fontSize: 16);
  static const text12 = TextStyle(fontFamily: fontFamily, fontSize: 12);
  static const textDrawingink =
      TextStyle(fontFamily: fontFamily, color: AppColors.drawingInk);
  static const textDrawingtext =
      TextStyle(fontFamily: fontFamily, color: AppColors.drawingText);
  static const text14Drawingtext = TextStyle(
      fontFamily: fontFamily, color: AppColors.drawingText, fontSize: 14);
  static const text14W700Ink = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.ink,
      fontSize: 14,
      fontWeight: FontWeight.w700);
  static const text13W600Error = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.error,
      fontSize: 13,
      fontWeight: FontWeight.w600);
  static const text16W700Text = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.text,
      fontSize: 16,
      fontWeight: FontWeight.w700);
  static const text13Secondarytext = TextStyle(
      fontFamily: fontFamily, color: AppColors.secondaryText, fontSize: 13);
  static const text13W700Text = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.text,
      fontSize: 13,
      fontWeight: FontWeight.w700);
  static const text12Muted =
      TextStyle(fontFamily: fontFamily, color: AppColors.muted, fontSize: 12);
  static const text12W700Text = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.text,
      fontSize: 12,
      fontWeight: FontWeight.w700);
  static const text12Text =
      TextStyle(fontFamily: fontFamily, color: AppColors.text, fontSize: 12);
  static const text13W600Secondarytext = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.secondaryText,
      fontSize: 13,
      fontWeight: FontWeight.w600);
  static const text11Muted =
      TextStyle(fontFamily: fontFamily, color: AppColors.muted, fontSize: 11);
  static const text14W700Heading = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.heading,
      fontSize: 14,
      fontWeight: FontWeight.w700);
  static const text22BoldInk = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.ink,
      fontSize: 22,
      fontWeight: FontWeight.bold);
  static const text14W700Black87 = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.black87,
      fontSize: 14,
      fontWeight: FontWeight.w700);
  static const text16Bold = TextStyle(
      fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.bold);
  static const text20BoldInk = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.ink,
      fontSize: 20,
      fontWeight: FontWeight.bold);
  static const textBoldWhite = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.white,
      fontWeight: FontWeight.bold);
  static const text = TextStyle(fontFamily: fontFamily);
  static const textBoldDrawingink = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.drawingInk,
      fontWeight: FontWeight.bold);
  static const textW700Bodytext = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.bodyText,
      fontWeight: FontWeight.w700);
  static const textW600Drawingink = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.drawingInk,
      fontWeight: FontWeight.w600);
  static const text16BoldMainrunner = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.mainRunner,
      fontSize: 16,
      fontWeight: FontWeight.bold);
  static const textBoldMainrunner = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.mainRunner,
      fontWeight: FontWeight.bold);
  static const textBoldCrossrunner = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.crossRunner,
      fontWeight: FontWeight.bold);
  static const textBold =
      TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold);
  static const textBoldShortrunner = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.shortRunner,
      fontWeight: FontWeight.bold);
  static const text15W700Drawingheader = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.drawingHeader,
      fontSize: 15,
      fontWeight: FontWeight.w700);
  static const text12W600Drawingink = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.drawingInk,
      fontSize: 12,
      fontWeight: FontWeight.w600);
  static const text17BoldDrawingink = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.drawingInk,
      fontSize: 17,
      fontWeight: FontWeight.bold);
  static const text14BoldWhite = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.white,
      fontSize: 14,
      fontWeight: FontWeight.bold);
  static const text13W500 = TextStyle(
      fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w500);
  static const textW500 =
      TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w500);
  static const textW500Drawingtext = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.drawingText,
      fontWeight: FontWeight.w500);
  static const text15BoldDrawingink = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.drawingInk,
      fontSize: 15,
      fontWeight: FontWeight.bold);
  static const textBoldBrown = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.brown,
      fontWeight: FontWeight.bold);
  static const text13Drawingtext = TextStyle(
      fontFamily: fontFamily, color: AppColors.drawingText, fontSize: 13);
  static const text10Bold = TextStyle(
      fontFamily: fontFamily, fontSize: 10, fontWeight: FontWeight.bold);
  static const textW500Text = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.text,
      fontWeight: FontWeight.w500,
      height: 1,
      letterSpacing: 0.2);
  static const text14W500Secondarymuted = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.secondaryMuted,
      fontSize: 14,
      fontWeight: FontWeight.w500);
  static const textW600 =
      TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600);
  static const text18W700Text = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.text,
      fontSize: 18,
      fontWeight: FontWeight.w700);
  static const text14Secondarymuted = TextStyle(
      fontFamily: fontFamily, color: AppColors.secondaryMuted, fontSize: 14);
  static const text18BoldLegacyblue = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.legacyBlue,
      fontSize: 18,
      fontWeight: FontWeight.bold);
  static const text20BoldSuccess = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.success,
      fontSize: 20,
      fontWeight: FontWeight.bold);
  static const text14Greymuted = TextStyle(
      fontFamily: fontFamily, color: AppColors.greyMuted, fontSize: 14);
  static const text13BoldDrawingink = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.drawingInk,
      fontSize: 13,
      fontWeight: FontWeight.bold);
  static const text13 = TextStyle(fontFamily: fontFamily, fontSize: 13);
  static const text13W700 = TextStyle(
      fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w700);
  static const text16W700 = TextStyle(
      fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w700);
  static const text12W700 = TextStyle(
      fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w700);
}
