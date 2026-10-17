import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/room.dart';
import '../models/door.dart';
import '../utils/svg_parser.dart';

/// Custom painter for drawing the floor plan
class FloorPainter extends CustomPainter {
  final List<Room> rooms;
  final List<Door> doors;
  final Room? selectedRoom;
  final Door? selectedDoor;
  final Path? previewPath;
  final TextStyle? wallLabelStyle;

  FloorPainter({
    required this.rooms,
    required this.doors,
    this.selectedRoom,
    this.selectedDoor,
    this.previewPath,
    this.wallLabelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw rooms with custom colors and dark gray walls
    for (final room in rooms) {
      // Room fill - use room's custom color
      final fillPaint = Paint()
        ..color = room.fillColor
        ..style = PaintingStyle.fill;

      // Wall border - dark gray
      final borderPaint = Paint()
        ..color = const Color(0xFF424242) // Dark gray
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      canvas.drawPath(room.path, fillPaint);

      // Draw border following the actual path shape
      // Draw border segments, skipping door openings
      _drawRoomBorderWithDoors(canvas, room, borderPaint);

      // Draw room area
      final bounds = room.path.getBounds();
      final area = SvgParser.calculateArea(room.path);
      _drawRoomArea(canvas, bounds.center, area, room.name);

      // Draw resize handles for selected room
      if (room == selectedRoom) {
        final points = room.wallPoints;
        if (points != null) {
          for (var i = 0; i < points.length; i++) {
            final a = points[i];
            final b = points[(i + 1) % points.length];
            final delta = b - a;
            if (delta.distance == 0) continue;
            final text = TextPainter(
                textDirection: TextDirection.ltr,
                text: TextSpan(
                    text:
                        '${i + 1}: ${(delta.distance / 100).toStringAsFixed(2)} m',
                    style: wallLabelStyle))
              ..layout();
            final centre =
                (a + b) / 2 + Offset(delta.dy, -delta.dx) / delta.distance * 16;
            final origin = centre - Offset(text.width / 2, text.height / 2);
            canvas.drawRect((origin & text.size).inflate(3),
                Paint()..color = room.fillColor);
            text.paint(canvas, origin);
          }
        }
        if (points != null) {
          final paint = Paint()
            ..color = wallLabelStyle?.color ?? room.fillColor;
          for (var i = 0; i < points.length; i++) {
            canvas.drawRect(
                Rect.fromCenter(center: points[i], width: 14, height: 14),
                paint);
            canvas.drawCircle(
                (points[i] + points[(i + 1) % points.length]) / 2, 7, paint);
          }
        } else {
          final b = room.path.getBounds();
          final hPaint = Paint()..color = Colors.red;
          const s = 6.0;
          for (final centre in [
            b.topCenter,
            b.bottomCenter,
            b.centerLeft,
            b.centerRight
          ]) {
            canvas.drawCircle(centre, 7, hPaint);
          }

          // Draw handles at all four corners
          canvas.drawRect(
            Rect.fromLTWH(b.left - s, b.top - s, s * 2, s * 2),
            hPaint,
          );
          canvas.drawRect(
            Rect.fromLTWH(b.right - s, b.top - s, s * 2, s * 2),
            hPaint,
          );
          canvas.drawRect(
            Rect.fromLTWH(b.left - s, b.bottom - s, s * 2, s * 2),
            hPaint,
          );
          canvas.drawRect(
            Rect.fromLTWH(b.right - s, b.bottom - s, s * 2, s * 2),
            hPaint,
          );
        }
      }
    }

    // Draw doors with swing arcs
    for (final door in doors) {
      _drawDoorWithSwing(canvas, door);
    }

    // Draw dimensions
    _drawDimensions(canvas, selectedRoom == null ? rooms : [selectedRoom!]);

    // Draw selection highlight
    if (selectedRoom != null) {
      final b = selectedRoom!.path.getBounds();
      canvas.drawRect(
        b.inflate(4),
        Paint()
          ..color = Colors.orange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    } else if (selectedDoor != null) {
      final b = selectedDoor!.path.getBounds();
      canvas.drawRect(
        b.inflate(4),
        Paint()
          ..color = Colors.orange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    if (previewPath != null) {
      canvas.drawPath(
        previewPath!,
        Paint()
          ..color = Colors.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _drawRoomArea(
    Canvas canvas,
    Offset center,
    double area,
    String roomName,
  ) {
    // Draw room name
    final namePainter = TextPainter(
      text: TextSpan(
        text: roomName,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    namePainter.layout();
    namePainter.paint(
      canvas,
      center - Offset(namePainter.width / 2, namePainter.height / 2 - 12),
    );

    // Draw area below name
    final areaPainter = TextPainter(
      text: TextSpan(
        text: "${area.toStringAsFixed(2)} m²",
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    areaPainter.layout();
    areaPainter.paint(
      canvas,
      center - Offset(areaPainter.width / 2, areaPainter.height / 2 + 8),
    );
  }

  void _drawDoorWithSwing(Canvas canvas, Door door) {
    final bounds = door.path.getBounds();
    final center = bounds.center;
    final doorWidth = math.max(bounds.width, bounds.height);

    // Determine door opening lines based on door edge
    Offset doorLineStart;
    Offset doorLineEnd;

    switch (door.edge) {
      case 'top':
        doorLineStart = Offset(center.dx - doorWidth / 2, center.dy);
        doorLineEnd = Offset(center.dx + doorWidth / 2, center.dy);
        break;
      case 'bottom':
        doorLineStart = Offset(center.dx - doorWidth / 2, center.dy);
        doorLineEnd = Offset(center.dx + doorWidth / 2, center.dy);
        break;
      case 'left':
        doorLineStart = Offset(center.dx, center.dy - doorWidth / 2);
        doorLineEnd = Offset(center.dx, center.dy + doorWidth / 2);
        break;
      case 'right':
        doorLineStart = Offset(center.dx, center.dy - doorWidth / 2);
        doorLineEnd = Offset(center.dx, center.dy + doorWidth / 2);
        break;
      default:
        return;
    }

    // Draw door opening indicators (small perpendicular lines at gap edges)
    final gapPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw small perpendicular lines to indicate the gap
    if (door.edge == 'top' || door.edge == 'bottom') {
      // Horizontal door - draw vertical indicator lines
      const indicatorLength = 6.0;
      canvas.drawLine(
        doorLineStart,
        Offset(
          doorLineStart.dx,
          doorLineStart.dy -
              (door.edge == 'top' ? indicatorLength : -indicatorLength),
        ),
        gapPaint,
      );
      canvas.drawLine(
        doorLineEnd,
        Offset(
          doorLineEnd.dx,
          doorLineEnd.dy -
              (door.edge == 'top' ? indicatorLength : -indicatorLength),
        ),
        gapPaint,
      );
    } else {
      // Vertical door - draw horizontal indicator lines
      const indicatorLength = 6.0;
      canvas.drawLine(
        doorLineStart,
        Offset(
          doorLineStart.dx -
              (door.edge == 'left' ? indicatorLength : -indicatorLength),
          doorLineStart.dy,
        ),
        gapPaint,
      );
      canvas.drawLine(
        doorLineEnd,
        Offset(
          doorLineEnd.dx -
              (door.edge == 'left' ? indicatorLength : -indicatorLength),
          doorLineEnd.dy,
        ),
        gapPaint,
      );
    }
  }

  void _drawRoomBorderWithDoors(Canvas canvas, Room room, Paint borderPaint) {
    // Get the path outline
    final pathMetrics = room.path.computeMetrics();

    for (final metric in pathMetrics) {
      final path = metric.extractPath(0, metric.length);

      // Draw the path border
      canvas.drawPath(path, borderPaint);

      // For each door opening, cover the border with canvas color to create gap
      for (final doorOpening in room.doorOpenings) {
        final openingBounds = doorOpening.getBounds();

        // Draw canvas background color to create gap in border
        final gapPaint = Paint()
          ..color = const Color(0xFFE3F2FD) // Canvas background color
          ..style = PaintingStyle.fill;

        // Create a wider rectangle to cover the border line
        final gapRect = openingBounds.inflate(4);
        canvas.drawRect(gapRect, gapPaint);

        // Redraw room fill inside the opening (use room's actual color)
        final roomFillPaint = Paint()
          ..color = room.fillColor
          ..style = PaintingStyle.fill;
        canvas.drawRect(openingBounds, roomFillPaint);
      }
    }
  }

  void _drawDimensions(Canvas canvas, List<Room> rooms) {
    if (rooms.isEmpty) return;

    // Get overall bounds
    Rect? overallBounds;
    for (final room in rooms) {
      final bounds = room.path.getBounds();
      if (overallBounds == null) {
        overallBounds = bounds;
      } else {
        overallBounds = overallBounds.expandToInclude(bounds);
      }
    }

    if (overallBounds == null) return;

    final dimPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const textStyle = TextStyle(color: Colors.green, fontSize: 12);

    // Draw horizontal dimensions
    _drawDimensionLine(
      canvas,
      Offset(overallBounds.left, overallBounds.top - 20),
      Offset(overallBounds.right, overallBounds.top - 20),
      '${(overallBounds.width / 100).toStringAsFixed(2)} m',
      dimPaint,
      textStyle,
    );

    // Draw vertical dimensions
    _drawDimensionLine(
      canvas,
      Offset(overallBounds.left - 20, overallBounds.top),
      Offset(overallBounds.left - 20, overallBounds.bottom),
      '${(overallBounds.height / 100).toStringAsFixed(2)} m',
      dimPaint,
      textStyle,
      vertical: true,
    );
  }

  void _drawDimensionLine(
    Canvas canvas,
    Offset start,
    Offset end,
    String label,
    Paint paint,
    TextStyle textStyle, {
    bool vertical = false,
  }) {
    canvas.drawLine(start, end, paint);

    final textPainter = TextPainter(
      text: TextSpan(text: label, style: textStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final labelPos = Offset(
      (start.dx + end.dx) / 2 - textPainter.width / 2,
      (start.dy + end.dy) / 2 - textPainter.height / 2,
    );
    textPainter.paint(canvas, labelPos);
  }

  @override
  bool shouldRepaint(_) => true;
}
