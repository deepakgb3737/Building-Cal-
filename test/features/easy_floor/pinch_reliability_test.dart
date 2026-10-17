import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'drawing_screen_test.dart' as board;

void main() {
  testWidgets(
      'Cancelling a tiny pinch restores the camera and next wall drawing works',
      (t) async {
    await board.open(t);
    final view = board.painter(t), offset = t.getTopLeft(board.canvas);
    final a = await t.startGesture(offset + const Offset(100, 280), pointer: 1);
    final b = await t.startGesture(offset + const Offset(220, 280), pointer: 2);
    await a.moveTo(offset + const Offset(99, 280));
    await b.moveTo(offset + const Offset(221, 280));
    await t.pump();
    await a.cancel();
    await b.up();
    await t.pumpAndSettle();
    expect(board.painter(t).scale, view.scale);
    expect(board.painter(t).origin, view.origin);
    final draw = await t.startGesture(offset + const Offset(60, 100));
    await draw.moveTo(offset + const Offset(260, 100));
    await t.pump();
    await draw.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.walls.length, 1);
    expect(t.takeException(), isNull);
  });

  testWidgets('Small two-finger movements zoom without a gesture dead zone',
      (t) async {
    await board.open(t);
    final offset = t.getTopLeft(board.canvas), scale = board.painter(t).scale;
    final a = await t.startGesture(offset + const Offset(100, 280), pointer: 1);
    final b = await t.startGesture(offset + const Offset(220, 280), pointer: 2);
    await a.moveTo(offset + const Offset(99, 280));
    await b.moveTo(offset + const Offset(221, 280));
    await t.pump();
    expect(board.painter(t).scale, closeTo(scale * 122 / 120, 1e-8));
    await a.up();
    await b.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.walls, isEmpty);
  });

  testWidgets(
      'Trackpad pinch uses current camera and keeps its midpoint anchored',
      (t) async {
    await board.open(t);
    await board.outline(t);
    final before = board.painter(t), offset = t.getTopLeft(board.canvas);
    final at = offset + const Offset(160, 280);
    final gesture = await t.createGesture(kind: PointerDeviceKind.trackpad);
    await gesture.panZoomStart(at);
    await gesture.panZoomUpdate(at, scale: 1.2);
    await t.pump();
    expect(board.painter(t).scale, closeTo(before.scale * 1.2, 1e-8));
    expect(board.painter(t).origin.dx,
        closeTo(160 - (160 - before.origin.dx) * 1.2, 1e-8));
    await gesture.panZoomUpdate(at, scale: .8);
    await t.pump();
    expect(board.painter(t).scale, closeTo(before.scale * .8, 1e-8));
    await gesture.panZoomEnd();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), before.model.toJson());
  });

  testWidgets(
      'Pinch changes scale immediately and repeated pinches keep working',
      (t) async {
    await board.open(t);
    await board.outline(t);
    final original = board.painter(t).model.toJson();
    final offset = t.getTopLeft(board.canvas);
    for (final spread in [true, false, true, false]) {
      final before = board.painter(t).scale;
      final a =
          await t.startGesture(offset + const Offset(100, 280), pointer: 1);
      final b =
          await t.startGesture(offset + const Offset(220, 280), pointer: 2);
      await a.moveTo(offset + Offset(spread ? 80 : 120, 280));
      await b.moveTo(offset + Offset(spread ? 240 : 200, 280));
      await t.pump();
      expect(board.painter(t).scale,
          closeTo(before * (spread ? 160 / 120 : 80 / 120), 1e-8));
      await a.up();
      await b.up();
      await t.pumpAndSettle();
      expect(board.painter(t).model.toJson(), original);
    }
  });

  testWidgets(
      'Adding a second finger during drawing rolls back drawing and zooms',
      (t) async {
    await board.open(t);
    final offset = t.getTopLeft(board.canvas);
    final a = await t.startGesture(offset + const Offset(100, 200), pointer: 1);
    await a.moveTo(offset + const Offset(140, 200));
    await t.pump();
    final scale = board.painter(t).scale;
    final b = await t.startGesture(offset + const Offset(240, 200), pointer: 2);
    await a.moveTo(offset + const Offset(110, 200));
    await b.moveTo(offset + const Offset(270, 200));
    await t.pump();
    expect(board.painter(t).scale, closeTo(scale * 1.6, 1e-8));
    expect(board.painter(t).model.walls, isEmpty);
    expect(board.painter(t).preview, isEmpty);
    await a.up();
    await b.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.walls, isEmpty);
  });
}
