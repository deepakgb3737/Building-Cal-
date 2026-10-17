import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/home/ui/home_screen.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:grid_ceiling_calculator/features/unit_converter/ui/unit_converter.dart';

void main() {
  testWidgets('Home icons load and buttons fit a narrow scaled screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.5)),
        child: child!,
      ),
      home: const HomeScreen(),
    ));
    await tester.pumpAndSettle();
    for (final image in tester.widgetList<Image>(find.byType(Image))) {
      expect(
          ((image.image as ResizeImage).imageProvider as AssetImage).assetName,
          startsWith('assets/icons/inside /'));
      expect(image.width, 56);
    }
    expect(find.byType(Image), findsAtLeastNWidgets(6));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Unit Converter'));
    await tester.pumpAndSettle();
    expect(find.byType(UnitConverterScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
