import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/paint/ui/paint_screen.dart';
import 'package:grid_ceiling_calculator/features/flooring_tiles/ui/flooring_tile_screen.dart';
import 'package:grid_ceiling_calculator/features/concrete/ui/concrete_screen.dart';
import 'package:grid_ceiling_calculator/features/plaster/ui/plaster_screen.dart';
import 'package:grid_ceiling_calculator/features/home/ui/home_screen.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:grid_ceiling_calculator/ui/material_estimate_screen.dart';

void main() {
  final cases = [
    (
      screen: const PaintScreen(),
      fields: {
        'length': '10',
        'height': '3',
        'openings': '5',
        'coverage': '10'
      },
      expected: '5.50 L'
    ),
    (
      screen: const FlooringTileScreen(),
      fields: {'length': '5', 'width': '4', 'excluded': '2'},
      expected: '55 pcs'
    ),
    (
      screen: const ConcreteScreen(),
      fields: {'length': '5', 'width': '4', 'depth': '100'},
      expected: '2.100 m³'
    ),
    (
      screen: const PlasterScreen(),
      fields: {
        'length': '10',
        'height': '3',
        'openings': '5',
        'thickness': '20',
        'rate': '8'
      },
      expected: '440.00 kg'
    ),
  ];
  for (final example in cases) {
    testWidgets(
        '${example.screen.runtimeType} calculates, copies and clears stale results on mobile',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? clipboard;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!),
          home: example.screen));
      for (final entry in example.fields.entries) {
        final field = find.descendant(
            of: find.byKey(ValueKey(entry.key)),
            matching: find.byType(TextFormField));
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      await tester.ensureVisible(find.text('Calculate'));
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();
      expect(find.text(example.expected), findsOneWidget);
      await tester.ensureVisible(find.text('Copy estimate'));
      await tester.tap(find.text('Copy estimate'));
      await tester.pumpAndSettle();
      expect(clipboard, contains(example.expected));
      expect(tester.takeException(), isNull);
      final lengthField = find.descendant(
          of: find.byKey(const ValueKey('length')),
          matching: find.byType(TextFormField));
      await tester.ensureVisible(lengthField);
      await tester.enterText(lengthField, '');
      await tester.pumpAndSettle();
      expect(find.text('Your estimate'), findsNothing);
      await tester.ensureVisible(find.text('Calculate'));
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Excluded area error is shown without leaving a result',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const PaintScreen()));
    for (final entry in {
      'length': '1',
      'height': '1',
      'openings': '2',
      'coverage': '10'
    }.entries) {
      await tester.enterText(
          find.descendant(
              of: find.byKey(ValueKey(entry.key)),
              matching: find.byType(TextFormField)),
          entry.value);
    }
    await tester.ensureVisible(find.text('Calculate'));
    await tester.tap(find.text('Calculate'));
    await tester.pumpAndSettle();
    expect(find.text('Excluded area must be smaller than the total area.'),
        findsOneWidget);
    expect(find.text('Your estimate'), findsNothing);
  });

  for (final title in [
    'Paint',
    'Flooring Tiles',
    'Concrete Volume',
    'Plaster'
  ]) {
    testWidgets('Home opens $title', (tester) async {
      await tester.pumpWidget(
          MaterialApp(theme: AppTheme.light, home: const HomeScreen()));
      await tester.scrollUntilVisible(find.text(title), 250);
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.byType(MaterialEstimateScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
