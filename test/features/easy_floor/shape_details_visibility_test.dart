import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_shapes.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/shape_diagram.dart';
import 'preset_dialog_test.dart' show input, edit, diagram;
import 'preset_keyboard_test.dart' as keyboard;

void main() {
  for (final kind
      in ShapePreset.values.where((k) => k != ShapePreset.polygon)) {
    for (final unit in [DrawingUnit.mm, DrawingUnit.feetInches]) {
      testWidgets(
          '${kind.label} details remain accessible in ${unit.symbol} across viewport changes',
          (t) async {
        t.view.physicalSize = const Size(320, 568);
        await keyboard.open(t, kind, unit: unit, textScale: 1.6);
        final spec = ShapeSpec(kind, 5000, 4000, 0);
        final expected = <ShapeDimension, String>{};
        for (final m in spec.measurements) {
          expected[m.id] = unit.input(m.value);
        }
        for (final scenario in [
          (const Size(240, 420), 0.0),
          (const Size(320, 568), 240.0),
          (const Size(740, 360), 140.0),
          (const Size(430, 900), 300.0),
          (const Size(1024, 768), 0.0),
        ]) {
          t.view.physicalSize = scenario.$1;
          t.view.viewInsets = FakeViewPadding(bottom: scenario.$2);
          await t.pumpAndSettle();
          for (final m in spec.measurements) {
            if (keyboard.editable(t, input(m.id)).focusNode!.hasFocus) {
              await t.enterText(input(m.id), expected[m.id]!);
            } else {
              await edit(t, m.id, expected[m.id]!);
            }
            await t.pumpAndSettle();
            keyboard.visibleField(t, m.id);
            expect(t.widget<TextFormField>(input(m.id)).controller!.text,
                expected[m.id]);
            expect(diagram(t).active, m.id);
            final label = find.text(
                '${String.fromCharCode(65 + spec.measurements.indexWhere((entry) => entry.id == m.id))} · ${m.name} (${unit == DrawingUnit.feetInches ? 'feet inches' : unit.symbol})');
            expect(t.renderObject<RenderParagraph>(label).didExceedMaxLines,
                isFalse);
          }
          for (final button in [
            find.byTooltip('Cancel').evaluate().isNotEmpty
                ? find.byTooltip('Cancel')
                : find.widgetWithText(TextButton, 'Cancel'),
            find.widgetWithText(FilledButton, 'Preview')
          ]) {
            expect(button.hitTestable(), findsOneWidget);
            final rect = t.getRect(button);
            expect(rect.bottom,
                lessThanOrEqualTo(scenario.$1.height - scenario.$2));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(scenario.$1.width));
          }
          // In compact layouts the diagram remains part of the scrollable form.
          await t.ensureVisible(
              find.byKey(const ValueKey('shapeDimensionDiagram')));
          await t.pumpAndSettle();
          expect(
              find.byKey(const ValueKey('shapeDimensionDiagram')).hitTestable(),
              findsOneWidget);
          expect(diagram(t).unit, unit);
          expect(t.takeException(), isNull);
        }
      });
    }

    for (final size in [
      const Size(192, 180),
      const Size(220, 180),
      const Size(400, 200)
    ]) {
      test('${kind.label} diagram labels fit and remain separate in $size', () {
        for (final textScale in [1.0, 1.6, 2.0]) {
          final spec = ShapeSpec(kind, 5000, 4000, 0),
              labels = <ShapeDimension, Rect>{};
          final recorder = ui.PictureRecorder();
          ShapeDiagram(spec, DrawingUnit.feetInches, ShapeDimension.width,
                  textScaler: TextScaler.linear(textScale), labelBounds: labels)
              .paint(Canvas(recorder), size);
          recorder.endRecording().dispose();
          expect(
              labels.keys.toSet(), spec.measurements.map((m) => m.id).toSet());
          for (final label in labels.values) {
            expect(label.left, greaterThanOrEqualTo(0));
            expect(label.top, greaterThanOrEqualTo(0));
            expect(label.right, lessThanOrEqualTo(size.width));
            expect(label.bottom, lessThanOrEqualTo(size.height));
            for (final other in labels.values.where((r) => r != label)) {
              expect(label.overlaps(other), isFalse);
            }
          }
        }
      });
    }
  }
}
