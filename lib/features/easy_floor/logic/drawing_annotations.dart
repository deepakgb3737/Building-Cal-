import 'dart:collection';
import 'drawing_point.dart';
import 'document_json.dart';

enum AnnotationInk { ink, blue, red, green, brown }

enum AnnotationAlignment { left, center, right }

class DrawingAnnotation {
  const DrawingAnnotation(this.id, this.text, this.position,
      {this.sizeMm = 180,
      this.ink = AnnotationInk.ink,
      this.alignment = AnnotationAlignment.left});
  final int id;
  final String text;
  final DrawingPoint position;
  final double sizeMm;
  final AnnotationInk ink;
  final AnnotationAlignment alignment;
  DrawingAnnotation copyWith(
          {String? text,
          DrawingPoint? position,
          double? sizeMm,
          AnnotationInk? ink,
          AnnotationAlignment? alignment}) =>
      DrawingAnnotation(id, text ?? this.text, position ?? this.position,
          sizeMm: sizeMm ?? this.sizeMm,
          ink: ink ?? this.ink,
          alignment: alignment ?? this.alignment);
}

/// Independent from the wall graph: annotations never create junctions or snaps.
class DrawingAnnotations {
  final Map<int, DrawingAnnotation> _items = {};
  int _nextId = 1;
  Map<int, DrawingAnnotation> get items => UnmodifiableMapView(_items);
  List<Object?> toJson() => [
        for (final n in _items.values)
          {
            'id': n.id,
            'text': n.text,
            'x': n.position.x,
            'y': n.position.y,
            'size': n.sizeMm,
            'ink': n.ink.name,
            'alignment': n.alignment.name
          }
      ];
  static DrawingAnnotations fromJson(Object? value) {
    final result = DrawingAnnotations();
    for (final row in jsonArray(value)) {
      final r = jsonObject(row), id = jsonInteger(jsonObject(row)['id']);
      if (r['text'] is! String || result._items.containsKey(id)) {
        throw const FormatException('Invalid text annotation.');
      }
      final note = DrawingAnnotation(id, r['text'] as String,
          DrawingPoint(jsonNumber(r['x']), jsonNumber(r['y'])),
          sizeMm: jsonNumber(r['size']),
          ink: jsonEnum(AnnotationInk.values, r['ink']),
          alignment: jsonEnum(AnnotationAlignment.values, r['alignment']));
      _validate(note);
      result._items[id] = note;
      if (id >= result._nextId) result._nextId = id + 1;
    }
    return result;
  }

  DrawingAnnotations copy() => DrawingAnnotations()
    .._items.addAll(_items)
    .._nextId = _nextId;

  bool sameAs(DrawingAnnotations other) =>
      _items.length == other._items.length &&
      _items.entries.every((e) {
        final b = other._items[e.key], a = e.value;
        return b != null &&
            a.text == b.text &&
            a.position.x == b.position.x &&
            a.position.y == b.position.y &&
            a.sizeMm == b.sizeMm &&
            a.ink == b.ink &&
            a.alignment == b.alignment;
      });

  static void _validate(DrawingAnnotation note) {
    if (note.text.trim().isEmpty ||
        note.text.length > 2000 ||
        !note.position.isFinite ||
        note.position.x.abs() > 100000000 ||
        note.position.y.abs() > 100000000 ||
        !note.sizeMm.isFinite ||
        note.sizeMm < 120 ||
        note.sizeMm > 480) {
      throw ArgumentError(
          'Enter text (1-2000 characters), size 12-48, and a valid position.');
    }
  }

  int add(String text, DrawingPoint position,
      {double sizeMm = 180,
      AnnotationInk ink = AnnotationInk.ink,
      AnnotationAlignment alignment = AnnotationAlignment.left}) {
    final note = DrawingAnnotation(_nextId, text, position,
        sizeMm: sizeMm, ink: ink, alignment: alignment);
    _validate(note);
    _items[note.id] = note;
    _nextId++;
    return note.id;
  }

  void update(DrawingAnnotation note) {
    _require({note.id});
    _validate(note);
    _items[note.id] = note;
  }

  void _require(Set<int> ids) {
    if (!ids.every(_items.containsKey)) {
      throw ArgumentError('Select existing text.');
    }
  }

  void move(Set<int> ids, DrawingPoint delta) {
    _require(ids);
    final moved = {
      for (final id in ids)
        id: _items[id]!.copyWith(position: _items[id]!.position + delta)
    };
    moved.values.forEach(_validate);
    _items.addAll(moved);
  }

  Set<int> duplicate(Set<int> ids, DrawingPoint delta) {
    _require(ids);
    final next = copy(), result = <int>{};
    for (final id in ids) {
      final note = _items[id]!;
      result.add(next.add(note.text, note.position + delta,
          sizeMm: note.sizeMm, ink: note.ink, alignment: note.alignment));
    }
    _items.addAll(next._items);
    _nextId = next._nextId;
    return result;
  }

  void delete(Set<int> ids) {
    _require(ids);
    _items.removeWhere((id, _) => ids.contains(id));
  }
}
