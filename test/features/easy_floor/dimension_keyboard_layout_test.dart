import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/dimension_dialog.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';

void main() {
  for (final rectangle in [false, true]) {
    for (final unit in [DrawingUnit.mm, DrawingUnit.feetInches]) {
      testWidgets(
          'Exact ${rectangle ? 'room' : 'wall'} entry survives keyboard and rotation in ${unit.symbol}',
          (t) async {
        t.view.physicalSize = const Size(320, 740);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetViewInsets);
        t.platformDispatcher.textScaleFactorTestValue = 1.4;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        (double, double?, bool)? result;
        await t.pumpWidget(MaterialApp(
            theme: AppTheme.light,
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () async {
                          result = await showDialog<(double, double?, bool)>(
                              context: context,
                              builder: (_) => DimensionDialog(
                                  valueMm: 2000,
                                  secondMm: rectangle ? 3000 : null,
                                  unit: unit,
                                  showLock: false));
                        },
                        child: const Text('Edit'))))));
        await t.tap(find.text('Edit'));
        await t.pumpAndSettle();
        final first = find.byType(TextFormField).first;
        final entered = unit.input(3352.8);
        await t.enterText(first, entered);
        for (final size in [const Size(320, 740), const Size(740, 360)]) {
          t.view.physicalSize = size;
          t.view.viewInsets = const FakeViewPadding(bottom: 180);
          await t.pumpAndSettle();
          expect(t.widget<TextFormField>(first).controller!.text, entered);
          expect(first.hitTestable(), findsOneWidget);
          final apply = find.widgetWithText(FilledButton, 'Apply');
          expect(apply.hitTestable(), findsOneWidget);
          expect(t.getRect(apply).bottom, lessThanOrEqualTo(size.height - 180));
          expect(t.takeException(), isNull);
        }
        if (rectangle) {
          final second = find.byType(TextFormField).last;
          await t.enterText(second, unit.input(3657.6));
          await t.pumpAndSettle();
          t.view.physicalSize = const Size(320, 740);
          await t.pumpAndSettle();
          t.view.physicalSize = const Size(740, 360);
          await t.pumpAndSettle();
          expect(second.hitTestable(), findsOneWidget);
          expect(t.widget<TextFormField>(first).controller!.text, entered);
        }
        t.view.viewInsets = FakeViewPadding.zero;
        t.view.physicalSize = const Size(320, 740);
        await t.pumpAndSettle();
        expect(t.widget<TextFormField>(first).controller!.text, entered);
        await t.tap(find.text('Apply'));
        await t.pumpAndSettle();
        expect(result!.$1, closeTo(3352.8, .000001));
        expect(result!.$2, rectangle ? closeTo(3657.6, .000001) : isNull);
        expect(t.takeException(), isNull);
      });
    }
  }
}
