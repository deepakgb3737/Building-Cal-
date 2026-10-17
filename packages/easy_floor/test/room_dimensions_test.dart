import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_floor/easy_floor.dart';
import 'package:easy_floor/src/utils/room_dimensions.dart';

void main() {
  test('Feet and metres use exact conversion factors', () {
    expect(DimensionUnit.feet.toMm(10), 3048);
    expect(DimensionUnit.metres.toMm(3), 3000);
    expect(DimensionUnit.feet.fromMm(3048), 10);
  });
  testWidgets('Selected room dimensions can be edited on mobile',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final room = Room(
        id: 'r', path: Path()..addRect(const Rect.fromLTWH(20, 20, 100, 100)));
    await tester
        .pumpWidget(MaterialApp(home: FloorPlanEditor(initialRooms: [room])));
    await tester.tapAt(tester.getTopLeft(find.byType(InteractiveViewer)) +
        const Offset(60, 60));
    await tester.pumpAndSettle();
    final dimensions = find.text('Width 1000 mm · Length 1000 mm');
    await tester.ensureVisible(dimensions);
    await tester.tap(dimensions);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Millimetres'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Metres').last);
    await tester.pumpAndSettle();
    expect(find.text('Width (m)'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), '3');
    await tester.enterText(find.byType(TextFormField).at(1), '2');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(room.path.getBounds().width, closeTo(300, 1e-5));
    expect(room.path.getBounds().height, closeTo(200, 1e-5));
    expect(tester.takeException(), isNull);
  });
  test('Dimensions convert mm and keep doors attached to the resized room', () {
    final room = Room(
        id: 'room',
        path: Path()..addRect(const Rect.fromLTWH(50, 50, 100, 100)),
        doorOpenings: [Path()..addRect(const Rect.fromLTWH(80, 50, 20, 5))]);
    final door = Door(
        id: 'door',
        roomId: 'room',
        edge: 'top',
        path: Path()..addRect(const Rect.fromLTWH(80, 50, 20, 5)));
    RoomDimensions.resize(room, [door], 3000, 2000);
    expect(room.path.getBounds().width, closeTo(300, 1e-5));
    expect(room.path.getBounds().height, closeTo(200, 1e-5));
    expect(room.path.getBounds().topLeft, const Offset(50, 50));
    expect(SvgParser.calculateArea(room.path), closeTo(6, .001));
    expect(door.path.getBounds(), room.doorOpenings.single.getBounds());
    expect(door.path.getBounds().left, closeTo(140, 1e-5));
    expect(() => RoomDimensions.resize(room, [door], double.nan, 2000),
        throwsArgumentError);
    expect(() => RoomDimensions.resize(room, [door], 0, 2000),
        throwsArgumentError);
  });
}
