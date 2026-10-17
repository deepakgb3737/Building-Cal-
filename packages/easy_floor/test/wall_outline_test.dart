import 'package:flutter_test/flutter_test.dart';
import 'package:easy_floor/src/utils/wall_outline.dart';

void main() {
  test('Small out-and-back slips are cleaned and a nearby endpoint closes', () {
    final points = WallOutline.straighten(const [
      Offset(0, 0),
      Offset(50, 0),
      Offset(50, -10),
      Offset(50, 0),
      Offset(100, 0),
      Offset(100, 100),
      Offset(0, 100),
      Offset(2, 3),
    ]);
    expect(points.length, 4);
    expect(points.every((p) => p.dy >= 0), isTrue);
    expect(
        () => WallOutline.straighten(const [
              Offset(0, 0),
              Offset(100, 0),
              Offset(100, 100),
            ]),
        throwsArgumentError);
  });
  test('Shaky rectangle becomes four connected axis-aligned walls', () {
    final points = WallOutline.straighten(const [
      Offset(0, 0),
      Offset(50, 1),
      Offset(100, 0),
      Offset(99, 50),
      Offset(100, 100),
      Offset(50, 99),
      Offset(0, 100),
      Offset(1, 50),
      Offset(0, 0),
    ]);
    expect(points.length, 4);
    for (var i = 0; i < points.length; i++) {
      final delta = points[(i + 1) % points.length] - points[i];
      expect(delta.dx == 0 || delta.dy == 0, isTrue);
    }
  });
  test('Concave corners and deliberate diagonal walls survive', () {
    final lShape = WallOutline.straighten(const [
      Offset(0, 0),
      Offset(200, 0),
      Offset(200, 100),
      Offset(100, 100),
      Offset(100, 200),
      Offset(0, 200),
      Offset(0, 0),
    ]);
    expect(lShape.length, 6);
    expect(lShape, contains(const Offset(100, 100)));
    final triangle = WallOutline.straighten(const [
      Offset(0, 0),
      Offset(100, 100),
      Offset(0, 100),
      Offset(0, 0),
    ]);
    expect(triangle.length, 3);
    expect(triangle, contains(const Offset(100, 100)));
    expect(
        WallOutline.straighten(
            const [Offset(0, 0), Offset(100, 0), Offset(0, 0)]),
        isEmpty);
  });
}
