import 'package:flutter/material.dart';

/// Represents a door in the floor plan
class Door {
  final String id;
  Path path;
  double rotation;
  final String roomId; // Reference to the room this door belongs to
  final String edge; // Which edge: 'top', 'bottom', 'left', 'right'

  Door({
    required this.id,
    required this.path,
    this.rotation = 0,
    required this.roomId,
    required this.edge,
  });
}
