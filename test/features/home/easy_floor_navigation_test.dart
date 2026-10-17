import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/home/ui/home_screen.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/easy_floor_screen.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';

void main() {
  testWidgets('Home opens EasyFloor and returns on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const HomeScreen()));
    expect(find.text('EasyFloor').hitTestable(), findsOneWidget);
    await tester.tap(find.text('EasyFloor'));
    await tester.pumpAndSettle();
    expect(find.byType(EasyFloorScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('drawingCanvas')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
