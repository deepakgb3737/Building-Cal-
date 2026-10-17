import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/logic/pvc_ceiling_calculator.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_ceiling_painter.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_measurement_guide.dart';
import 'pvc_multi_layout_ui_test.dart' as board;

void main() {
  testWidgets('Guide stays in place during incomplete or invalid entry',
      (t) async {
    await board.open(t, const Size(320, 640));
    await board.choose(t, PvcShape.l);
    final guide = find.byType(PvcMeasurementGuide);
    final before = t.getSize(guide);
    final first = find.byType(TextFormField).first;
    for (final value in ['', '.', '1']) {
      await t.enterText(first, value);
      await t.pumpAndSettle();
      expect(guide, findsOneWidget);
      expect(t.getSize(guide), before);
      expect(find.text('Check sizes'), findsOneWidget);
      expect(find.byType(PvcShapePreview), findsNothing);
      await t.ensureVisible(guide);
      await t.tap(guide);
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    }
    await t.enterText(first, '20');
    await t.pumpAndSettle();
    expect(find.byType(PvcShapePreview), findsOneWidget);
    expect(find.text('View guide'), findsOneWidget);
    expect(t.getSize(guide), before);
    expect(t.takeException(), isNull);
  });
  for (final size in [const Size(280, 600), const Size(740, 360)]) {
    testWidgets(
        'Thumbnail opens a readable guide without losing inputs at $size',
        (t) async {
      await board.open(t, size);
      for (final shape in PvcShape.values) {
        await board.choose(t, shape);
        final fields = find.byType(TextFormField);
        final values = t
            .widgetList<TextFormField>(fields)
            .map((f) => f.controller!.text)
            .toList();
        final thumbnail = find.byType(PvcShapePreview);
        expect(t.widget<PvcShapePreview>(thumbnail).thumbnail, isTrue);
        expect(t.getSize(thumbnail), const Size(112, 88));
        final label = t.getRect(find.text('Room measurements'));
        expect(label.right, lessThanOrEqualTo(t.getRect(thumbnail).left));
        await t.ensureVisible(find.byType(PvcMeasurementGuide));
        await t.tap(find.byType(PvcMeasurementGuide));
        await t.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        expect(dialog, findsOneWidget);
        final painter = t
            .widgetList<CustomPaint>(
                find.descendant(of: dialog, matching: find.byType(CustomPaint)))
            .map((p) => p.painter)
            .whereType<PvcShapePreviewPainter>()
            .single;
        expect(painter.room.shape, shape);
        expect(painter.thumbnail, isFalse);
        final close = find.widgetWithText(TextButton, 'Close');
        expect(t.getRect(close).bottom, lessThanOrEqualTo(size.height));
        await t.tap(close);
        await t.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(
            t.widgetList<TextFormField>(fields).map((f) => f.controller!.text),
            values);
        expect(t.takeException(), isNull);
      }
    });
  }
  test('Thumbnail markers remain separated for every shape', () {
    for (final shape in PvcShape.values) {
      for (final scale in [1.0, 1.5]) {
        final painter = PvcShapePreviewPainter(
            buildPvcRoom(shape, pvcDefaults(shape)), null,
            thumbnail: true, textScale: scale);
        final rects = <Rect>[];
        for (final center in painter.labelCenters(const Size(112, 88)).values) {
          final rect = Rect.fromCircle(center: center, radius: painter.radius);
          expect(const Rect.fromLTWH(0, 0, 112, 88).contains(rect.topLeft),
              isTrue);
          expect(const Rect.fromLTWH(0, 0, 112, 88).contains(rect.bottomRight),
              isTrue);
          expect(rects.any((other) => other.overlaps(rect)), isFalse);
          rects.add(rect);
        }
      }
    }
  });
}
