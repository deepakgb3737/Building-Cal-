import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_shapes.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/shape_dialog.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'preset_dialog_test.dart' show input, edit;

Future<void> open(WidgetTester t, ShapePreset kind,
    {DrawingUnit unit = DrawingUnit.mm,
    double textScale = 1,
    void Function(ShapeSpec?)? result}) async {
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetViewInsets);
  await t.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!),
      home: Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () async {
                    final spec = await showDialog<ShapeSpec>(
                        context: context,
                        builder: (_) => ShapeDialog(
                            spec: ShapeSpec(kind, 5000, 4000, 0), unit: unit));
                    result?.call(spec);
                  },
                  child: const Text('Open'))))));
  await t.tap(find.text('Open'));
  await t.pumpAndSettle();
}

TextField editable(WidgetTester t, Finder finder) => t.widget<TextField>(
    find.descendant(of: finder, matching: find.byType(TextField)));

void visibleField(WidgetTester t, ShapeDimension id) {
  final field = input(id);
  final rect = t.getRect(field);
  final labelRect = t.getRect(find
      .descendant(of: find.byKey(ValueKey(id)), matching: find.byType(Text))
      .first);
  final keyboardTop = t.view.physicalSize.height - t.view.viewInsets.bottom;
  final viewport = t.getRect(find
      .ancestor(of: field, matching: find.byType(SingleChildScrollView))
      .first);
  expect(rect.bottom, lessThanOrEqualTo(keyboardTop));
  expect(labelRect.top, greaterThanOrEqualTo(0));
  expect(labelRect.top, greaterThanOrEqualTo(viewport.top - .1));
  expect(rect.bottom, lessThanOrEqualTo(viewport.bottom + .1));
  expect(labelRect.bottom, lessThanOrEqualTo(rect.top));
  expect(editable(t, field).focusNode!.hasFocus, isTrue);
  expect(
      t.getRect(find.text('Preview')).bottom, lessThanOrEqualTo(keyboardTop));
  expect(t.takeException(), isNull);
}

void main() {
  for (final kind in [
    ShapePreset.square,
    ShapePreset.rectangle,
    ShapePreset.lShape,
    ShapePreset.uShape,
    ShapePreset.tShape
  ]) {
    testWidgets(
        '${kind.label}: keyboard and rotation retain text, focus and reachable actions',
        (t) async {
      t.view.physicalSize = const Size(320, 740);
      await open(t, kind);
      final id = kind == ShapePreset.square
          ? ShapeDimension.width
          : ShapeDimension.height;
      await edit(t, id, '3600');
      t.view.viewInsets = const FakeViewPadding(bottom: 280);
      await t.pumpAndSettle();
      visibleField(t, id);
      t.view.physicalSize = const Size(740, 360);
      t.view.viewInsets = const FakeViewPadding(bottom: 140);
      await t.pumpAndSettle();
      visibleField(t, id);
      expect(t.widget<TextFormField>(input(id)).controller!.text, '3600');
      t.view.physicalSize = const Size(320, 740);
      t.view.viewInsets = const FakeViewPadding(bottom: 320);
      await t.pumpAndSettle();
      visibleField(t, id);
      t.view.viewInsets = const FakeViewPadding();
      await t.pumpAndSettle();
      expect(t.widget<TextFormField>(input(id)).controller!.text, '3600');
      await t.tap(find.text('Preview'));
      await t.pumpAndSettle();
      expect(find.byType(ShapeDialog), findsNothing);
    });
  }

  testWidgets(
      'Wide form uses two columns; large text labels wrap without clipping',
      (t) async {
    t.view.physicalSize = const Size(1024, 768);
    await open(t, ShapePreset.lShape);
    expect(t.getTopLeft(input(ShapeDimension.width)).dy,
        t.getTopLeft(input(ShapeDimension.height)).dy);
    expect(t.getTopLeft(input(ShapeDimension.width)).dx,
        lessThan(t.getTopLeft(input(ShapeDimension.height)).dx));
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    t.view.physicalSize = const Size(320, 568);
    await open(t, ShapePreset.lShape, textScale: 1.6);
    await edit(t, ShapeDimension.horizontalArm, '1000');
    t.view.viewInsets = const FakeViewPadding(bottom: 260);
    await t.pumpAndSettle();
    visibleField(t, ShapeDimension.horizontalArm);
    final label = find.text('D · Horizontal Arm Depth (within B) (mm)');
    final paragraph = t.renderObject<RenderParagraph>(label);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.size.height, greaterThan(20));
    expect(t.takeException(), isNull);
  });

  testWidgets('Next traverses fields; rapid Preview taps submit only once',
      (t) async {
    t.view.physicalSize = const Size(360, 740);
    var submissions = 0;
    ShapeSpec? result;
    await open(t, ShapePreset.rectangle, result: (spec) {
      submissions++;
      result = spec;
    });
    await edit(t, ShapeDimension.width, '4200');
    await t.testTextInput.receiveAction(TextInputAction.next);
    await t.pumpAndSettle();
    expect(
        editable(t, input(ShapeDimension.height)).focusNode!.hasFocus, isTrue);
    await t.testTextInput.receiveAction(TextInputAction.next);
    await t.pumpAndSettle();
    final rotation = find.byType(TextFormField).last;
    expect(editable(t, rotation).focusNode!.hasFocus, isTrue);
    final submit = t
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Preview'))
        .onPressed!;
    submit();
    submit();
    await t.pumpAndSettle();
    expect(submissions, 1);
    expect(result!.width, 4200);
    expect(t.takeException(), isNull);
  });

  testWidgets('Done validates, dismisses keyboard and returns the preview',
      (t) async {
    t.view.physicalSize = const Size(320, 740);
    ShapeSpec? result;
    await open(t, ShapePreset.rectangle, result: (value) => result = value);
    final rotation = find.byType(TextFormField).last;
    await t.ensureVisible(rotation);
    await t.tap(rotation);
    await t.enterText(rotation, '45');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(result!.rotation, 45);
    expect(find.byType(ShapeDialog), findsNothing);
    expect(t.testTextInput.isVisible, isFalse);
  });

  testWidgets(
      'Feet and inches input retains spaces and exposes Next on a text keyboard',
      (t) async {
    t.view.physicalSize = const Size(320, 568);
    await open(t, ShapePreset.rectangle, unit: DrawingUnit.feetInches);
    await edit(t, ShapeDimension.width, '12 6');
    final field = editable(t, input(ShapeDimension.width));
    expect(field.keyboardType, TextInputType.text);
    expect(field.textInputAction, TextInputAction.next);
    t.view.viewInsets = const FakeViewPadding(bottom: 280);
    await t.pumpAndSettle();
    visibleField(t, ShapeDimension.width);
    expect(field.controller!.text, '12 6');
  });
}
