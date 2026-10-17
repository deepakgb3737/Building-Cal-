import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_floor/easy_floor.dart';
import 'package:easy_floor/src/utils/wall_dimensions.dart';

void main() {
  test('Overlapping and crossing outlines are rejected', () {
    expect(
        () => WallDimensions.validate(const [
              Offset(0, 0),
              Offset(100, 100),
              Offset(0, 100),
              Offset(100, 0)
            ]),
        throwsArgumentError);
    expect(
        () => WallDimensions.validate(const [
              Offset(0, 0),
              Offset(100, 0),
              Offset(100, 100),
              Offset(20, 100),
              Offset(20, 0),
              Offset(80, 0),
              Offset(80, 120),
              Offset(0, 120)
            ]),
        throwsArgumentError);
  });
  testWidgets('Angled wall handle adjusts length continuously by hand',
      (tester) async {
    final points = [
      const Offset(20, 20),
      const Offset(120, 120),
      const Offset(20, 120)
    ];
    final r = Room(
        id: 'r', wallPoints: points, path: Path()..addPolygon(points, true));
    await tester
        .pumpWidget(MaterialApp(home: FloorPlanEditor(initialRooms: [r])));
    await tester.tapAt(tester.getTopLeft(find.byType(InteractiveViewer)) +
        const Offset(50, 90));
    await tester.pumpAndSettle();
    expect(find.text('Edit wall lengths'), findsOneWidget);
    final origin = tester.getTopLeft(find.byType(InteractiveViewer));
    final gesture = await tester.startGesture(origin + const Offset(70, 70));
    await gesture.moveTo(origin + const Offset(80, 80));
    await gesture.moveTo(origin + const Offset(90, 90));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(r.wallPoints!.first, const Offset(20, 20));
    expect(r.wallPoints![1].dx, closeTo(140, .001));
    expect(r.wallPoints![1].dy, closeTo(140, .001));
    expect(tester.takeException(), isNull);
  });
  test(
      'Diagonal wall edit uses its actual length and keeps starting corner fixed',
      () {
    final points = [
      const Offset(0, 0),
      const Offset(100, 100),
      const Offset(0, 100)
    ];
    final r = Room(
        id: 'r', wallPoints: points, path: Path()..addPolygon(points, true));
    WallDimensions.resize(r, [], 0, 2000);
    expect((r.wallPoints![1] - r.wallPoints![0]).distance * 10,
        closeTo(2000, 1e-8));
    expect(r.wallPoints!.first, Offset.zero);
    expect(r.wallPoints![1].dx, closeTo(r.wallPoints![1].dy, 1e-8));
  });
  testWidgets('Individual wall control works on a small screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final points = [
      const Offset(20, 20),
      const Offset(120, 20),
      const Offset(120, 120),
      const Offset(20, 120)
    ];
    final r = Room(
        id: 'r', wallPoints: points, path: Path()..addPolygon(points, true));
    await tester
        .pumpWidget(MaterialApp(home: FloorPlanEditor(initialRooms: [r])));
    await tester.tapAt(tester.getTopLeft(find.byType(InteractiveViewer)) +
        const Offset(60, 60));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit wall lengths'));
    await tester.tap(find.text('Edit wall lengths'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '3');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(r.path.getBounds().width, closeTo(300, .001));
    expect(tester.takeException(), isNull);
  });
  Room room() {
    final points = [
      const Offset(0, 0),
      const Offset(100, 0),
      const Offset(100, 100),
      const Offset(0, 100)
    ];
    return Room(
        id: 'r', wallPoints: points, path: Path()..addPolygon(points, true));
  }

  test('One wall length moves connected walls and survives SVG export', () {
    final r = room();
    r.name = 'Kitchen & dining <site>';
    WallDimensions.resize(r, [], 0, 3000);
    expect(r.wallPoints![0], Offset.zero);
    expect(r.wallPoints![1], const Offset(300, 0));
    expect(r.wallPoints![2], const Offset(300, 100));
    expect(SvgParser.calculateArea(r.path), closeTo(3, .001));
    final imported =
        SvgParser.loadFromSVG(SvgParser.generateSVG([r], []))['rooms']
            as List<Room>;
    expect(imported.first.wallPoints, r.wallPoints);
    expect(imported.first.name, r.name);
  });
  test('Invalid edits do not change the outline', () {
    final r = room();
    final before = r.path.getBounds();
    expect(() => WallDimensions.resize(r, [], 0, 0), throwsArgumentError);
    expect(
        () => WallDimensions.resize(r,
            [Door(id: 'd', path: Path(), roomId: 'r', edge: 'top')], 0, 3000),
        throwsArgumentError);
    expect(r.path.getBounds(), before);
  });
}
