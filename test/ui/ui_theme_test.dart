import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:grid_ceiling_calculator/ui/app_widgets.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';
import 'package:grid_ceiling_calculator/features/drawer/ui/drawer_calculator.dart';

void main() {
  testWidgets('Drawer screen renders calculated layout with the shared theme',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light, home: const DrawerCalculatorScreen()));
    final height = find.descendant(
        of: find.byType(AppNumberField).first,
        matching: find.byType(TextFormField));
    await tester.enterText(height, '762');
    await tester.ensureVisible(find.text('Calculate'));
    await tester.tap(find.text('Calculate'));
    await tester.pumpAndSettle();
    expect(find.text('2D Drawer Layout'), findsOneWidget);
    expect(find.text('Gap Space ((N-1)×G)'), findsOneWidget);
    expect(find.text('Drawer 1  370.50 mm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('Theme and drawing typography share the same font', () {
    expect(AppTheme.light.textTheme.bodyMedium!.fontFamily,
        AppTypography.fontFamily);
    expect(AppTypography.input.fontFamily, AppTypography.fontFamily);
    expect(AppTheme.light.scaffoldBackgroundColor, AppColors.background);
    expect(AppTheme.light.colorScheme.primary, AppColors.primary);
    expect(
        AppTheme.light.elevatedButtonTheme.style!.backgroundColor!.resolve({}),
        AppColors.primary);
  });

  testWidgets('Shared numeric fields retain list input and validation',
      (tester) async {
    final controller = TextEditingController();
    final key = GlobalKey<FormState>();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: Form(
                key: key,
                child: AppNumberField(
                    label: 'Custom drawers',
                    controller: controller,
                    allowCommaSeparated: true,
                    validator: (value) =>
                        value!.isEmpty ? 'Required' : null)))));
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '200,150');
    expect(controller.text, '200,150');
    expect(key.currentState!.validate(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shared converter field fits narrow screens and scales text',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
          body: Center(
              child: SizedBox(
        width: 240,
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: AppConversionField(
              label: 'Square Millimetre (mm²)',
              controller: controller,
              labelWidth: 150,
              maxLines: 2),
        ),
      ))),
    ));
    await tester.enterText(find.byType(TextField), '12.5');
    expect(controller.text, '12.5');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Length field preserves signed decimal input', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: AppConversionField(
                label: 'Metre (m)',
                controller: controller,
                allowNegative: true))));
    await tester.enterText(find.byType(TextField), '-2.5');
    expect(controller.text, '-2.5');
  });
}
