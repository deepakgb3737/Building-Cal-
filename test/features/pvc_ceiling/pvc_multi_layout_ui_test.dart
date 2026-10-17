import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/logic/pvc_ceiling_calculator.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_ceiling_screen.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_ceiling_results.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_ceiling_painter.dart';

Future<void> choose(WidgetTester t, PvcShape shape) async {
  final dropdown = find.byKey(const ValueKey('pvcShape'));
  await t.ensureVisible(dropdown);
  await t.tap(dropdown);
  await t.pumpAndSettle();
  await t.ensureVisible(find.text(shape.label).last);
  await t.pumpAndSettle();
  await t.tap(find.text(shape.label).last);
  await t.pumpAndSettle();
}

Future<void> calculate(WidgetTester t) async {
  final button = find.widgetWithText(FilledButton, 'Calculate');
  await t.ensureVisible(button);
  await t.tap(button);
  for (var i = 0;
      i < 200 && find.byType(PvcCeilingResults).evaluate().isEmpty;
      i++) {
    await t
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump();
  }
  await t.pumpAndSettle();
  expect(find.byType(PvcCeilingResults), findsOneWidget);
}

Future<void> open(WidgetTester t, Size size) async {
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
  await t.pumpAndSettle();
}

void main() {
  for (final size in [const Size(280, 600), const Size(740, 360)]) {
    for (final shape in PvcShape.values) {
      testWidgets('${shape.label} preview, fields and calculated plan at $size',
          (t) async {
        await open(t, size);
        if (shape != PvcShape.rectangle) await choose(t, shape);
        final preview = t.widget<PvcShapePreview>(find.byType(PvcShapePreview));
        expect(preview.room.shape, shape);
        expect(preview.room.area, buildPvcRoom(shape, pvcDefaults(shape)).area);
        final fields =
            t.widgetList<TextFormField>(find.byType(TextFormField)).toList();
        expect(fields.length, pvcDimensions(shape).length);
        for (var i = 0; i < fields.length; i++) {
          expect(fields[i].controller!.text,
              pvcDefaults(shape)[pvcDimensions(shape)[i].key]);
        }
        await calculate(t);
        final result =
            t.widget<PvcCeilingResults>(find.byType(PvcCeilingResults));
        final canvas = t
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<CeilingPainter>()
            .single;
        expect(identical(canvas.c, result.layout), isTrue);
        expect(t.takeException(), isNull);
      });
    }
  }
  testWidgets(
      'Invalid preview never falls back; shape values and focus survive keyboard changes',
      (t) async {
    await open(t, const Size(320, 640));
    await choose(t, PvcShape.l);
    await t.enterText(find.byType(TextFormField).at(0), '20');
    await t.enterText(find.byType(TextFormField).at(2), '21');
    await t.pumpAndSettle();
    expect(find.byType(PvcShapePreview), findsNothing);
    final button = find.widgetWithText(FilledButton, 'Calculate');
    await t.ensureVisible(button);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(find.text('Wall C must be shorter than wall A.'), findsOneWidget);
    expect(find.byType(PvcCeilingResults), findsNothing);
    await choose(t, PvcShape.u);
    final last = find.byType(TextFormField).last;
    t
        .widget<TextField>(
            find.descendant(of: last, matching: find.byType(TextField)))
        .focusNode!
        .requestFocus();
    await t.pumpAndSettle();
    t.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(t.view.resetViewInsets);
    await t.pumpAndSettle();
    expect(t.getRect(last).bottom, lessThanOrEqualTo(640 - 260 + 1));
    await t.enterText(last, '2');
    await t.pumpAndSettle();
    expect(t.widget<PvcShapePreview>(find.byType(PvcShapePreview)).active, 'E');
    t.view.viewInsets = const FakeViewPadding();
    await t.pumpAndSettle();
    await choose(t, PvcShape.l);
    expect(
        t
            .widget<TextFormField>(find.byType(TextFormField).at(0))
            .controller!
            .text,
        '20');
    expect(
        t
            .widget<TextFormField>(find.byType(TextFormField).at(2))
            .controller!
            .text,
        '21');
    expect(find.byType(PvcShapePreview), findsNothing);
    expect(t.takeException(), isNull);
  });
  test('U-shaped plan clips material out of the opening', () async {
    final room = buildPvcRoom(PvcShape.u, pvcDefaults(PvcShape.u));
    final layout = runPvcCalculation(PvcCalculation(room, 'mix'))!;
    expect(layout.turned, isFalse);
    final geometry = LayoutGeometry.of(layout), recorder = ui.PictureRecorder();
    CeilingPainter(layout, 1)
        .paint(Canvas(recorder), Size(geometry.vw, geometry.vh));
    final picture = recorder.endRecording();
    final image = await picture.toImage(geometry.vw.ceil(), geometry.vh.ceil());
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    int alpha(double x, double y) {
      final px = (LayoutGeometry.padL + x * geometry.sc).round();
      final py = (LayoutGeometry.padT + y * geometry.sc).round();
      return bytes.getUint8((py * image.width + px) * 4 + 3);
    }

    expect(alpha(8, 3), 0);
    expect(alpha(2.5, 3), greaterThan(0));
    image.dispose();
    picture.dispose();
  });
}
