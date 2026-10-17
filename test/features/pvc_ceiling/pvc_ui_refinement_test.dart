import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/logic/pvc_ceiling_calculator.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_diagram_view.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_ceiling_painter.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_ceiling_results.dart';
import 'pvc_multi_layout_ui_test.dart' as board;

class _BlankPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(covariant _BlankPainter old) => false;
}

void main() {
  for (final shape in PvcShape.values) {
    testWidgets('${shape.label}: input diagram stays compact', (t) async {
      for (final size in [const Size(320, 700), const Size(740, 360)]) {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
                body: PvcShapePreview(
                    room: buildPvcRoom(shape, pvcDefaults(shape))))));
        final preview = find.byType(CustomPaint).last;
        expect(t.getSize(preview).height, inInclusiveRange(110, 160));
        expect(t.takeException(), isNull);
      }
    });
    test('${shape.label}: preview letters stay visible and separate', () {
      for (final values in [
        pvcDefaults(shape),
        {...pvcDefaults(shape), 'A': '100'}
      ]) {
        final room = buildPvcRoom(shape, values);
        for (final size in [
          const Size(248, 110),
          const Size(248, 125),
          const Size(288, 172),
          const Size(708, 125)
        ]) {
          for (final scale in [1.0, 1.5]) {
            final painter =
                PvcShapePreviewPainter(room, null, textScale: scale);
            final centers = painter.labelCenters(size);
            expect(centers.keys, room.edges.keys);
            final rects = <Rect>[];
            for (final center in centers.values) {
              final rect =
                  Rect.fromCircle(center: center, radius: painter.radius);
              expect((Offset.zero & size).contains(rect.topLeft), isTrue);
              expect((Offset.zero & size).contains(rect.bottomRight), isTrue);
              expect(rects.any((r) => r.overlaps(rect)), isFalse);
              rects.add(rect);
            }
            expect(
                PvcShapePreviewPainter(room, 'C', textScale: scale)
                    .labelCenters(size),
                centers);
          }
        }
      }
    });
  }
  for (final shape in [
    const Size(1000, 900),
    const Size(300, 3000),
    const Size(1000, 172)
  ]) {
    testWidgets('Diagram $shape fits, zooms and survives rotation', (t) async {
      t.view.physicalSize = const Size(280, 600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
              body: SingleChildScrollView(
                  child: PvcDiagramView(
                      size: shape,
                      painter: _BlankPainter(),
                      label: 'Test diagram')))));
      await t.pumpAndSettle();
      final finder = find.byType(InteractiveViewer);
      var view = t.widget<InteractiveViewer>(finder), size = t.getSize(finder);
      final before = view.transformationController!.value.getMaxScaleOnAxis();
      expect(shape.width * before, lessThanOrEqualTo(size.width + .001));
      expect(shape.height * before, lessThanOrEqualTo(size.height + .001));
      expect(size.height, lessThanOrEqualTo(330));
      await t.tap(find.byTooltip('Zoom in'));
      await t.pumpAndSettle();
      expect(view.transformationController!.value.getMaxScaleOnAxis(),
          greaterThan(before));
      await t.tap(find.byTooltip('Zoom out'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Fit diagram'));
      await t.pumpAndSettle();
      expect(view.transformationController!.value.getMaxScaleOnAxis(),
          closeTo(before, 1e-8));
      final center = t.getCenter(finder);
      final first =
          await t.startGesture(center - const Offset(20, 0), pointer: 1);
      final second =
          await t.startGesture(center + const Offset(20, 0), pointer: 2);
      await first.moveBy(const Offset(-20, 0));
      await second.moveBy(const Offset(20, 0));
      await t.pump();
      await second.up();
      await first.up();
      await t.pumpAndSettle();
      expect(view.transformationController!.value.getMaxScaleOnAxis(),
          greaterThan(before));
      t.view.physicalSize = const Size(600, 280);
      await t.pumpAndSettle();
      view = t.widget<InteractiveViewer>(finder);
      size = t.getSize(finder);
      final rotated = view.transformationController!.value.getMaxScaleOnAxis();
      expect(shape.height * rotated, lessThanOrEqualTo(size.height + .001));
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('One-finger page scroll remains available over a fitted diagram',
      (t) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: SingleChildScrollView(
                controller: scroll,
                child: Column(children: [
                  PvcDiagramView(
                      size: const Size(1000, 900),
                      painter: _BlankPainter(),
                      label: 'Plan'),
                  const SizedBox(height: 1800)
                ])))));
    await t.pumpAndSettle();
    await t.drag(find.byType(InteractiveViewer), const Offset(0, -100));
    await t.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
  });
  testWidgets(
      'Calculate reveals summary and invalid dimensions focus their field',
      (t) async {
    await board.open(t, const Size(280, 600));
    await board.choose(t, PvcShape.u);
    await board.calculate(t);
    expect(t.getRect(find.text('What to buy')).top, inInclusiveRange(50, 250));
    final result = t.widget<PvcCeilingResults>(find.byType(PvcCeilingResults));
    expect(result.layout!.total, 168);
    final field = find.byType(TextFormField).at(3);
    await t.ensureVisible(field);
    await t.enterText(field, '99');
    await t.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Calculate');
    await t.ensureVisible(button);
    await t.tap(button);
    await t.pumpAndSettle();
    final input = t.widget<TextField>(
        find.descendant(of: field, matching: find.byType(TextField)));
    expect(input.focusNode!.hasFocus, isTrue);
    expect(find.text('Wall D must be shorter than wall B.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
