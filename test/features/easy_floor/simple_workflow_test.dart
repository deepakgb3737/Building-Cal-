import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'drawing_screen_test.dart' as board;
import 'wall_resize_interaction_test.dart' as editing;

void main() {
  testWidgets(
      'Normal corner exposes Delete without an invalid straight-join action',
      (t) async {
    await board.open(t);
    await board.outline(t);
    await board.collapseTools(t);
    final view = board.painter(t);
    final at = t.getTopLeft(board.canvas) +
        view.screen(view.model.corners.values.first);
    await t.tapAt(at);
    await t.pumpAndSettle();
    expect(find.text('Selected corner'), findsOneWidget);
    expect(find.byTooltip('Delete selected geometry'), findsOneWidget);
    expect(find.text('Join straight segments'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'Toolbar has no manual wall/corner modes or duplicate stroke entries',
      (t) async {
    await board.open(t);
    expect(find.text('Smart touch'), findsNothing);
    await t.ensureVisible(find.byTooltip('More drawing tools'));
    await t.tap(find.byTooltip('More drawing tools'));
    await t.pumpAndSettle();
    for (final value in ['wall', 'corner', 'pan', 'outline', 'single']) {
      expect(
          find.byWidgetPredicate((w) => w is PopupMenuItem && w.value == value),
          findsNothing);
    }
    expect(find.text('Move wall'), findsNothing);
    expect(find.text('Move corner'), findsNothing);
    expect(find.text('Drawing help'), findsOneWidget);
    await t.tap(find.text('Drawing help'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Back to drawing'));
    await t.tap(find.text('Back to drawing'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Text and navigation can be toggled off to return to automatic drawing',
      (t) async {
    await board.open(t);
    for (final name in ['Text', 'Pan']) {
      final chip = find.widgetWithText(ChoiceChip, name);
      await t.ensureVisible(chip);
      await t.tap(chip);
      await t.pumpAndSettle();
      expect(t.widget<ChoiceChip>(chip).selected, isTrue);
      await t.tap(chip);
      await t.pumpAndSettle();
      expect(t.widget<ChoiceChip>(chip).selected, isFalse);
      expect(
          t
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Draw'))
              .selected,
          isTrue);
    }
    await board.collapseTools(t);
    await board.outline(t);
    expect(board.painter(t).model.walls.length, 4);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Selected wall shows only essential editing and optional collapsed advanced controls',
      (t) async {
    await editing.selectFirst(t);
    expect(find.text('Enter length'), findsOneWidget);
    expect(find.text('Lock length'), findsOneWidget);
    expect(find.byTooltip('Delete selected geometry'), findsOneWidget);
    for (final label in [
      'Room width / length',
      'Resize options',
      'Drag length'
    ]) {
      expect(find.text(label), findsNothing);
    }
    await board.moreWallOptions(t);
    expect(find.text('Room width / length'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
