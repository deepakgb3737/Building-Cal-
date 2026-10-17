import 'package:flutter/material.dart';

/// Represents a room in the floor plan
class Room {
  final String id;
  Path path;
  final List<Path> doorOpenings; // Store door openings for border rendering
  Color fillColor; // Room fill color
  String name; // Room name
  List<Offset>? wallPoints;

  Room({
    required this.id,
    required this.path,
    List<Path>? doorOpenings,
    Color? fillColor,
    String? name,
    this.wallPoints,
  })  : doorOpenings = doorOpenings ?? [],
        fillColor = fillColor ?? const Color(0xFFF5F5DC), // Default light beige
        name = name ?? 'Room'; // Default name
}
