import 'package:flutter/material.dart';
import '../models/room.dart';
import '../models/door.dart';
import 'svg_parser.dart';

class PlanSnapshot {
  PlanSnapshot(List<Room> rooms, List<Door> doors, this.counter)
      : rooms = rooms.map(copyRoom).toList(),
        doors = doors.map(copyDoor).toList(),
        signature = SvgParser.generateSVG(rooms, doors);
  final List<Room> rooms;
  final List<Door> doors;
  final int counter;
  final String signature;
  static Room copyRoom(Room r) => Room(
      id: r.id,
      path: Path.from(r.path),
      name: r.name,
      fillColor: r.fillColor,
      wallPoints: r.wallPoints == null ? null : List.of(r.wallPoints!),
      doorOpenings: r.doorOpenings.map(Path.from).toList());
  static Door copyDoor(Door d) => Door(
      id: d.id,
      path: Path.from(d.path),
      roomId: d.roomId,
      rotation: d.rotation,
      edge: d.edge);
}
