import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/main.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_ceiling_screen.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_ceiling_results.dart';

void main() {
  testWidgets('Home opens PVC inside existing app theme', (t) async {
    await t.pumpWidget(const GridCeilingCalculatorApp());
    await t.tap(find.text('PVC Ceiling'));
    await t.pumpAndSettle();
    expect(find.byType(PvcCeilingScreen), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Room length'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('BuildCalc'), findsOneWidget);
  });
  for (final size in [
    const Size(280, 600),
    const Size(360, 740),
    const Size(740, 360),
    const Size(1024, 768)
  ]) {
    testWidgets('Inputs, results, keyboard and rotation at $size', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.4)),
              child: child!),
          home: const PvcCeilingScreen()));
      await t.enterText(find.byType(TextFormField).at(0), '10');
      await t.enterText(find.byType(TextFormField).at(1), '10');
      final button = find.widgetWithText(FilledButton, 'Calculate');
      await t.ensureVisible(button);
      await t.tap(button);
      for (var i = 0;
          i < 100 && find.byType(PvcCeilingResults).evaluate().isEmpty;
          i++) {
        await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await t.pump();
      }
      await t.pumpAndSettle();
      final result =
          t.widget<PvcCeilingResults>(find.byType(PvcCeilingResults));
      expect(result.layout!.run, 10);
      expect(result.layout!.total, 110);
      await t.ensureVisible(find.text('Ceiling layout'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      t.view.physicalSize = Size(size.height, size.width);
      t.view.viewInsets = const FakeViewPadding(bottom: 180);
      addTearDown(t.view.resetViewInsets);
      await t.pumpAndSettle();
      await t.ensureVisible(find.byType(TextFormField).at(0));
      await t.enterText(find.byType(TextFormField).at(0), '0');
      await t.pumpAndSettle();
      expect(find.byType(PvcCeilingResults), findsNothing);
      await t.ensureVisible(button);
      await t.tap(button);
      await t.pumpAndSettle();
      expect(find.text('Wall A: enter 0.5 to 100 ft.'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
