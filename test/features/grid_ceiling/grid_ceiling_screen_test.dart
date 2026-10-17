import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/ceiling_material_service.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/grid_ceiling_screen.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/enhanced_room_layout.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:grid_ceiling_calculator/ui/app_widgets.dart';

void main() {
  testWidgets('Mobile form, drawing views and editing stay consistent',
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
            child: child!),
        home: const GridCeilingCalculatorScreen()));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '2438');
    await tester.enterText(fields.at(1), '3200');
    await tester.ensureVisible(find.text('Calculate layout'));
    await tester.tap(find.text('Calculate layout'));
    await tester.pumpAndSettle();
    final result = tester.widget<EnhancedRoomLayoutScreen>(
        find.byType(EnhancedRoomLayoutScreen));
    expect(result.width, 2438);
    expect(result.length, 3200);
    expect(find.text('4ft cross Ts required'), findsOneWidget);
    expect(find.text('2ft cross Ts required'), findsOneWidget);
    expect(find.text('10ft wall angles'), findsOneWidget);
    expect(
      find.text(
        '${CeilingMaterialService.wallAnglePieces(result.width, result.length)} pcs',
      ),
      findsWidgets,
    );
    expect(find.text('${result.result.optimizedFourFootT} pcs'), findsWidgets);
    expect(
        find.text('${result.result.optimizedTwoFootCrossT} pcs'), findsWidgets);
    expect(find.text('Material requirements'), findsOneWidget);
    expect(find.text('Placement measurements'), findsOneWidget);
    await tester.ensureVisible(find.text('Measurements'));
    await tester.tap(find.text('Measurements'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Placement measurements')).dy,
        inInclusiveRange(0, 640));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('2D plan'));
    await tester.tap(find.text('2D plan'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(tester.getSize(find.byType(InteractiveViewer)).width,
        lessThanOrEqualTo(320));
    await tester.ensureVisible(find.byType(InteractiveViewer));
    await tester.drag(find.byType(InteractiveViewer), const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byType(AppNumberField).first);
    await tester.enterText(fields.at(0), '');
    await tester.pumpAndSettle();
    expect(find.byType(EnhancedRoomLayoutScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Wide layout keeps both inputs and validation', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light, home: const GridCeilingCalculatorScreen()));
    await tester.tap(find.text('Calculate layout'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter room width in mm'), findsOneWidget);
    expect(find.text('Please enter room length in mm'), findsOneWidget);
    expect(find.byType(EnhancedRoomLayoutScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
