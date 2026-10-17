import 'dart:convert';
import 'dart:math';
import 'floor_document.dart';
import 'document_json.dart';
import 'document_storage.dart';

class DocumentEntry {
  const DocumentEntry(this.id, this.name, this.modified,
      {this.invalid = false});
  final String id, name;
  final DateTime? modified;
  final bool invalid;
}

class DocumentRepository {
  DocumentRepository(this.storage);
  final DocumentStorage storage;
  bool _writing = false;
  static final _random = Random.secure();
  String _newId() => List.generate(4,
          (_) => _random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'))
      .join();

  static String validName(String input) {
    final name = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty ||
        name.length > 80 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(input)) {
      throw const FormatException(
          'Use a document name of 1-80 characters, without control characters.');
    }
    return name;
  }

  static void _checkSize(String content) {
    if (content.length > 16 * 1024 * 1024 ||
        utf8.encode(content).length > 16 * 1024 * 1024) {
      throw const FormatException('Document is too large.');
    }
  }

  static String _encode(Object value) {
    final encoded = jsonEncode(value);
    _checkSize(encoded);
    return encoded;
  }

  static Map<String, dynamic> _decode(String content) {
    _checkSize(content);
    return jsonObject(jsonDecode(content));
  }

  static DocumentEntry _entry(String id, String raw) {
    validateDocumentId(id);
    final d = _decode(raw);
    if (d['version'] != 1 ||
        d['id'] != id ||
        d['name'] is! String ||
        d['modified'] is! String) {
      throw const FormatException('Unsupported or invalid document.');
    }
    final name = validName(d['name'] as String),
        modified = DateTime.tryParse(d['modified'] as String);
    if (modified == null) throw const FormatException('Invalid document date.');
    jsonObject(d['data']);
    return DocumentEntry(id, name, modified);
  }

  Future<List<DocumentEntry>> list() async {
    final files = await storage.readAll(), result = <DocumentEntry>[];
    for (final file in files.entries) {
      try {
        result.add(_entry(file.key, file.value));
      } catch (_) {
        result.add(DocumentEntry(file.key, 'Unreadable document', null,
            invalid: true));
      }
    }
    result.sort((a, b) => (b.modified ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(a.modified ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return result;
  }

  Future<(DocumentEntry, FloorDocument)> open(String id) async {
    validateDocumentId(id);
    final raw = (await storage.readAll())[id];
    if (raw == null) throw const FormatException('Document no longer exists.');
    final entry = _entry(id, raw);
    return (entry, FloorDocument.fromJson(_decode(raw)['data']));
  }

  Future<T> _write<T>(Future<T> Function() action) async {
    if (_writing) throw StateError('A document operation is already running.');
    _writing = true;
    try {
      return await action();
    } finally {
      _writing = false;
    }
  }

  void _unique(String name, String? id, Map<String, String> files) {
    for (final file in files.entries) {
      if (file.key == id) continue;
      DocumentEntry? entry;
      try {
        entry = _entry(file.key, file.value);
      } catch (_) {
        continue;
      }
      if (entry.name.toLowerCase() == name.toLowerCase()) {
        throw const FormatException(
            'That document name already exists. Choose another name.');
      }
    }
  }

  Future<DocumentEntry> save(FloorDocument document, String input,
          {String? id}) =>
      _write(() async {
        final name = validName(input), files = await storage.readAll();
        if (id != null) {
          validateDocumentId(id);
          if (!files.containsKey(id)) {
            throw const FormatException('Document was removed. Use Save As.');
          }
        }
        _unique(name, id, files);
        // Validate the complete snapshot before touching persistent data.
        final data = document.toJson();
        FloorDocument.fromJson(jsonDecode(jsonEncode(data)));
        var target = id ?? _newId();
        while (id == null && files.containsKey(target)) {
          target = _newId();
        }
        final modified = DateTime.now().toUtc();
        await storage.write(
            target,
            _encode({
              'version': 1,
              'id': target,
              'name': name,
              'modified': modified.toIso8601String(),
              'data': data
            }));
        return DocumentEntry(target, name, modified);
      });

  Future<DocumentEntry> rename(String id, String input) => _write(() async {
        final name = validName(input),
            files = await storage.readAll(),
            raw = (await open(id));
        _unique(name, id, files);
        final d = _decode(files[id]!), modified = DateTime.now().toUtc();
        d['name'] = name;
        d['modified'] = modified.toIso8601String();
        await storage.write(id, _encode(d));
        return DocumentEntry(raw.$1.id, name, modified);
      });
  Future<void> delete(String id) => _write(() async {
        validateDocumentId(id);
        await storage.delete(id);
      });
}
