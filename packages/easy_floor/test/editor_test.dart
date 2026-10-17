import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_floor/easy_floor.dart';

void main() {
  testWidgets('Dragging a side changes width without typing or changing length',
      (tester) async {
    final room = Room(
        id: 'r', path: Path()..addRect(const Rect.fromLTWH(40, 40, 100, 100)));
    await tester
        .pumpWidget(MaterialApp(home: FloorPlanEditor(initialRooms: [room])));
    await tester.tapAt(tester.getTopLeft(find.byType(InteractiveViewer)) +
        const Offset(90, 90));
    await tester.pumpAndSettle();
    final origin = tester.getTopLeft(find.byType(InteractiveViewer));
    final gesture = await tester.startGesture(origin + const Offset(140, 90));
    await gesture.moveTo(origin + const Offset(160, 90));
    await gesture.moveTo(origin + const Offset(180, 90));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(room.path.getBounds().width, closeTo(140, .001));
    expect(room.path.getBounds().height, closeTo(100, .001));
    expect(room.path.getBounds().left, closeTo(40, .001));
    expect(tester.takeException(), isNull);
  });
  testWidgets('Pencil closes a room from the actual first touch and selects it',
      (tester) async {
    List<Room> result = [];
    await tester.pumpWidget(MaterialApp(
        home: FloorPlanEditor(onChanged: (rooms, doors) => result = rooms)));
    await tester.tap(find.text('Walls'));
    await tester.pumpAndSettle();
    final origin = tester.getTopLeft(find.byType(InteractiveViewer));
    final gesture = await tester.startGesture(origin + const Offset(20, 20));
    await gesture.moveTo(origin + const Offset(120, 20));
    await gesture.moveTo(origin + const Offset(120, 120));
    await gesture.moveTo(origin + const Offset(20, 120));
    await gesture.moveTo(origin + const Offset(22, 22));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(result, hasLength(1));
    expect(result.single.wallPoints, hasLength(4));
    expect(find.text('Edit wall lengths'), findsOneWidget);
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(result, isEmpty);
    await tester.tap(find.byTooltip('Redo'));
    await tester.pumpAndSettle();
    expect(result, hasLength(1));
    expect(result.single.wallPoints, hasLength(4));
    expect(tester.takeException(), isNull);
  });
  test('Area follows concave outlines and survives rotation', () {
    final room = Path()
      ..moveTo(0, 0)
      ..lineTo(200, 0)
      ..lineTo(200, 100)
      ..lineTo(100, 100)
      ..lineTo(100, 200)
      ..lineTo(0, 200)
      ..close();
    expect(SvgParser.calculateArea(room), closeTo(3, .0001));
    final rotation = Matrix4.rotationZ(math.pi / 4);
    expect(SvgParser.calculateArea(room.transform(rotation.storage)),
        closeTo(3, .0001));
    expect(
        SvgParser.calculateArea(
            Path()..addOval(const Rect.fromLTWH(0, 0, 200, 200))),
        closeTo(math.pi, .002));
    expect(SvgParser.calculateArea(Path()), 0);
  });

  testWidgets('Small screen keeps canvas and shape controls accessible',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: FloorPlanEditor()));
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Room shapes'));
    await tester.pumpAndSettle();
    expect(find.text('Square room'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
