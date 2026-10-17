import 'package:flutter_test/flutter_test.dart';
import 'drawing_screen_test.dart' as board;
import 'floating_palette_test.dart' show palette, handle;

void main() {
  testWidgets(
      'Labels avoid the moved toolbar and release its space when hidden',
      (t) async {
    await board.open(t);
    await board.outline(t);
    final before = board.painter(t).model.toJson();
    await t.drag(handle, const Offset(0, -500));
    await t.pumpAndSettle();
    final offset = t.getTopLeft(board.canvas);
    final tools = t.getRect(palette).shift(-offset);
    final view = board.painter(t);
    expect(view.labelBounds, isNotEmpty);
    for (final bounds in view.labelBounds!.values) {
      expect(bounds.overlaps(tools), isFalse);
    }
    expect(view.labelObstacles, contains(tools));
    expect(view.model.toJson(), before);
    await t.tap(find.byTooltip('Hide UI'));
    await t.pumpAndSettle();
    expect(board.painter(t).labelObstacles, isNot(contains(tools)));
    expect(board.painter(t).model.toJson(), before);
    await t.tap(find.byTooltip('Show Tools'));
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), before);
    expect(t.takeException(), isNull);
  });
}
