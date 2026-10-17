import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_shapes.dart';
import 'preset_dialog_test.dart' show input;
import 'preset_keyboard_test.dart' as keyboard;

void main() {
  testWidgets('Rapid focus changes reveal the latest field, not a stale target',
      (t) async {
    t.view.physicalSize = const Size(320, 568);
    await keyboard.open(t, ShapePreset.uShape);
    t.view.viewInsets = const FakeViewPadding(bottom: 240);
    await t.pumpAndSettle();
    keyboard.editable(t, input(ShapeDimension.width)).focusNode!.requestFocus();
    await t.pump();
    keyboard.editable(t, input(ShapeDimension.base)).focusNode!.requestFocus();
    await t.pumpAndSettle();
    keyboard.visibleField(t, ShapeDimension.base);
  });

  for (final kind
      in ShapePreset.values.where((k) => k != ShapePreset.polygon)) {
    testWidgets(
        '${kind.label}: limited-height keyboard keeps form and actions reachable',
        (t) async {
      t.view.physicalSize = const Size(740, 360);
      await keyboard.open(t, kind);
      t.view.viewInsets = const FakeViewPadding(bottom: 230);
      await t.pumpAndSettle();
      final last = ShapeSpec(kind, 5000, 4000, 0).measurements.last.id;
      keyboard.editable(t, input(last)).focusNode!.requestFocus();
      await t.pumpAndSettle();
      final field = t.getRect(input(last));
      final label = t.getRect(find
          .descendant(
              of: find.byKey(ValueKey(last)), matching: find.byType(Text))
          .first);
      expect(label.top, greaterThanOrEqualTo(12));
      expect(field.top, greaterThanOrEqualTo(12));
      expect(field.bottom, lessThanOrEqualTo(130));
      await t.ensureVisible(find.text('Preview'));
      await t.pumpAndSettle();
      expect(find.text('Preview').hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
