import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:xml/xml.dart' as xml;
import '../models/room.dart';
import '../models/door.dart';

/// Helper class for parsing SVG path commands
class _PathCommand {
  final String command;
  final List<double> coordinates;

  _PathCommand(this.command, this.coordinates);
}

/// Utility class for SVG parsing and generation
class SvgParser {
  /// Parse SVG content and extract rooms and doors
  static Map<String, dynamic> loadFromSVG(String svgContent) {
    try {
      final document = xml.XmlDocument.parse(svgContent);
      final newRooms = <Room>[];
      final newDoors = <Door>[];

      // Find all path elements (rooms)
      final pathElements = document.findAllElements('path');
      int roomIndex = 1;

      for (final pathElement in pathElements) {
        final pathData = pathElement.getAttribute('d');
        if (pathData == null || pathData.isEmpty) continue;

        final fill = pathElement.getAttribute('fill');

        // Check if this is a room (has fill color) or a door line (just stroke)
        if (fill != null && fill != 'none') {
          // This is a room
          final roomPath = _parseSVGPath(pathData);
          final fillColor = _hexToColor(fill);

          String roomName = 'Room $roomIndex';
          roomIndex++;

          newRooms.add(
            Room(
              id: UniqueKey().toString(),
              path: roomPath,
              fillColor: fillColor ?? const Color(0xFFF5F5DC),
              name: roomName,
              wallPoints:
                  _readWallPoints(pathElement.getAttribute('data-wall-points')),
            ),
          );
        }
      }

      // Find text elements for room names
      final textElements = document.findAllElements('text');

      // First, collect all text elements with their positions
      final textItems = <Map<String, dynamic>>[];
      for (final textElement in textElements) {
        final text = textElement.innerText.trim();
        if (text.isEmpty) continue;

        final x = double.tryParse(textElement.getAttribute('x') ?? '') ?? 0;
        final y = double.tryParse(textElement.getAttribute('y') ?? '') ?? 0;

        // Check if this is an area text (contains numbers and m²/m2/mÂ²)
        final normalizedText = text
            .toLowerCase()
            .replaceAll('mâ²', 'm²')
            .replaceAll('mÂ²', 'm²')
            .replaceAll('m2', 'm²');
        final isAreaText = RegExp(
          r'^\d+\.?\d*\s*m²\s*$',
          caseSensitive: false,
        ).hasMatch(normalizedText);

        textItems.add({
          'text': text,
          'position': Offset(x, y),
          'isArea': isAreaText,
        });
      }

      // Match non-area text elements to rooms
      for (final textItem in textItems) {
        if (textItem['isArea'] == true) continue; // Skip area text

        final text = textItem['text'] as String;
        final textPos = textItem['position'] as Offset;

        if (newRooms.isEmpty) continue;

        // Find the nearest room to this text
        Room? nearestRoom;
        double minDistance = double.infinity;
        int nearestIndex = -1;

        for (int i = 0; i < newRooms.length; i++) {
          final room = newRooms[i];
          final bounds = room.path.getBounds();
          final center = bounds.center;
          final distance = (center - textPos).distance;

          final yOffset = textPos.dy - center.dy;
          final adjustedDistance =
              distance + (yOffset > 0 ? 50 : 0); // Penalize text below center

          if (adjustedDistance < minDistance) {
            minDistance = adjustedDistance;
            nearestRoom = room;
            nearestIndex = i;
          }
        }

        // Update room name if it's close enough (within 150 pixels)
        if (nearestRoom != null && nearestIndex != -1 && minDistance < 150) {
          // Double-check: ensure this is not area text (safety check)
          final normalizedText = text
              .toLowerCase()
              .replaceAll('mâ²', 'm²')
              .replaceAll('mÂ²', 'm²')
              .replaceAll('m2', 'm²');
          final looksLikeArea = RegExp(
            r'^\d+\.?\d*\s*m²\s*$',
            caseSensitive: false,
          ).hasMatch(normalizedText);

          // Skip if it looks like area text
          if (looksLikeArea) continue;

          // Only update if the room still has a default name or if this text is closer
          if (nearestRoom.name.startsWith('Room ') ||
              (textPos.dy < nearestRoom.path.getBounds().center.dy)) {
            newRooms[nearestIndex] = Room(
              id: nearestRoom.id,
              path: nearestRoom.path,
              doorOpenings: nearestRoom.doorOpenings,
              fillColor: nearestRoom.fillColor,
              name: text,
              wallPoints: nearestRoom.wallPoints,
            );
          }
        }
      }

      return {
        'rooms': newRooms,
        'doors': newDoors,
        'roomCounter': roomIndex,
      };
    } catch (e) {
      throw Exception('Error parsing SVG: $e');
    }
  }

  /// Parse SVG path data string to Flutter Path
  static Path _parseSVGPath(String pathData) {
    final path = Path();
    final commands = _parsePathCommands(pathData);

    double currentX = 0;
    double currentY = 0;

    for (final cmd in commands) {
      switch (cmd.command.toUpperCase()) {
        case 'M':
          if (cmd.coordinates.length >= 2) {
            currentX = cmd.coordinates[0];
            currentY = cmd.coordinates[1];
            path.moveTo(currentX, currentY);
          }
          break;
        case 'L':
          if (cmd.coordinates.length >= 2) {
            currentX = cmd.coordinates[0];
            currentY = cmd.coordinates[1];
            path.lineTo(currentX, currentY);
          }
          break;
        case 'H':
          if (cmd.coordinates.isNotEmpty) {
            currentX = cmd.coordinates[0];
            path.lineTo(currentX, currentY);
          }
          break;
        case 'V':
          if (cmd.coordinates.isNotEmpty) {
            currentY = cmd.coordinates[0];
            path.lineTo(currentX, currentY);
          }
          break;
        case 'C':
          if (cmd.coordinates.length >= 6) {
            path.cubicTo(
              cmd.coordinates[0],
              cmd.coordinates[1],
              cmd.coordinates[2],
              cmd.coordinates[3],
              cmd.coordinates[4],
              cmd.coordinates[5],
            );
            currentX = cmd.coordinates[4];
            currentY = cmd.coordinates[5];
          }
          break;
        case 'Q':
          if (cmd.coordinates.length >= 4) {
            path.quadraticBezierTo(
              cmd.coordinates[0],
              cmd.coordinates[1],
              cmd.coordinates[2],
              cmd.coordinates[3],
            );
            currentX = cmd.coordinates[2];
            currentY = cmd.coordinates[3];
          }
          break;
        case 'Z':
        case 'z':
          path.close();
          break;
      }
    }

    return path;
  }

  /// Parse path commands from SVG path data
  static List<_PathCommand> _parsePathCommands(String pathData) {
    final commands = <_PathCommand>[];
    final regex = RegExp(r'([MmLlHhVvCcQqZz])\s*([-\d.e]+(?:\s+[-\d.e]+)*)?');

    for (final match in regex.allMatches(pathData)) {
      final command = match.group(1)!;
      final coordsStr = match.group(2);

      List<double> coordinates = [];
      if (coordsStr != null) {
        coordinates = coordsStr
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .map((s) => double.tryParse(s.trim()) ?? 0)
            .toList();
      }

      commands.add(_PathCommand(command, coordinates));
    }

    return commands;
  }

  /// Convert hex color string to Color
  static Color? _hexToColor(String hex) {
    try {
      hex = hex.trim();
      if (hex.startsWith('#')) {
        hex = hex.substring(1);
      }
      if (hex.length == 6) {
        hex = 'FF$hex'; // Add alpha
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return null;
    }
  }

  /// Convert Path to SVG path data string by sampling points
  static String pathToSvgPathData(Path path) {
    final metrics = path.computeMetrics();
    final buffer = StringBuffer();
    bool isFirst = true;

    for (final metric in metrics) {
      final length = metric.length;
      final sampleCount = math.max(
        10,
        (length / 10).ceil(),
      );
      final step = length / sampleCount;

      for (int i = 0; i <= sampleCount; i++) {
        final distance = i * step;
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          final point = tangent.position;
          if (isFirst) {
            buffer.write(
              'M ${point.dx.toStringAsFixed(2)} ${point.dy.toStringAsFixed(2)} ',
            );
            isFirst = false;
          } else {
            buffer.write(
              'L ${point.dx.toStringAsFixed(2)} ${point.dy.toStringAsFixed(2)} ',
            );
          }
        }
      }

      // Close the path if it's closed
      if (path.getBounds().isEmpty == false) {
        final firstTangent = metric.getTangentForOffset(0);
        final lastTangent = metric.getTangentForOffset(length);
        if (firstTangent != null && lastTangent != null) {
          final firstPoint = firstTangent.position;
          final lastPoint = lastTangent.position;
          if ((firstPoint - lastPoint).distance < 1.0) {
            buffer.write('Z ');
          }
        }
      }
    }

    return buffer.toString().trim();
  }

  /// Convert Color to hex string
  static String colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).padLeft(6, '0').toUpperCase()}';
  }

  /// Calculate room area
  static double calculateArea(Path path) {
    double area = 0;
    for (final contour in path.computeMetrics(forceClosed: true)) {
      if (contour.length == 0) continue;
      final count = math.max(3, (contour.length / 0.25).ceil());
      final origin = contour.getTangentForOffset(0)!.position;
      var previous = origin;
      double twiceArea = 0;
      for (var i = 1; i < count; i++) {
        final point =
            contour.getTangentForOffset(contour.length * i / count)!.position;
        final a = previous - origin;
        final b = point - origin;
        twiceArea += a.dx * b.dy - b.dx * a.dy;
        previous = point;
      }
      area += twiceArea / 2;
    }
    // Curves are sampled at 0.25 drawing units; 100 units represent one metre.
    return area.abs() / 10000;
  }

  static List<Offset>? _readWallPoints(String? data) {
    if (data == null || data.trim().isEmpty) return null;
    final points = <Offset>[];
    for (final pair in data.trim().split(RegExp(r'\s+'))) {
      final parts = pair.split(',');
      if (parts.length != 2) return null;
      final x = double.tryParse(parts[0]);
      final y = double.tryParse(parts[1]);
      if (x == null || y == null || !x.isFinite || !y.isFinite) return null;
      points.add(Offset(x, y));
    }
    return points.length < 3 ? null : points;
  }

  /// Generate SVG content from rooms and doors
  static String generateSVG(List<Room> rooms, List<Door> doors) {
    // Calculate overall bounds
    Rect? overallBounds;
    for (final room in rooms) {
      final bounds = room.path.getBounds();
      overallBounds = overallBounds == null
          ? bounds
          : overallBounds.expandToInclude(bounds);
    }

    overallBounds ??= const Rect.fromLTWH(0, 0, 2000, 2000);

    // Add padding
    const padding = 50.0;
    final width = overallBounds.width + (padding * 2);
    final height = overallBounds.height + (padding * 2);
    final viewBoxX = overallBounds.left - padding;
    final viewBoxY = overallBounds.top - padding;

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'width="${width.toStringAsFixed(0)}" '
      'height="${height.toStringAsFixed(0)}" '
      'viewBox="$viewBoxX $viewBoxY $width $height">',
    );

    // Background
    buffer.writeln(
      '  <rect x="$viewBoxX" y="$viewBoxY" width="$width" height="$height" fill="#E3F2FD"/>',
    );

    // Draw rooms
    for (final room in rooms) {
      final pathData = pathToSvgPathData(room.path);
      final fillColor = colorToHex(room.fillColor);

      // Room fill
      buffer.writeln(
        '  <path d="$pathData" fill="$fillColor" stroke="#424242" stroke-width="3"'
        '${room.wallPoints == null ? '' : ' data-wall-points="${room.wallPoints!.map((p) => '${p.dx},${p.dy}').join(' ')}"'}/>',
      );

      // Room name and area (as text)
      final bounds = room.path.getBounds();
      final center = bounds.center;
      final area = calculateArea(room.path);
      buffer.writeln(
        '  <text x="${center.dx}" y="${center.dy - 8}" '
        'text-anchor="middle" font-family="Arial" font-size="16" font-weight="bold" fill="#000000">${xml.XmlText(room.name)}</text>',
      );
      buffer.writeln(
        '  <text x="${center.dx}" y="${center.dy + 12}" '
        'text-anchor="middle" font-family="Arial" font-size="14" fill="#000000">${area.toStringAsFixed(2)} m²</text>',
      );
    }

    // Draw doors (as gaps with swing arcs)
    for (final door in doors) {
      final bounds = door.path.getBounds();
      final center = bounds.center;
      final doorLength = math.max(bounds.width, bounds.height);

      // Calculate door opening lines
      Offset doorLineStart;
      Offset doorLineEnd;

      switch (door.edge) {
        case 'top':
          doorLineStart = Offset(center.dx - doorLength / 2, center.dy);
          doorLineEnd = Offset(center.dx + doorLength / 2, center.dy);
          break;
        case 'bottom':
          doorLineStart = Offset(center.dx - doorLength / 2, center.dy);
          doorLineEnd = Offset(center.dx + doorLength / 2, center.dy);
          break;
        case 'left':
          doorLineStart = Offset(center.dx, center.dy - doorLength / 2);
          doorLineEnd = Offset(center.dx, center.dy + doorLength / 2);
          break;
        case 'right':
          doorLineStart = Offset(center.dx, center.dy - doorLength / 2);
          doorLineEnd = Offset(center.dx, center.dy + doorLength / 2);
          break;
        default:
          continue;
      }

      // Draw door gap lines
      if (door.edge == 'top' || door.edge == 'bottom') {
        buffer.writeln(
          '  <line x1="${doorLineStart.dx}" y1="${doorLineStart.dy}" '
          'x2="${doorLineStart.dx}" y2="${doorLineStart.dy - (door.edge == 'top' ? 8 : -8)}" '
          'stroke="#000000" stroke-width="2"/>',
        );
        buffer.writeln(
          '  <line x1="${doorLineEnd.dx}" y1="${doorLineEnd.dy}" '
          'x2="${doorLineEnd.dx}" y2="${doorLineEnd.dy - (door.edge == 'top' ? 8 : -8)}" '
          'stroke="#000000" stroke-width="2"/>',
        );
      } else {
        buffer.writeln(
          '  <line x1="${doorLineStart.dx}" y1="${doorLineStart.dy}" '
          'x2="${doorLineStart.dx - (door.edge == 'left' ? 8 : -8)}" y2="${doorLineStart.dy}" '
          'stroke="#000000" stroke-width="2"/>',
        );
        buffer.writeln(
          '  <line x1="${doorLineEnd.dx}" y1="${doorLineEnd.dy}" '
          'x2="${doorLineEnd.dx - (door.edge == 'left' ? 8 : -8)}" y2="${doorLineEnd.dy}" '
          'stroke="#000000" stroke-width="2"/>',
        );
      }
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }
}
