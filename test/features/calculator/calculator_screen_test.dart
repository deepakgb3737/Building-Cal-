import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/calculator/ui/basic_calculator.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';

void main() {
  testWidgets('Physical keyboard calculates, continues and clears',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const CalculatorScreen()));
    await tester.pumpAndSettle();
    for (final entry in [
      (LogicalKeyboardKey.digit2, '2'),
      (LogicalKeyboardKey.numpadMultiply, '*'),
      (LogicalKeyboardKey.digit3, '3'),
    ]) {
      await tester.sendKeyEvent(entry.$1, character: entry.$2);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('6'), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '/');
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2, character: '2');
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await tester.pump();
    expect(find.text('3'), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit9, character: '9');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(find.text('0'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Short landscape layout scrolls without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(568, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!),
        home: const CalculatorScreen()));
    expect(find.text('Copy'), findsNothing);
    await tester.ensureVisible(find.text('='));
    await tester.tap(find.text('='));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Copy, history and new calculations work on a small screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? clipboard;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = call.arguments['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const CalculatorScreen()));
    for (final key in ['2', '+', '3', '=']) {
      await tester.tap(find.text(key));
      await tester.pump();
    }
    expect(tester.takeException(), isNull, reason: 'Keypad and result layout');
    expect(find.text('Copy'), findsNothing);
    await tester.longPress(find.byType(SelectableText));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(clipboard, '5');
    expect(tester.takeException(), isNull, reason: 'Copy result layout');
    await tester.tap(find.text('7'));
    await tester.pump();
    expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data, '7');
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'History layout');
    await tester.tap(find.byTooltip('Copy history result'));
    await tester.pump();
    expect(clipboard, '5');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Advanced square root and invalid calculation states',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const CalculatorScreen()));
    await tester.tap(find.text('9'));
    await tester.pump();
    await tester.tap(find.byTooltip('More operations'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Square root √x'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data, '3');
    for (final key in ['AC', '1', '÷', '0', '=']) {
      await tester.tap(find.text(key));
      await tester.pump();
    }
    expect(tester.widget<SelectableText>(find.byType(SelectableText)).data,
        'Error');
    await tester.longPress(find.byType(SelectableText));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsNothing);
  });
}
