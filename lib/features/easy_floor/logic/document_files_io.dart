import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'document_storage.dart';

DocumentStorage createStorage() => FileDocumentStorage();

class FileDocumentStorage implements DocumentStorage {
  FileDocumentStorage({Directory? directory}) : _provided = directory;
  final Directory? _provided;
  Future<Directory> _directory() async {
    final dir = _provided ??
        Directory(
            '${(await getApplicationSupportDirectory()).path}/easy_floor_documents');
    await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<Map<String, String>> readAll() async {
    final result = <String, String>{};
    await for (final entry in (await _directory()).list()) {
      if (entry is! File || !entry.path.endsWith('.json')) continue;
      final id =
          entry.uri.pathSegments.last.replaceFirst(RegExp(r'\.json$'), '');
      try {
        validateDocumentId(id);
        result[id] = await entry.length() > 16 * 1024 * 1024
            ? ''
            : await entry.readAsString();
      } on FileSystemException {
        result[id] = '';
      } on FormatException {
        result[id] = '';
      }
    }
    return result;
  }

  @override
  Future<void> write(String id, String content) async {
    validateDocumentId(id);
    final dir = await _directory();
    final pending = File('${dir.path}/$id.pending');
    try {
      await pending.writeAsString(content, flush: true);
      // Same-directory rename exposes either the old complete file or the new one.
      await pending.rename('${dir.path}/$id.json');
    } finally {
      try {
        if (await pending.exists()) await pending.delete();
      } on FileSystemException {/* Keep the original save error. */}
    }
  }

  @override
  Future<void> delete(String id) async {
    validateDocumentId(id);
    final file = File('${(await _directory()).path}/$id.json');
    if (await file.exists()) await file.delete();
  }
}
