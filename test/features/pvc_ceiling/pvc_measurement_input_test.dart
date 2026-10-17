import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:grid_ceiling_calculator/ui/app_widgets.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_ceiling_screen.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/logic/pvc_ceiling_calculator.dart';
import 'pvc_multi_layout_ui_test.dart' as board;

void main() {
  for (final width in [320.0, 360.0, 740.0]) {
    testWidgets('Compact PVC inputs share a row at width $width', (t) async {
      t.view.physicalSize = Size(width, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
          MaterialApp(theme: AppTheme.light, home: const PvcCeilingScreen()));
      await t.pumpAndSettle();
      await board.choose(t, PvcShape.t);
      final fields = find.byType(AppNumberField);
      final first = t.getRect(fields.at(0));
      final second = t.getRect(fields.at(1));
      expect(first.top, second.top);
      expect(second.left - first.right, closeTo(12, .1));
      for (var i = 0; i < 5; i++) {
        await t.ensureVisible(fields.at(i));
        await t.pumpAndSettle();
        final input = find.descendant(
            of: fields.at(i), matching: find.byType(TextFormField));
        expect(t.getSize(input).height, inInclusiveRange(48, 52));
        await t.enterText(input, '100.00');
        await t.pumpAndSettle();
        expect(t.widget<TextFormField>(input).controller!.text, '100.00');
      }
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Landscape keyboard keeps the editable value above its inset',
      (t) async {
    await board.open(t, const Size(740, 360));
    final field = find.byType(TextFormField).last;
    final input = find.descendant(of: field, matching: find.byType(TextField));
    t.widget<TextField>(input).focusNode!.requestFocus();
    await t.pumpAndSettle();
    t.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(t.view.resetViewInsets);
    await t.pumpAndSettle();
    final editable =
        find.descendant(of: field, matching: find.byType(EditableText));
    expect(t.getRect(editable).bottom, lessThanOrEqualTo(121));
    expect(t.takeException(), isNull);
  });
  for (final size in [const Size(280, 600), const Size(740, 360)]) {
    testWidgets(
        'PVC fields at $size keep full labels, markers, units and values',
        (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: const PvcCeilingScreen()));
      await t.pumpAndSettle();
      await board.choose(t, PvcShape.t);
      final fields = find.byType(AppNumberField);
      expect(fields, findsNWidgets(5));
      for (var i = 0; i < 5; i++) {
        final widget = t.widget<AppNumberField>(fields.at(i));
        expect(widget.label, pvcDimensions(PvcShape.t)[i].label);
        expect(widget.leadingLabel, pvcDimensions(PvcShape.t)[i].key);
        expect(widget.unit, 'ft');
        await t.ensureVisible(fields.at(i));
        await t.pumpAndSettle();
        final unit =
            find.descendant(of: fields.at(i), matching: find.text('ft'));
        final box = t.getRect(fields.at(i)), unitBox = t.getRect(unit);
        expect(box.contains(unitBox.topLeft), isTrue);
        expect(box.contains(unitBox.bottomRight), isTrue);
      }
      final first = find.byType(TextFormField).first;
      await t.ensureVisible(first);
      await t.enterText(first, '100.00');
      await t.pumpAndSettle();
      expect(t.widget<TextFormField>(first).controller!.text, '100.00');
      await t.testTextInput.receiveAction(TextInputAction.next);
      await t.pumpAndSettle();
      final next = t.widget<TextField>(find.descendant(
          of: find.byType(TextFormField).at(1),
          matching: find.byType(TextField)));
      expect(next.focusNode!.hasFocus, isTrue);
      expect(t.takeException(), isNull);
    });
  }
}
