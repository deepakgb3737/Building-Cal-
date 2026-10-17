import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/shape_dialog.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';
import 'drawing_screen_test.dart' as board;

Finder chip(String name) => find.widgetWithText(ChoiceChip, name);

void main() {
  testWidgets('Landscape primary actions do not scroll when one row fits',
      (t) async {
    await board.open(t);
    t.view.physicalSize = const Size(740, 320);
    await t.pumpAndSettle();
    expect(Scrollable.of(t.element(chip('Undo'))).position.maxScrollExtent, 0);
    final geometry = board.painter(t).model.toJson();
    await board.collapseTools(t);
    t.view.physicalSize = const Size(320, 568);
    await t.pumpAndSettle();
    expect(find.byTooltip('Expand drawing tools'), findsOneWidget);
    await board.expandTools(t);
    expect(Scrollable.of(t.element(chip('Undo'))).position.maxScrollExtent, 0);
    expect(board.painter(t).model.toJson(), geometry);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Phone toolbar has two tool rows, readable labels and finger targets',
      (t) async {
    await board.open(t);
    final undo = t.getRect(chip('Undo'));
    expect(t.getSize(find.byKey(const ValueKey('drawingToolPalette'))).height,
        lessThan(145));
    final row2 = t.getRect(chip('Draw'));
    expect(row2.top, greaterThan(undo.bottom));
    Rect? previous;
    for (final label in ['Draw', 'Wall', 'Shapes', 'Pan', 'Text', 'Labels']) {
      final rect = t.getRect(chip(label));
      expect(rect.top, closeTo(row2.top, .1));
      expect(rect.width, greaterThanOrEqualTo(44));
      expect(rect.height, greaterThanOrEqualTo(44));
      if (previous != null) {
        expect(rect.left - previous.right, greaterThanOrEqualTo(4));
      }
      previous = rect;
      expect(chip(label).hitTestable(), findsOneWidget);
      expect(
          t
              .getSize(
                  find.descendant(of: chip(label), matching: find.text(label)))
              .height,
          lessThanOrEqualTo(14));
    }
    final active = t.widget<ChoiceChip>(chip('Draw'));
    final inactive = t.widget<ChoiceChip>(chip('Shapes'));
    final disabled = t.widget<ChoiceChip>(chip('Undo'));
    expect(active.selected, isTrue);
    expect(active.selectedColor, AppColors.blueSurface);
    expect(inactive.backgroundColor, AppColors.surfaceAlt);
    expect(disabled.onSelected, isNull);
    expect(disabled.disabledColor, AppColors.white);
    expect(t.takeException(), isNull);
  });

  testWidgets('Shapes exposes seven presets without duplicating drawing tools',
      (t) async {
    await board.open(t);
    await t.tap(find.byTooltip('Shapes'));
    await t.pumpAndSettle();
    final tiles = find.descendant(
        of: find.byType(BottomSheet), matching: find.byType(ChoiceChip));
    expect(tiles, findsNWidgets(7));
    final tileRects = [
      for (final tile in tiles.evaluate()) t.getRect(find.byWidget(tile.widget))
    ];
    for (var i = 0; i < tileRects.length; i++) {
      expect(tileRects[i].width, greaterThanOrEqualTo(90));
      for (var j = i + 1; j < tileRects.length; j++) {
        expect(tileRects[i].inflate(1.9).overlaps(tileRects[j].inflate(1.9)),
            isFalse);
      }
    }
    for (final label in [
      'Square',
      'Rectangle',
      'L-shape',
      'U-shape',
      'T-shape',
      'Triangle',
      'Irregular Shape'
    ]) {
      final tile =
          find.descendant(of: find.byType(BottomSheet), matching: chip(label));
      expect(tile, findsOneWidget);
      expect(tile.hitTestable(), findsOneWidget);
    }
    await t.tap(find.widgetWithText(ChoiceChip, 'Square'));
    await t.pumpAndSettle();
    expect(find.byType(ShapeDialog), findsOneWidget);
    expect(find.text('Square dimensions'), findsOneWidget);
    expect(board.painter(t).model.walls, isEmpty);
    await t.tap(find.byTooltip('Cancel'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Rotation, narrow screens and large text keep tools inside the drawing board',
      (t) async {
    await board.open(t);
    for (final size in [
      const Size(430, 900),
      const Size(740, 320),
      const Size(240, 420),
      const Size(320, 640)
    ]) {
      t.view.physicalSize = size;
      t.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpAndSettle();
      final canvas = t.getRect(board.canvas);
      final tools = t.getRect(find.byKey(const ValueKey('drawingToolPalette')));
      expect(tools.left, greaterThanOrEqualTo(canvas.left));
      expect(tools.right, lessThanOrEqualTo(canvas.right));
      expect(tools.top, greaterThanOrEqualTo(canvas.top));
      expect(tools.bottom, lessThanOrEqualTo(canvas.bottom));
      await t.ensureVisible(find.byTooltip('Shapes'));
      expect(find.byTooltip('Shapes').hitTestable(), findsOneWidget);
      expect(board.painter(t).model.walls, isEmpty);
      expect(t.takeException(), isNull);
    }
  });
}
